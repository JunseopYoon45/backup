USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_Q4]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_Q4] (
	  @P_DP_VERSION		 NVARCHAR(30)	-- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	-- MP 버전		
	, @P_BRND_CD		 NVARCHAR(MAX)	-- Brand코드	
	, @P_GRADE_CD		 NVARCHAR(MAX)	-- 그레이드코드
	, @P_ITEM_CD		 NVARCHAR(30)	-- 제품코드	
	, @P_ITEM_NM		 NVARCHAR(MAX)	-- 제품명	
	, @P_ITEM_TP		 NVARCHAR(30)	-- 제품타입
	, @P_LANG_CD		 NVARCHAR(10)   -- 다국어코드
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID		 NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_Q4
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > PSI 및 공급 계획 확정
                     본사 PSI Chart
  
   CONTENTS        : ╬╬ 울산 창고 완제품 / 임가공 / 사급자재 출하 PSI 산출
                     1. 출하 필요량    : 재고가 Netting 및 L/T를 감안한 Demand
					 2. 생산 목표      : MP 출하일 기준 공급계획
					 3. 예상 창고 재고 : Σ(기초 재고(I) – 출하 필요량 합계(S) + 생산 목표 합계(P))
					 4. 안전 재고      : 최소 재고 레벨
					 5. 적정 재고      : 최대 재고 레벨
-----------------------------------------------------------------------------------------------------------------------
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
--2024-07-10  Zionex          신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

-------------------------------------------------- LOG START ------------------------------------------------------------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_Q4' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_Q4 'DP-202407-01-M','MP-20240725-01-M-46','ALL','ALL','100458','','','ko','I23671','UI_MP1031'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_DP_VERSION	), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION	), '')					   
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
	  , @V_BRND_CD		  NVARCHAR(MAX) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(MAX) = REPLACE(@P_GRADE_CD, 'ALL', '')
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

-------------------------------------------------- LOG END ------------------------------------------------------------
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
	  본사 PSI 대상 목록 수집	 
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD,    I.BRND_NM, I.GRADE_CD,    I.GRADE_NM                                                                                                                                      
	     , I.ITEM_CD,    I.ITEM_NM, I.ITEM_TP,     M.MEASURE_CD
		 , M.MEASURE_NM, C.REP_DT,  C.REP_DT_DESC, C.YYYY
		 , C.YYYYMM,     C.PLAN_DT, C.WEEK_SEQ 
		 , CONVERT(NUMERIC(18, 6), 0) AS BOH_STCK_QTY -- 법인재고			 
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY     -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0) AS PSI_QTY      -- PSI산출용 개별수량
	  INTO #TB_PLAN
	  FROM (SELECT A.BRND_CD, A.BRND_NM, A.GRADE_CD, A.GRADE_NM
	             , A.ITEM_CD, A.ITEM_NM, A.ITEM_TP
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD			 
			 WHERE 1 = 1
			 GROUP BY A.BRND_CD, A.BRND_NM, A.GRADE_CD, A.GRADE_NM
			        , A.ITEM_CD, A.ITEM_NM, A.ITEM_TP
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
		      FROM FN_COMN_CODE ('MP1031_4','')
	      ) M
	WHERE 1 = 1	 		
	  AND (I.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
	  AND (I.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	  AND ((@V_ITEM_CD = '') OR (I.ITEM_CD  LIKE '%'+@V_ITEM_CD+'%'))
	  AND ((@V_ITEM_NM = '') OR (I.ITEM_NM  LIKE '%'+@V_ITEM_NM+'%')) 
	  AND ((@V_ITEM_TP = '') OR (I.ITEM_TP  LIKE '%'+@V_ITEM_TP+'%'))
	
/*******************************************************************************************************************************************************
  [2] Collection
    - 항목 별 고정 데이터를 수집하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [내부 설정] 차월 예상 기초재고 (CDC = BOH)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT C.ITEM_CD, SUM(B.QTY) AS BOH_STCK_QTY
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
			   AND C.LOC_TP_NM     = 'CDC'
			 GROUP BY C.ITEM_CD
          ) Y
       ON X.ITEM_CD = Y.ITEM_CD	 
     WHEN MATCHED 
     THEN UPDATE
             SET X.BOH_STCK_QTY = Y.BOH_STCK_QTY
	;

/*******************************************************************************************************************************************************
  [3] Processing
    - 각 Measure 별 수치를 계산 및 저장하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [PSI] 1. 예상 창고 재고 (PSI 계산용 BOH)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.MEASURE_CD
	             , A.BOH_STCK_QTY AS PSI_QTY
				 , MIN(A.PLAN_DT) AS PLAN_DT
	          FROM #TB_PLAN A
	         WHERE 1 = 1
	           AND A.MEASURE_CD   = '003'
	           AND A.BOH_STCK_QTY > 0			   
	         GROUP BY A.ITEM_CD, A.MEASURE_CD, A.BOH_STCK_QTY
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.MEASURE_CD = Y.MEASURE_CD
	  AND X.PLAN_DT    = Y.PLAN_DT
     WHEN MATCHED 
     THEN UPDATE
             SET X.PSI_QTY = Y.PSI_QTY
	;

	/*************************************************************************************************************
	  [PSI] 2. 출하필요량 (S) - Demand 기반으로 재고 Netting 후, 납기에 L/T을 반영한 요구량임. 
	           - 계획수립 결과와는 무관함
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                           AS ITEM_CD					     
			              , A.SHNG_QTY                           AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE -- 출하일 기준			 
			           FROM TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)			  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO  C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID     = @V_DP_VERSION   --'DP-202406-03-M'
						AND A.MP_VERSION_ID     = @V_MP_VERSION						
          	            AND A.SHNG_QTY          > 0	
						--AND A.DMND_TP           = 'D'             -- 최종 독립 Demand
						--AND LEFT(A.DMND_ID, 1) <> 'S'             -- 안전재고 보충량 제외
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')	 
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
	         GROUP BY A.ITEM_CD, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD		 
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '001'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = - Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI] 3. 생산 목표 (P) = 공급계획
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                           AS ITEM_CD					    
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY  -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE						 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)			  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID     = @V_MP_VERSION						
          	            AND A.PLAN_QTY          > 0				
					--	AND LEFT(A.DMND_ID, 1) <> 'S'             -- 안전재고 보충량 제외
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')				 
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
	         GROUP BY A.ITEM_CD, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD		  
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY
	;	

	/*************************************************************************************************************
	  [PSI] 4-2. 안전 재고 보충량 (P) = 공급계획
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- 공급계획
			         SELECT A.ITEM_CD
			              , SUM(A.PLAN_QTY) * 1000              AS PLAN_QTY  -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE						 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					     ON B.LOCAT_CD	= A.TO_LOCAT_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID    = @V_MP_VERSION   --'MP-20240628-03-M-08'--@V_MP_VERSION   
						AND LEFT(A.DMND_ID, 1) = 'S'             -- 안전재고 보충 Demand						
          	            AND A.PLAN_QTY         > 0
				        AND (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')					  
					  GROUP BY A.ITEM_CD, A.PLAN_DATE
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
	         GROUP BY A.ITEM_CD, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '004_2'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY 
			   , X.PSI_QTY  = Y.PLAN_QTY;
	
	/*************************************************************************************************************
	  [PSI] 4. 예상 창고재고 (I) = 기말재고 (EOH)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.ITEM_CD
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1			           
			         GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '003'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	; 

	/*************************************************************************************************************
	  [PSI] 5. 안전재고 및 적정재고
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT B.ITEM_CD, A.SFST_VAL, A.OPERT_INV_VAL        
              FROM TB_IM_TARGET_INV_POLICY A WITH (NOLOCK)
	         INNER
	          JOIN VW_LOCAT_ITEM_DTS_INFO B WITH (NOLOCK)
	            ON B.LOCAT_ITEM_ID = A.LOCAT_ITEM_ID
	         INNER
	          JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
	            ON C.LOCAT_CD = B.LOCAT_CD	
             WHERE 1 = 1
			   AND C.PLNT_CD      = '1110'   -- 수지공장 기준으로 안전재고 표현하기로 함. 그외 플랜트는 법인 PSI 차트로 확인(24/08/06 황영학E)
	           AND A.SNRIO_VER_ID = (SELECT Z.ID
                                       FROM TB_IM_TARGET_INV_VERSION Z WITH (NOLOCK)
                                      WHERE Z.SNRIO_VER_CD = @V_SNRIO_VER_CD
	        						)
			   --AND A.SFST_VAL > 0
	         GROUP BY B.ITEM_CD, A.SFST_VAL, A.OPERT_INV_VAL
          ) Y
       ON X.ITEM_CD     = Y.ITEM_CD	 
	  AND X.MEASURE_CD IN ('004', '005')
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = CASE WHEN X.MEASURE_CD = '004'
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
	SELECT A.MEASURE_CD, A.MEASURE_NM --, 'W' + CONVERT(VARCHAR, A.WEEK_SEQ) AS NUM_WEEK
	     , A.REP_DT_DESC        AS NUM_WEEK
	     , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
		 , @V_SNRIO_VER_CD      AS SNRIO_VER_CD				 
		 /***************************************************************************
		   본사(1000), 수지공장(1110) 기준으로 안전재고 표현하기로 함. 
		   그외 플랜트는 법인 PSI 차트로 확인(24/08/06 황영학E)
		 ***************************************************************************/
		 , '1000'               AS CORP_CD
		 , '1110'               AS PLNT_CD 
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	 ORDER BY A.MEASURE_CD, A.MEASURE_NM, A.WEEK_SEQ, A.PLAN_QTY

END
GO
