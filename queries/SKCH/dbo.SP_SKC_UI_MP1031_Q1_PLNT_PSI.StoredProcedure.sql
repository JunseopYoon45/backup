USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_Q1_PLNT_PSI]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_Q1_PLNT_PSI] (
	  @P_DP_VERSION		 NVARCHAR(30)	-- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	-- MP 버전		
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID   
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
  PROCEDURE NAME  : SP_SKC_UI_MP1031_Q1_PLNT_PSI
  COPYRIGHT       : Zionex
  REMARK          : 공급 계획 > 공급 계획 수립 > PSI 및 공급 계획 확정
                    법인 창고 PSI

  CONTENTS        : ╬╬ SKCA, SKCA 법인 제품/창고별 PSI 산출 (A199, B199는 본사 PSI에 포함)
                    1. 수요계획                    : 확정 수요계획 (DP)
					2. 예상 창고 입고 (공급 계획)  : MP 납품일 기준 공급계획
					3. 예상 창고 입고 (In-Transit) : In-Transit 도착일 기준
					4. 예상 창고 재고              : Σ(법인 창고 재고(I) – 수요계획(S) + 예상 창고 입고(P))
					5. 예상 선적 (CY + 공급 계획)  : MP 선적일 기준 공급계획 + CY 선적 L/T 반영일 기준
					6. 예상 In-Transit 재고        : Σ(In-Transit 재고(I) – 예상 창고 입고(S) + 예상 선적(P))
-----------------------------------------------------------------------------------------------------------------------
    DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
    2024-08-05  Zionex          신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_Q1_PLNT_PSI' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_Q1_PLNT_PSI 'DP-202407-01-M','MP-20240809-01-M-02','zionex8'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_DP_VERSION	), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION	), '')			 				  
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID		), '')                
                   + ''''

DECLARE @V_DP_VERSION	  NVARCHAR(30) = @P_DP_VERSION		-- DP 버전
	  , @V_MP_VERSION	  NVARCHAR(30) = @P_MP_VERSION		-- MP 버전	  	 
	  , @V_DTF_DATE		  DATETIME
	  , @V_FROM_DATE	  DATETIME
	  , @V_VAR_START_DATE DATETIME
	  , @V_TO_DATE		  DATETIME	

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
   
    /*************************************************************************************************************
	  법인 PSI 대상 목록 수집
	  1. 본사 제외
	  2. 직수출 제외
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD,  I.BRND_NM,     I.GRADE_CD,   I.GRADE_NM
		 , I.ITEM_CD,  I.ITEM_NM,     I.ITEM_TP,    I.CORP_CD
		 , I.CORP_NM,  I.PLNT_CD,     I.PLNT_NM,    I.BOD_D_LT
		 , I.BOD_W_LT, M.MEASURE_CD,  M.MEASURE_NM, C.DT_TYPE
		 , C.REP_DT,   C.REP_DT_DESC, C.YYYY,       C.YYYYMM
		 , C.PLAN_DT,  C.DAT
		 , CONVERT(NUMERIC(18, 6), 0.00) AS CDC_STCK_QTY  -- 울산 재고
		 , CONVERT(NUMERIC(18, 6), 0.00) AS CY_STCK_QTY   -- CY 재고
	     , CONVERT(NUMERIC(18, 6), 0.00) AS IN_TRNS_QTY   -- In-transit 재고
		 , CONVERT(NUMERIC(18, 6), 0.00) AS PLNT_STCK_QTY -- 법인재고			 
		 , CONVERT(NUMERIC(18, 6), 0.00) AS PLAN_QTY      -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0.00) AS PSI_QTY       -- 예상 창고 재고 PSI산출용 개별수량
		 , CONVERT(NUMERIC(18, 6), 0.00) AS ITRNS_PSI_QTY -- 예상 In-Transit 재고 PSI산출용 개별수량
	  INTO #TB_PLAN
	  FROM (SELECT A.BRND_CD,  A.BRND_NM,  A.GRADE_CD, A.GRADE_NM
		         , A.ITEM_CD,  A.ITEM_NM,  A.ITEM_TP,  A.CORP_CD
		         , A.CORP_NM,  B.PLNT_CD,  B.PLNT_NM,  C.BOD_D_LT			
				 , CONCAT(C.BOD_W_LT, ' (', C.BOD_D_LT, ' Days)') AS BOD_W_LT
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD
			 INNER
			  JOIN (SELECT A.PLNT_CD                                                              AS PLNT_CD
                         , MAX(ISNULL(A.SHIP_CONF_LT, 0))                                         AS BOD_D_LT
                         , CONVERT(NUMERIC(3, 1), ROUND(MAX(ISNULL(A.SHIP_CONF_LT, 0)) / 7.0, 1)) AS BOD_W_LT
                      FROM TB_SKC_DP_BOD_MST A WITH (NOLOCK)
                     GROUP BY A.PLNT_CD
                   ) C
			    ON C.PLNT_CD = B.PLNT_CD
			 WHERE 1 = 1
			   AND A.CORP_CD     <> '1000'           -- 본사 제외
			   AND B.PLNT_CD NOT IN ('A199', 'B199') -- 직수출 제외
			 GROUP BY A.BRND_CD,  A.BRND_NM, A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,  A.ITEM_NM, A.ITEM_TP,  A.CORP_CD
		            , A.CORP_NM,  B.PLNT_CD, B.PLNT_NM,  C.BOD_D_LT
					, C.BOD_W_LT
		   ) I
	 CROSS 
	 APPLY ( SELECT	'W'                                               AS DT_TYPE
				  , FORMAT(MAX(C.DAT),'yy-MM-dd')                     AS REP_DT
				  , CONCAT('W',SUBSTRING(C.PARTWK, 5, LEN(C.PARTWK))) AS REP_DT_DESC
  				  , C.YYYY                                            AS YYYY
				  , C.YYYYMM                                          AS YYYYMM
				  , C.PARTWK                                          AS PLAN_DT
				  , MAX(C.DAT)                                        AS DAT
			   FROM TB_CM_CALENDAR C WITH (NOLOCK)
			  WHERE 1 = 1
			    AND C.DAT_ID >= @V_FROM_DATE
			    AND C.DAT_ID <  @V_VAR_START_DATE
			  GROUP BY YYYYMM, PARTWK, YYYY
			  UNION ALL
			 SELECT	'M'                                               AS DT_TYPE
				  ,	CONCAT(C.YYYY, N'년 ', RIGHT(C.YYYYMM, 2), N'월') AS REP_DT
				  , CONCAT(C.YYYY, N'년 ', RIGHT(C.YYYYMM, 2), N'월') AS REP_DT_DESC
  				  , C.YYYY                                            AS YYYY
				  , C.YYYYMM                                          AS YYYYMM
				  , C.YYYYMM                                          AS PLAN_DT
				  , MAX(C.DAT)                                        AS DAT
			   FROM TB_CM_CALENDAR C WITH (NOLOCK)
			  WHERE 1 = 1
			    AND C.DAT_ID >= @V_VAR_START_DATE
			    AND C.DAT_ID <= @V_TO_DATE
			  GROUP BY C.MM, C.YYYYMM, C.YYYY
	      ) C 
	    , ( SELECT COMN_CD    AS MEASURE_CD
		         , COMN_CD_NM AS MEASURE_NM
		      FROM FN_COMN_CODE ('MP1031_1','')
	      ) M
	WHERE 1 = 1	
	
/*******************************************************************************************************************************************************
  [2] Collection
    - 항목 별 고정 데이터를 수집하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [DISPLAY 전용] 1. In-transit 재고
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
	  [DISPLAY 전용] 2. CY 재고
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, SUM(A.QTY) AS CY_STCK_QTY
			  FROM ( -- 지점 및 직수출 CY 재고			        
			         SELECT C.ITEM_CD, D.PLNT_CD, B.QTY
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
			            AND A.INV_TP        = 'CY'
					 -------------------------------------------
			          UNION ALL
					 -------------------------------------------
					 -- 법인향 CY 재고					 
			         SELECT C.ITEM_CD, D.PLNT_CD, B.QTY
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
			            AND A.INV_TP        = 'CY'
				   ) A
			 GROUP BY A.ITEM_CD, A.PLNT_CD
          ) Y
       ON X.PLNT_CD = Y.PLNT_CD  
	  AND X.ITEM_CD = Y.ITEM_CD	 
     WHEN MATCHED 
     THEN UPDATE
             SET X.CY_STCK_QTY = Y.CY_STCK_QTY
	;

	/*************************************************************************************************************
	  [DISPLAY 전용] 3. 울산 재고 (CDC)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT C.ITEM_CD, SUM(B.QTY) AS CDC_STCK_QTY
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
             SET X.CDC_STCK_QTY = Y.CDC_STCK_QTY
	;

    /*************************************************************************************************************
	  [DISPLAY 전용] 4. 법인 재고 (BOH)
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
	           AND A.DT_TYPE       = 'W'
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
	  [PSI] 2. 예상 In-Transit 재고 (PSI 계산용 BOH In-Transit)
	        -> 첫 번째 주에 In-transit PSI 수량 설정 (누적 합산 시, 시작점)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( -- In-Transit 재고
			SELECT A.ITEM_CD, A.PLNT_CD, A.MEASURE_CD
	             , A.IN_TRNS_QTY  AS PSI_QTY
				 , MIN(A.PLAN_DT) AS PLAN_DT
	          FROM #TB_PLAN A
	         WHERE 1 = 1
	           AND A.DT_TYPE     = 'W'
	           AND A.MEASURE_CD  = '006'
	           AND A.IN_TRNS_QTY > 0
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.MEASURE_CD, A.IN_TRNS_QTY
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.MEASURE_CD = Y.MEASURE_CD
	  AND X.PLAN_DT    = Y.PLAN_DT
     WHEN MATCHED 
     THEN UPDATE
             SET X.ITRNS_PSI_QTY = Y.PSI_QTY   -- 예상 In-transit PSI 용도
	;

	/*************************************************************************************************************
	  [PSI] 3. 예상 선적 (CY + 공급계획) 
	        -> [CY 재고] (In-transit PSI 계산용)	        
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- 법인향 CY 재고					 
			         SELECT C.ITEM_CD, D.PLNT_CD
					      , B.QTY AS PLAN_QTY
						  , A.ETD AS USABLE_DATE -- 선적일(출항예정일)  DATEADD(DAY, 7, A.ESTIMT_USABLE_DATE) AS USABLE_DATE	-- In-Transit 입고일 + 7일 적용 (현업 요청 사항)					 
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
						AND A.INV_TP        = 'CY'
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
	  AND X.MEASURE_CD = '005'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY      = Y.PLAN_QTY
			   , X.ITRNS_PSI_QTY = Y.PLAN_QTY   -- 예상 In-transit PSI 용도
	;

	/*************************************************************************************************************
	  [PSI] 4. 예상 선적 (CY + 공급계획) 
	        -> [공급 계획] (In-transit PSI 계산용)
			-> 선적 공급계획
	        -> 기 선적된 공급계획은 운송되고 있음을 가정하고, In-transit 수량으로 정의됨.	       
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- 선적 공급계획 
			         SELECT A.ITEM_CD, B.PLNT_CD
			              , A.SHMT_QTY                        AS PLAN_QTY    -- 톤 단위 수량
						  , CONVERT(DATETIME, SHMT_DATE, 112) AS USABLE_DATE -- 납품일 기준				 
			           FROM TB_SKC_MP_SHMT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					     ON B.LOCAT_CD	= A.TO_LOCAT_CD
          	          WHERE 1 = 1
          	            AND A.MP_VERSION_ID = @V_MP_VERSION   --'MP-20240628-03-M-08'--@V_MP_VERSION    						
          	            AND A.SHMT_QTY      > 0
				        AND (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')
					/*
			         SELECT A.ITEM_CD, B.PLNT_CD
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.SHMT_DATE, 112) AS USABLE_DATE -- 선적일 기준				 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					     ON B.LOCAT_CD	= A.TO_LOCAT_CD
          	          WHERE 1 = 1
          	            AND A.MP_VERSION_ID = @V_MP_VERSION   --'MP-20240628-03-M-08'--@V_MP_VERSION    						
          	            AND A.PLAN_QTY      > 0
				        AND (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')	
					*/
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '005'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY      = X.PLAN_QTY      + Y.PLAN_QTY  -- 선적 기준 공급계획 (기존 CY 수량에서 더함)
			   , X.ITRNS_PSI_QTY = X.ITRNS_PSI_QTY + Y.PLAN_QTY  -- 예상 In-transit PSI 용도 (기존 CY 수량에서 더함)
	;

	/*************************************************************************************************************
	  [PSI] 5. 수요계획 (S) = 출하 수요계획 (Demand)
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
					    UNION ALL
					   SELECT C.YYYYMM AS PLAN_DT
					     FROM TB_CM_CALENDAR C WITH (NOLOCK)
					    WHERE 1 = 1
					      AND C.DAT_ID >= @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					      AND C.DAT_ID <= @V_TO_DATE        --CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					      AND C.DAT	    = CONVERT(DATETIME, D.DUE_DATE, 112)
					      AND C.DAT	    = D.DUE_DATE
					    GROUP BY C.MM, C.YYYYMM, C.YYYY
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
	  [PSI] 6. 예상 창고 입고 (P : 공급계획)
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
			        /* 
					 SELECT A.ITEM_CD, B.PLNT_CD
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.DLVY_DATE, 112) AS USABLE_DATE -- 납품일 기준				 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					     ON B.LOCAT_CD	= A.TO_LOCAT_CD
          	          WHERE 1 = 1
          	            AND A.MP_VERSION_ID = @V_MP_VERSION   --'MP-20240628-03-M-08'--@V_MP_VERSION    						
          	            AND A.PLAN_QTY      > 0
				        AND (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')
					*/
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
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
             SET X.PLAN_QTY      = Y.PLAN_QTY
			   , X.PSI_QTY       = Y.PLAN_QTY    -- 예상 창고 재고 PSI 용도
			   , X.ITRNS_PSI_QTY = - Y.PLAN_QTY  -- 예상 In-transit PSI 용도
	;

	/*************************************************************************************************************
	  [PSI] 7. 예상 창고 입고 (P : In-transit) 
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
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = CONVERT(DATETIME, A.USABLE_DATE, 112)
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
          ) Y
       ON X.PLNT_CD = Y.PLNT_CD  
	  AND X.ITEM_CD = Y.ITEM_CD	
	  AND X.PLAN_DT = Y.PLAN_DT
	  AND X.MEASURE_CD = '003'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY      = Y.PLAN_QTY
			   , X.PSI_QTY       = Y.PLAN_QTY    -- 예상 창고 재고 PSI 용도
			   , X.ITRNS_PSI_QTY = - Y.PLAN_QTY  -- 예상 In-transit PSI 용도
	;
	
	/*************************************************************************************************************
	  [PSI 누적합산] 8. 예상 창고재고 (I) = 기말재고 (EOH)
	        001 : 수요계획
			002 : 예상 창고 입고 (In-Transit)
			003 : 예상 창고 입고 (공급 계획)
			004 : 예상 창고 재고
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
					   AND MEASURE_CD IN ('001', '002', '003', '004')
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
	  [PSI 누적합산] 9. 예상 In-Transit 재고 (I) = 기말재고 (EOH)
	        006 : 예상 In-Transit 재고
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT
	             , SUM(A.ITRNS_PSI_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD
				                                  ORDER BY A.YYYYMM,  A.PLAN_DT
									         ) AS PLAN_QTY
	          FROM (SELECT A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.ITRNS_PSI_QTY) AS ITRNS_PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1
					   AND MEASURE_CD IN ('002', '003', '005', '006')
			         GROUP BY A.PLNT_CD, A.ITEM_CD, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '006'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

/*******************************************************************************************************************************************************
  [4] Summary
    - 특정 Measure를 합산하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [SUMMARY] 주 / 년 단위 합산
	*************************************************************************************************************/	
	INSERT 
	  INTO #TB_PLAN
	     ( BRND_CD,       BRND_NM,      GRADE_CD,    GRADE_NM
		 , ITEM_CD,       ITEM_NM,      ITEM_TP,     CORP_CD
		 , CORP_NM,       PLNT_CD,      PLNT_NM,     MEASURE_CD
		 , MEASURE_NM,    CDC_STCK_QTY, CY_STCK_QTY, IN_TRNS_QTY
		 , PLNT_STCK_QTY, BOD_W_LT,     BOD_D_LT,    YYYY
		 , YYYYMM,        DT_TYPE,      REP_DT,      REP_DT_DESC		 
		 , PLAN_DT,       PLAN_QTY,     DAT
		 )
	/***********************************************************************
	  [주 단위 합산] 합계 유형의 합산
	   001. 수요계획
	   002. 예상 재고 입고 (공급계획)
	   003. 예상 재고 입고 (In-transit)	   	    
	***********************************************************************/
	SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		 , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		 , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		 , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
		 , A.YYYYMM
		 , 'S'                                               AS DT_TYPE
		 , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 , N'Sum'                                            AS REP_DT_DESC		 
		 , '999999'                                          AS PLAN_DT		 
		 , SUM(ISNULL(A.PLAN_QTY,0))                         AS PLAN_QTY
		 , MAX(A.DAT)                                        AS DAT
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND DT_TYPE = 'W'
	   AND A.MEASURE_CD IN ('001', '002', '003', '005')
	 GROUP BY A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		    , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		    , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		    , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
		    , A.YYYYMM
    ------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [주 단위 합산] 누적 유형의 합산
	   004. 예상 창고 재고
	   005. 예상 In-transit 재고
	***********************************************************************/
	SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		 , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		 , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		 , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
		 , A.YYYYMM,        A.DT_TYPE,      A.REP_DT,      A.REP_DT_DESC
		 , A.PLAN_DT,       A.PLAN_QTY
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		          , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		          , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		          , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
				  , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
				  , A.YYYYMM,        A.DAT
				  , 'S'                                               AS DT_TYPE
			      , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
			      , N'Sum'                                            AS REP_DT_DESC
			      , '999999'                                          AS PLAN_DT				 
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.MEASURE_CD, A.YYYYMM
				                                     ORDER BY A.MEASURE_CD, A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												)   AS PLAN_QTY			   
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.DT_TYPE     = 'W'
		        AND A.MEASURE_CD IN ('004', '006')
	       ) A
	 GROUP BY A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		    , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		    , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		    , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
		    , A.YYYYMM,        A.DT_TYPE,      A.REP_DT,      A.REP_DT_DESC
		    , A.PLAN_DT,       A.PLAN_QTY		
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [Total 단위 합산] 합계 유형의 합산
	   001. 수요계획
	   002. 예상 재고 입고 (공급계획)
	   003. 예상 재고 입고 (In-transit)
	***********************************************************************/
	SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		 , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		 , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		 , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT
		 , '999999'                  AS YYYY
		 , '999999'                  AS YYYYMM
		 , 'T'                       AS DT_TYPE
		 , N'Total'                  AS REP_DT
		 , N'Total'                  AS REP_DT_DESC		
		 , '999999'                  AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0)) AS PLAN_QTY
		 , MAX(A.DAT)                AS DAT
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.MEASURE_CD IN ('001', '002', '003', '005')
	 GROUP BY A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		    , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		    , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		    , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [Total 단위 합산] 누적 유형의 합산
	   004. 예상 창고 재고
	   005. 예상 In-transit 재고
	***********************************************************************/
	SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		 , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		 , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		 , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
		 , A.YYYYMM,        A.DT_TYPE,      A.REP_DT,      A.REP_DT_DESC
		 , A.PLAN_DT,       A.PLAN_QTY	
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		          , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		          , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		          , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
				  , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.DAT
				  , '999999'                      AS YYYY
				  , '999999'                      AS YYYYMM     
			      , 'T'                           AS DT_TYPE
			      , N'Total'                      AS REP_DT
			      , N'Total'                      AS REP_DT_DESC			      
			      , '999999'                      AS PLAN_DT
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.MEASURE_CD--, A.YYYY
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												) AS PLAN_QTY		
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.MEASURE_CD IN ('004', '006')
	       ) A
	 GROUP BY A.BRND_CD,       A.BRND_NM,      A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,       A.ITEM_NM,      A.ITEM_TP,     A.CORP_CD
		    , A.CORP_NM,       A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD
		    , A.MEASURE_NM,    A.CDC_STCK_QTY, A.CY_STCK_QTY, A.IN_TRNS_QTY
		    , A.PLNT_STCK_QTY, A.BOD_W_LT,     A.BOD_D_LT,    A.YYYY
			, A.YYYYMM,        A.DT_TYPE,      A.REP_DT,      A.REP_DT_DESC
			, A.PLAN_DT,       A.PLAN_QTY
		
/*******************************************************************************************************************************************************
  [5] Saving
    - 상기 결과물을 정리하여 저장하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [조회 제외 대상]
	  1. 대상의 Measure 의 모든 수량이 0 인 경우, 조회대상에서 제외
	  2. Total 수량이 0인 데이터가 다수인 관계로 추가된 집합임.
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_COL_TOTAL_ZERO') IS NOT NULL DROP TABLE #TB_COL_TOTAL_ZERO
	SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
	  INTO #TB_COL_TOTAL_ZERO
	  FROM ( -- Measure의 총량이 0 인 대상 수집
	         SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
	              , SUM(ABS(A.PLAN_QTY)) AS PLAN_QTY
	           FROM #TB_PLAN A
	          WHERE A.REP_DT = 'Total'
	          GROUP BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
		   ) A
	 WHERE A.PLAN_QTY = 0

	/*************************************************************************************************************
	  [데이터 생성]
	  - 법인 PSI 화면 조회용 데이터
	  - 대량 데이터 조회로 인한 성능 이슈 대응 (MP 수립 후, 화면 데이터 저장)
	*************************************************************************************************************/
	DELETE FROM TB_SKC_MP_UI_PLNT_PSI WHERE MP_VERSION_ID = @V_MP_VERSION

	INSERT 
	  INTO TB_SKC_MP_UI_PLNT_PSI
         ( MP_VERSION_ID, ITEM_CD,     PLNT_CD,       MEASURE_CD
		 , DP_VERSION_ID, CORP_CD,     BRND_CD,       GRADE_CD
         , ITEM_NM,       PLNT_NM,     MEASURE_NM,    CORP_NM
         , BRND_NM,       GRADE_NM,    ITEM_TP,       BOD_W_LT
         , DT_TYPE,       REP_DT,      REP_DT_DESC,   YYYY
         , YYYYMM,        PLAN_DT,     DAT,           CDC_STCK_QTY
         , CY_STCK_QTY,   IN_TRNS_QTY, PLNT_STCK_QTY, PLAN_QTY
         , CREATE_BY,     CREATE_DTTM, MODIFY_BY,     MODIFY_DTTM
		 ) 
	SELECT @V_MP_VERSION, A.ITEM_CD,     A.PLNT_CD,       A.MEASURE_CD
	     , @V_DP_VERSION, A.CORP_CD,     A.BRND_CD,       A.GRADE_CD
		 , A.ITEM_NM,     A.PLNT_NM,     A.MEASURE_NM,    A.CORP_NM
	     , A.BRND_NM,     A.GRADE_NM,    A.ITEM_TP,       A.BOD_W_LT
	     , A.DT_TYPE,     A.REP_DT,      A.REP_DT_DESC,   A.YYYY
		 , A.YYYYMM,      A.PLAN_DT,     A.DAT,           A.CDC_STCK_QTY
		 , A.CY_STCK_QTY, A.IN_TRNS_QTY, A.PLNT_STCK_QTY, A.PLAN_QTY
		 , @P_USER_ID,    GETDATE(),     @P_USER_ID,      GETDATE()
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND NOT EXISTS (SELECT 1
	                     FROM #TB_COL_TOTAL_ZERO Z
						WHERE Z.BRND_CD  = A.BRND_CD
						  AND Z.GRADE_CD = A.GRADE_CD
						  AND Z.ITEM_CD  = A.ITEM_CD
						  AND Z.PLNT_CD  = A.PLNT_CD
					  )
 END
GO
