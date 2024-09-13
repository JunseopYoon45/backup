USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_Q2] (
	  @P_DP_VERSION		 NVARCHAR(30)	--DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	--MP 버전	
	, @P_PLNT_CD         NVARCHAR(30)	--Plant코드	
	, @P_BRND_CD		 NVARCHAR(MAX)	--Brand코드	
	, @P_GRADE_CD		 NVARCHAR(MAX)	--그레이드코드
	, @P_ITEM_CD		 NVARCHAR(30)	--제품코드	
	, @P_ITEM_NM		 NVARCHAR(30)	--제품명	
	, @P_ITEM_TP		 NVARCHAR(30)	--제품타입
	, @P_LANG_CD		 NVARCHAR(10)   --다국어코드
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID		 NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_Q2
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > PSI 및 공급 계획 확정
                     법인 창고 PSI Chart

   CONTENTS        : ╬╬ SKCA, SKCA 법인 제품/창고별 PSI 산출 (A199, B199는 본사 PSI에 포함)
                     1. 수요계획                    : 확정 수요계획 (DP)
					 2. 예상 창고 입고 (공급 계획)  : MP 납품일 기준 공급계획
					 3. 예상 창고 입고 (In-Transit) : In-Transit 도착일 기준
					 4. 예상 창고 재고              : Σ(법인 창고 재고(I) – 수요계획(S) + 예상 창고 입고(P))
					 5. 안전 재고                   : 최소 재고 레벨
					 6. 적정 재고                   : 최대 재고 레벨
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
  2024-07-08  Zionex          신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_Q2' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_Q2 'DP-202407-01-M','MP-20240801-01-M-12','A101','ALL','ALL','100452','','','ko','zionex8',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_DP_VERSION	), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION	), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLNT_CD		), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRND_CD		), '')				 
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_CD		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_NM		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_TP		), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD 		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID		), '')
                   + ''''

DECLARE @V_DP_VERSION	  NVARCHAR(30) = @P_DP_VERSION		-- DP 버전
	  , @V_MP_VERSION	  NVARCHAR(30) = @P_MP_VERSION		-- MP 버전	
	  , @V_PLNT_CD		  NVARCHAR(MAX) = REPLACE(@P_PLNT_CD,  'ALL', '')
	  , @V_BRND_CD		  NVARCHAR(MAX) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(30) = REPLACE(@P_GRADE_CD, 'ALL', '')
	  , @V_ITEM_CD		  NVARCHAR(30) = @P_ITEM_CD
	  , @V_ITEM_NM		  NVARCHAR(30) = @P_ITEM_NM
	  , @V_ITEM_TP		  NVARCHAR(30) = @P_ITEM_TP
	  , @V_DTF_DATE		  DATETIME
	  , @V_FROM_DATE	  DATETIME
	  , @V_VAR_START_DATE DATETIME
	  , @V_TO_DATE		  DATETIME
	  , @V_SNRIO_VER_CD   NVARCHAR(30) = (SELECT MAX(X.SNRIO_VER_CD)        -- 안전재고 시나리오 버전
							                FROM TB_IM_TARGET_INV_VERSION X
										   WHERE X.CONFRM_YN = 'Y'
										 )

   EXEC SP_PGM_LOG  'MP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------
BEGIN

/*******************************************************************************************************************************************************
  [1] Loading
    - 대상 기준 데이터를 선정하는 영역
*******************************************************************************************************************************************************/

    /*************************************************************************************************************
	  계획 구간 일자 수집
	  1. 확정 DP 버전 기준    (@V_DP_VERSION)
	  2. 계획 수립 시작일     (@V_FROM_DATE)
	  3. 3개월 계획 구간 시점 (@V_VAR_START_DATE)
	  4. 계획 수립 종료일     (@V_TO_DATE)
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_DP_VER') IS NOT NULL DROP TABLE #TB_DP_VER
	SELECT @V_DTF_DATE		 = MA.DTF_DATE
		 , @V_FROM_DATE		 = MA.FROM_DATE
		 , @V_VAR_START_DATE = MA.VER_S_HORIZON_DATE 
		 , @V_TO_DATE		 = MA.TO_DATE
	  FROM TB_DP_CONTROL_BOARD_VER_MST MA WITH (NOLOCK)
	     , TB_DP_CONTROL_BOARD_VER_DTL DT WITH (NOLOCK)
	     , ( SELECT * 
		       FROM TB_CM_COMM_CONFIG WITH (NOLOCK)
		      WHERE 1 = 1
		        AND CONF_GRP_CD = 'DP_CL_STATUS' 
		        AND CONF_CD		= 'CLOSE'        -- 확정버전
		        AND ACTV_YN		= 'Y'
	       ) CN
	 WHERE 1 = 1
	   AND MA.ID           = DT.CONBD_VER_MST_ID
	   AND DT.CL_STATUS_ID = CN.ID
	   AND MA.VER_ID       = @V_DP_VERSION	

    ---------------------------------------------------------------------------------------------------------
    -- #TM_BRND
	-- Brand 다중 검색 용도
    ---------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#TM_BRND') IS NOT NULL DROP TABLE #TM_BRND -- 임시테이블 삭제
	SELECT Value AS VAL
      INTO #TM_BRND
      FROM SplitTableNVARCHAR(ISNULL(UPPER(@V_BRND_CD),''),'|');

    ---------------------------------------------------------------------------------------------------------
    -- #TM_GRADE
	-- Grade 다중 검색 용도
    ---------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제
	SELECT Value AS VAL
      INTO #TM_GRADE
      FROM SplitTableNVARCHAR(ISNULL(UPPER(@V_GRADE_CD),''),'|');

    /*************************************************************************************************************
	  법인 PSI 대상 목록 수집
	  1. 본사 제외
	  2. 직수출 제외
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.PLNT_CD,     I.PLNT_NM,    I.BRND_CD,    I.BRND_NM
	     , I.GRADE_CD,    I.GRADE_NM,   I.ITEM_CD,    I.ITEM_NM
		 , I.ITEM_TP,     M.MEASURE_CD, M.MEASURE_NM, C.REP_DT
		 , C.REP_DT_DESC, C.YYYY,       C.YYYYMM,     C.PLAN_DT	
		 , C.WEEK_SEQ,    I.CORP_CD	 		
	     , CONVERT(NUMERIC(18, 6), 0) AS IN_TRNS_QTY   -- In-transit 재고
		 , CONVERT(NUMERIC(18, 6), 0) AS PLNT_STCK_QTY -- 법인재고
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY      -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0) AS PSI_QTY       -- 예상 창고 재고 PSI산출용 개별수량		 
	  INTO #TB_PLAN
	  FROM (SELECT B.PLNT_CD,  B.PLNT_NM,  A.BRND_CD, A.BRND_NM
	             , A.GRADE_CD, A.GRADE_NM, A.ITEM_CD, A.ITEM_NM
				 , A.ITEM_TP,  A.CORP_CD
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD			 
			 WHERE 1 = 1
			   AND A.CORP_CD     <> '1000'           -- 본사 제외
			   AND B.PLNT_CD NOT IN ('A199', 'B199') -- 직수출 제외
			 GROUP BY B.PLNT_CD,  B.PLNT_NM,  A.BRND_CD, A.BRND_NM
	                , A.GRADE_CD, A.GRADE_NM, A.ITEM_CD, A.ITEM_NM
				    , A.ITEM_TP,  A.CORP_CD
		   ) I
	 CROSS 
	 APPLY ( SELECT	FORMAT(MAX(C.DAT),'yy-MM-dd')                     AS REP_DT
	        	  , CONCAT('W',SUBSTRING(C.PARTWK, 5, LEN(C.PARTWK))) AS REP_DT_DESC
  	        	  , C.YYYY                                            AS YYYY
	        	  , C.YYYYMM                                          AS YYYYMM
	        	  , C.PARTWK                                          AS PLAN_DT
	        	  , ROW_NUMBER() OVER (ORDER BY C.YYYYMM, C.PARTWK)   AS WEEK_SEQ
	           FROM TB_CM_CALENDAR C WITH (NOLOCK)
			  WHERE 1 = 1
			    AND C.DAT_ID >= @V_FROM_DATE
			    AND C.DAT_ID <  @V_VAR_START_DATE
			  GROUP BY YYYYMM, PARTWK, YYYY			 
	      ) C 
	    , ( SELECT COMN_CD    AS MEASURE_CD
		         , COMN_CD_NM AS MEASURE_NM
		      FROM FN_COMN_CODE ('MP1031_2','')
	      ) M
	WHERE 1 = 1	  
	  AND (I.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
	  AND (I.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	  AND ((@V_PLNT_CD  = '') OR (I.PLNT_CD	    =     @V_PLNT_CD))	  
	  AND ((@V_ITEM_CD  = '') OR (I.ITEM_CD  LIKE '%'+@V_ITEM_CD+'%'))
	  AND ((@V_ITEM_NM  = '') OR (I.ITEM_NM  LIKE '%'+@V_ITEM_NM+'%')) 
	  AND ((@V_ITEM_TP  = '') OR (I.ITEM_TP  LIKE '%'+@V_ITEM_TP+'%'))
	
/*******************************************************************************************************************************************************
  [2] Collection
    - 항목 별 고정 데이터를 수집하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [내부 설정] 1. In-transit 재고
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT C.ITEM_CD, D.PLNT_CD, SUM(B.QTY) AS IN_TRNS_QTY
	          FROM TB_CM_INTRANSIT_STOCK_MST_HIS A WITH (NOLOCK)
	         INNER
	          JOIN TB_CM_INTRANSIT_STOCK_QTY_HIS B WITH (NOLOCK)
	            ON B.MP_VERSION_ID        = A.MP_VERSION_ID
			   AND B.DP_VERSION_ID        = A.DP_VERSION_ID
			   AND B.INTRANSIT_INV_MST_ID = A.ID
	         INNER
	          JOIN VW_LOCAT_ITEM_DTS_INFO    C WITH (NOLOCK)
	            ON C.LOCAT_ITEM_ID = A.TO_LOCAT_ITEM_ID
	         INNER
	          JOIN VW_LOCAT_DTS_INFO         D WITH (NOLOCK)
	            ON D.LOCAT_CD      = C.LOCAT_CD
			 WHERE 1 = 1
			   AND A.MP_VERSION_ID = @V_MP_VERSION
			   AND A.DP_VERSION_ID = @V_DP_VERSION
			   AND A.INV_TP      = 'IN'
			 GROUP BY C.ITEM_CD, D.PLNT_CD
          ) Y
       ON X.PLNT_CD = Y.PLNT_CD  
	  AND X.ITEM_CD = Y.ITEM_CD	 
     WHEN MATCHED 
     THEN UPDATE
             SET X.IN_TRNS_QTY = Y.IN_TRNS_QTY
	;

    /*************************************************************************************************************
	  [내부 설정] 2. 법인 재고 (BOH)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT C.ITEM_CD, D.PLNT_CD, SUM(B.QTY) AS PLNT_STCK_QTY
	          FROM TB_CM_WAREHOUSE_STOCK_MST_HIS A WITH (NOLOCK)
	         INNER
	          JOIN TB_CM_WAREHOUSE_STOCK_QTY_HIS B WITH (NOLOCK)
	            ON B.MP_VERSION_ID        = A.MP_VERSION_ID
			   AND B.DP_VERSION_ID        = A.DP_VERSION_ID
			   AND B.WAREHOUSE_INV_MST_ID = A.ID
	         INNER
	          JOIN VW_LOCAT_ITEM_DTS_INFO    C WITH (NOLOCK)
	            ON C.LOCAT_ITEM_ID = A.LOCAT_ITEM_ID
	         INNER
	          JOIN VW_LOCAT_DTS_INFO         D WITH (NOLOCK)
	            ON D.LOCAT_CD      = C.LOCAT_CD
			 WHERE 1 = 1
			   AND A.MP_VERSION_ID = @V_MP_VERSION
		       AND A.DP_VERSION_ID = @V_DP_VERSION
			   AND C.LOC_TP_NM     = 'RDC'	
			   AND A.INV_TP       <> 'CY'
			 GROUP BY C.ITEM_CD, D.PLNT_CD
          ) Y
       ON X.PLNT_CD = Y.PLNT_CD  
	  AND X.ITEM_CD = Y.ITEM_CD	 
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLNT_STCK_QTY = Y.PLNT_STCK_QTY
	;

/*******************************************************************************************************************************************************
  [3] Processing
    - 각 Measure 별 수치를 계산 및 저장하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [PSI] 1. 예상 창고 재고       (PSI 계산용 BOH)
	        -> 첫 번째 주(버킷)에 PSI 수량 설정 (누적 합산 시, 시작점)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( -- 예상 창고 재고
	        SELECT A.ITEM_CD, A.PLNT_CD, A.MEASURE_CD
	             , A.PLNT_STCK_QTY AS PSI_QTY
				 , MIN(A.PLAN_DT)  AS PLAN_DT
	          FROM #TB_PLAN A
	         WHERE 1 = 1	           
	           AND A.MEASURE_CD    = '004'
	           AND A.PLNT_STCK_QTY > 0
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.MEASURE_CD, A.PLNT_STCK_QTY			
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.MEASURE_CD = Y.MEASURE_CD
	  AND X.PLAN_DT    = Y.PLAN_DT
     WHEN MATCHED 
     THEN UPDATE
             SET X.PSI_QTY = Y.PSI_QTY    -- 예상 창고 재고 PSI 용도			  
	;

	/*************************************************************************************************************
	  [PSI] 2. 수요계획 (S) = 출하 수요계획 (Demand)
	*************************************************************************************************************/	
	UPDATE P
	   SET P.PLAN_QTY = D.PLAN_QTY
	     , P.PSI_QTY  = - D.PLAN_QTY
	  FROM #TB_PLAN P
	  CROSS 
	  APPLY ( SELECT I.ITEM_CD, L.PLNT_CD, C.PLAN_DT
	               , SUM(D.DMND_QTY)   AS PLAN_QTY				  
		        FROM TB_CM_DEMAND_OVERVIEW D WITH (NOLOCK)
		       CROSS
			   APPLY ( SELECT C.PARTWK AS PLAN_DT
					     FROM TB_CM_CALENDAR C WITH (NOLOCK)
					    WHERE 1 = 1
					      AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)--@V_FROM_DATE
					      AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					      AND C.DAT	    = CONVERT(DATETIME, D.DUE_DATE, 112)
					    GROUP BY C.YYYYMM, C.PARTWK, C.YYYY					  
			         ) C 
		           , TB_CM_ITEM_MST    I WITH (NOLOCK)
		           , TB_DP_ACCOUNT_MST A WITH (NOLOCK)
		           , VW_LOCAT_DTS_INFO L WITH (NOLOCK)
		       WHERE 1 = 1
		         AND I.ID                  = D.ITEM_MST_ID 
		         AND A.ID                  = D.ACCOUNT_ID
		         AND D.REQUEST_SITE_ID     = L.LOC_DTL_ID
		         AND D.T3SERIES_VER_ID     = @V_DP_VERSION
		         AND L.PLNT_CD             = P.PLNT_CD
		         AND I.ITEM_CD             = P.ITEM_CD
				 AND C.PLAN_DT             = P.PLAN_DT
				 AND A.ACTV_YN             = 'Y'
		         AND ISNULL(D.DMND_QTY, 0) > 0
				 AND LEFT(D.DMND_ID, 1)   <> 'S'             -- 안전재고 보충 Demand 제외
		       GROUP BY I.ITEM_CD, L.PLNT_CD, C.PLAN_DT
	         ) D
	   WHERE 1 = 1
	     AND P.MEASURE_CD = '001'

	/*************************************************************************************************************
	  [PSI] 3. 예상 창고 입고 (P : 공급계획)
	           - 최종 창고 Delivery 계획
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- Deilvery 공급계획 
			         SELECT A.ITEM_CD, B.PLNT_CD
			              , A.DLVY_QTY                          AS PLAN_QTY    -- 톤 단위 수량
						  , CONVERT(DATETIME, A.DLVY_DATE, 112) AS USABLE_DATE -- 납품일 기준				 
			           FROM TB_SKC_MP_SHMT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					     ON B.LOCAT_CD	= A.TO_LOCAT_CD
          	          WHERE 1 = 1
          	            AND A.MP_VERSION_ID = @V_MP_VERSION   --'MP-20240628-03-M-08'--@V_MP_VERSION    						
          	            AND A.DLVY_QTY      > 0
				        AND (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')			      
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY					
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
          ) Y
       ON X.PLNT_CD = Y.PLNT_CD  
	  AND X.ITEM_CD = Y.ITEM_CD	
	  AND X.PLAN_DT = Y.PLAN_DT
	  AND X.MEASURE_CD = '002'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY    -- 예상 창고 재고 PSI 용도			   
    ;

	/*************************************************************************************************************
	  [PSI] 4. 예상 창고 입고 (P : In-transit + CY 재고) 
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- In-transit
					 SELECT C.ITEM_CD, D.PLNT_CD
					      , B.QTY                  AS PLAN_QTY
						  , A.ESTIMT_USABLE_DATE   AS USABLE_DATE --DATEADD(DAY, 7, A.ESTIMT_USABLE_DATE) AS USABLE_DATE	-- In-Transit 입고일 + 7일 적용 (현업 요청 사항)					 
	                   FROM TB_CM_INTRANSIT_STOCK_MST_HIS A WITH (NOLOCK)
	                  INNER
	                   JOIN TB_CM_INTRANSIT_STOCK_QTY_HIS B WITH (NOLOCK)
	                     ON B.MP_VERSION_ID        = A.MP_VERSION_ID
			            AND B.DP_VERSION_ID        = A.DP_VERSION_ID
						AND B.INTRANSIT_INV_MST_ID = A.ID
	                  INNER
	                   JOIN VW_LOCAT_ITEM_DTS_INFO    C WITH (NOLOCK)
	                     ON C.LOCAT_ITEM_ID = A.TO_LOCAT_ITEM_ID
	                  INNER
	                   JOIN VW_LOCAT_DTS_INFO         D WITH (NOLOCK)
	                     ON D.LOCAT_CD      = C.LOCAT_CD
			          WHERE 1 = 1
					    AND A.MP_VERSION_ID = @V_MP_VERSION
		                AND A.DP_VERSION_ID = @V_DP_VERSION
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY					
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '003'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY    -- 예상 창고 재고 PSI 용도			
	;	
	
	/*************************************************************************************************************
	  [PSI] 5. 예상 창고재고 (I) = 기말재고 (EOH)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1					  
			         GROUP BY A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '004'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI] 5. 안전재고 및 적정재고
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT C.PLNT_CD, B.ITEM_CD, A.SFST_VAL, A.OPERT_INV_VAL        
              FROM TB_IM_TARGET_INV_POLICY A WITH (NOLOCK)
	         INNER
	          JOIN VW_LOCAT_ITEM_DTS_INFO B WITH (NOLOCK)
	            ON B.LOCAT_ITEM_ID = A.LOCAT_ITEM_ID
	         INNER
	          JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
	            ON C.LOCAT_CD = B.LOCAT_CD	
             WHERE 1 = 1
	           AND A.SNRIO_VER_ID = (SELECT Z.ID
                                       FROM TB_IM_TARGET_INV_VERSION Z WITH (NOLOCK)
                                      WHERE Z.SNRIO_VER_CD = @V_SNRIO_VER_CD
	        						)
	         GROUP BY C.PLNT_CD, B.ITEM_CD, A.SFST_VAL, A.OPERT_INV_VAL
          ) Y
       ON X.PLNT_CD     = Y.PLNT_CD  
	  AND X.ITEM_CD     = Y.ITEM_CD	 
      AND X.MEASURE_CD IN ('005', '006')
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = CASE WHEN X.MEASURE_CD = '005'
			                       THEN Y.SFST_VAL      -- 안전재고
								   ELSE Y.OPERT_INV_VAL -- 적정재고
							   END
	;

/*******************************************************************************************************************************************************
  [4] Searching
    - 상기 정리된 결과물을 조회하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [화면 조회]
	*************************************************************************************************************/
	SELECT A.MEASURE_CD, A.MEASURE_NM -- 'W' + CONVERT(VARCHAR, A.WEEK_SEQ) AS NUM_WEEK
	     , A.REP_DT_DESC        AS NUM_WEEK
	     , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
		 , @V_SNRIO_VER_CD      AS SNRIO_VER_CD	
		 , A.CORP_CD            AS CORP_CD	
		 , A.PLNT_CD            AS PLNT_CD
		 , A.ITEM_CD            AS ITEM_CD
		 , A.ITEM_NM            AS ITEM_NM
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	 ORDER BY A.MEASURE_CD, A.MEASURE_NM, A.WEEK_SEQ, A.PLAN_QTY

END
GO
