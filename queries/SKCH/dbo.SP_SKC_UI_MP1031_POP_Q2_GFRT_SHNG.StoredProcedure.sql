USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_POP_Q2_GFRT_SHNG]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_POP_Q2_GFRT_SHNG] (
	  @P_DP_VERSION		 NVARCHAR(30)	-- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	-- MP 버전		
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID  
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_POP_Q2_GFRT_SHNG
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > 공급 계획 분석
                     완제품 출하
-----------------------------------------------------------------------------------------------------------------------  
   CONTENTS        : ╬╬ 완제품 출하 PSI 산출
                     1. 선적 기준 공급 필요량             : 재고 Netting 및 L/T를 감안한 선적 시점(납기)의 Demand
					 2. CY 재고 차감                      : Σ(CY 재고(I) - 선적 기준 공급 필요량(S))
                     3. 완제품 출하 기준 공급 필요량      : 재고 Netting 및 L/T를 감안한 출하 시점(납기)의 Demand
					 4. 완제품 출하 기준 공급 계획        : MP 출하일 기준 공급계획					
					 5. 차이 누계                         : Σ(완제품 출하 기준 공급 계획 - 완제품 출하 기준 공급 필요량)
					 6. 완제품 출하 기준 공급 필요량 합계 : Σ(완제품 출하 기준 공급 필요량)
					 7. 완제품 출하 기준 공급 계획 합계   : Σ(완제품 출하 기준 공급 계획)
					 8. 차이 합계                         : Σ(완제품 출하 기준 공급 계획 합계 - 완제품 출하 기준 공급 필요량 합계)
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
   2024-08-06  Zionex         신규 생성 (화면 성능을 고려한 분리 구현 - 테이블화)
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_POP_Q2_GFRT_SHNG' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_POP_Q2_GFRT_SHNG 'DP-202407-01-M','MP-20240814-01-M-06','zionex8'
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
	  완제품 출하 PSI 대상 목록 수집
	  1. 임가공 제외 
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD,     I.BRND_NM,    I.GRADE_CD, I.GRADE_NM
		 , I.ITEM_CD,     I.ITEM_NM,    I.ITEM_TP,  I.CORP_CD
		 , I.CORP_NM,     I.PLNT_CD,    I.PLNT_NM,  I.SALES_ZONE
		 , I.MEASURE_CD,  I.MEASURE_NM, C.DT_TYPE,  C.REP_DT
		 , C.REP_DT_DESC, C.YYYY,       C.YYYYMM,   C.PLAN_DT
		 , C.DAT
		 , CONVERT(NUMERIC(18, 6), 0) AS CDC_STCK_QTY -- 울산 재고
		 , CONVERT(NUMERIC(18, 6), 0) AS CY_STCK_QTY  -- CY 재고		 
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY     -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0) AS PSI_QTY      -- PSI산출용 개별수량
	  INTO #TB_PLAN
	  FROM (SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		         , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  A.CORP_CD
		         , A.CORP_NM,    B.PLNT_CD,    B.PLNT_NM,  D.SALES_ZONE
				 , M.MEASURE_CD, M.MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD			
			 INNER
			  JOIN ( SELECT A.ATTR_01 AS CORP_CD
			              , A.ATTR_05 AS PLNT_CD
			              , A.ATTR_04 AS SALES_ZONE
			           FROM TB_DP_ACCOUNT_MST A WITH (NOLOCK)
					  WHERE 1 = 1
					    AND A.ACTV_YN = 'Y'
					  GROUP BY A.ATTR_01, A.ATTR_05, A.ATTR_04
				   ) D
			    ON D.CORP_CD = B.CORP_CD
			   AND D.PLNT_CD = B.PLNT_CD
			     , ( SELECT COMN_CD    AS MEASURE_CD
		                  , COMN_CD_NM AS MEASURE_NM
		               FROM FN_COMN_CODE ('MP1031_POP_2','')
	               ) M
			 WHERE 1 = 1
			   AND A.ITEM_TP <> 'GSUB'  -- 임가공 제외
			 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  A.CORP_CD
		            , A.CORP_NM,    B.PLNT_CD,    B.PLNT_NM,  D.SALES_ZONE
					, M.MEASURE_CD, M.MEASURE_NM
			 UNION ALL
			-- 품목 단위 목록 (합계 표현)
	        SELECT A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		         , A.ITEM_CD, A.ITEM_NM,    A.ITEM_TP
				 , M.MEASURE_TP AS CORP_CD
		         , M.MEASURE_TP AS CORP_NM
				 , M.MEASURE_TP AS PLNT_CD
				 , M.MEASURE_TP AS PLNT_NM				
				 , M.MEASURE_TP AS SALES_ZONE
				 , M.MEASURE_CD AS MEASURE_CD
				 , M.MEASURE_NM AS MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD			 
			     , ( SELECT '006'                               AS MEASURE_CD
	             	      , '완제품 출하 기준 공급 필요량 합계' AS MEASURE_NM
						  , 'ZZZZZZZ'                           AS MEASURE_TP
	             	  UNION ALL
					 SELECT '007'                               AS MEASURE_CD
	             	      , '완제품 출하 기준 공급 계획 합계'   AS MEASURE_NM
						  , 'ZZZZZZZZ'                          AS MEASURE_TP
					  UNION ALL
					 SELECT '008'                               AS MEASURE_CD
	             	      , '차이 합계'                         AS MEASURE_NM
						  , 'ZZZZZZZZZ'                         AS MEASURE_TP
	               ) M
			 WHERE 1 = 1	
			   AND A.ITEM_TP <> 'GSUB'  -- 임가공 제외
			 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  M.MEASURE_CD
					, M.MEASURE_NM, M.MEASURE_TP
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
	WHERE 1 = 1	 	 	

/*******************************************************************************************************************************************************
  [2] Collection
    - 항목 별 고정 데이터를 수집하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [DISPLAY 전용] 1. CY 재고 (BOH)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, SUM(A.QTY) AS CY_STCK_QTY
			  FROM ( -- 지점 및 직수출 CY 재고
			         SELECT C.ITEM_CD, D.PLNT_CD, B.QTY
					      , E.ATTR_04 AS SALES_ZONE
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
	                     ON D.CORP_CD       = C.CORP_CD
						AND D.LOCAT_CD      = C.LOCAT_CD
					  INNER
			           JOIN TB_DP_ACCOUNT_MST         E WITH (NOLOCK)
			             ON E.ID            = A.ACCOUNT_ID
			          WHERE 1 = 1
					    AND A.MP_VERSION_ID = @V_MP_VERSION
			            AND A.DP_VERSION_ID = @V_DP_VERSION
			            AND A.INV_TP        = 'CY'
						AND E.ACTV_YN       = 'Y'
					 -------------------------------------------
			          UNION ALL
					 -------------------------------------------
					 -- 법인향 CY 재고
			         SELECT C.ITEM_CD, D.PLNT_CD, B.QTY
					      , E.ATTR_04 AS SALES_ZONE
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
	                     ON D.CORP_CD       = C.CORP_CD
						AND D.LOCAT_CD      = C.LOCAT_CD
					  INNER
			           JOIN TB_DP_ACCOUNT_MST         E WITH (NOLOCK)
			             ON E.ID            = A.ACCOUNT_ID
			          WHERE 1 = 1
					    AND A.MP_VERSION_ID = @V_MP_VERSION
			            AND A.DP_VERSION_ID = @V_DP_VERSION
			            AND A.INV_TP        = 'CY'
						AND E.ACTV_YN       = 'Y'
				   ) A
			 GROUP BY A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.SALES_ZONE = Y.SALES_ZONE
     WHEN MATCHED 
     THEN UPDATE
             SET X.CY_STCK_QTY = Y.CY_STCK_QTY
	;

	/*************************************************************************************************************
	  [DISPLAY 전용] 2. 울산 재고 (CDC)
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
	            ON D.CORP_CD       = C.CORP_CD
			   AND D.LOCAT_CD      = C.LOCAT_CD
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

/*******************************************************************************************************************************************************
  [3] Processing
    - 각 Measure 별 수치를 계산 및 저장하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [PSI-1] 1. CY 재고 차감 (PSI 계산용 BOH)
	*************************************************************************************************************/
    MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, A.MEASURE_CD
	             , A.CY_STCK_QTY  AS PSI_QTY
				 , MIN(A.PLAN_DT) AS PLAN_DT
	          FROM #TB_PLAN A
	         WHERE 1 = 1
	           AND A.DT_TYPE     = 'W'
	           AND A.MEASURE_CD  = '002'
	           AND A.CY_STCK_QTY > 0
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, A.MEASURE_CD, A.CY_STCK_QTY
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.MEASURE_CD = Y.MEASURE_CD
	  AND X.PLAN_DT    = Y.PLAN_DT
     WHEN MATCHED 
     THEN UPDATE
             SET X.PSI_QTY = Y.PSI_QTY
	;

	/*************************************************************************************************************
	  [PSI-1] 2. 선적 기준 공급 필요량 (S) - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.SHMT_QTY                          AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHMT_DATE, 112) AS USABLE_DATE	-- 선적일 기준				 
			           FROM TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST  B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO  C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   --'DP-202406-03-M'
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHMT_QTY      > 0
						AND A.DMND_TP       = 'D'             -- 최종 독립 Demand
						AND B.ACTV_YN       = 'Y'
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
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '001'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = - Y.PLAN_QTY
	;
	
	/*************************************************************************************************************
	  [PSI-1] 3. CY 재고차감 (I) = 기말재고 (EOH)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.YYYYMM, A.PLAN_DT
			             , SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1					 
					   AND A.MEASURE_CD IN ('001', '002')
			         GROUP BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;
	
	/*****************************************************************************************************************
	  [PSI-2] 4. 완제품 출하 기준 공급 필요량 (S) - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)
	*****************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.SHNG_QTY                          AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE	-- 선적일 기준				 
			           FROM TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST  B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO  C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   --'DP-202406-03-M'
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0
						AND A.DMND_TP       = 'D'             -- 최종 독립 Demand
						AND B.ACTV_YN       = 'Y'
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
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '003'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = - Y.PLAN_QTY
	;	

	/*************************************************************************************************************
	  [PSI-2] 5. 완제품 출하 기준 공급 계획 (P)
	          - 울산CDC 이후의 공급계획은 이동 L/T 구간이므로 선적 공급계획(TB_SKC_MP_SHMT_PLAN) 활용.
			    (울산 CDC -> CY 창고 -> 해외 법인 창고)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.SHNG_QTY                          AS PLAN_QTY     -- 톤 단위 수량
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE  -- 출하일 기준				 
			           FROM TB_SKC_MP_SHMT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST   B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO   C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID = @V_MP_VERSION          	    	    
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 독립 Demand
						AND B.ACTV_YN       = 'Y'
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')		
			        /*
			         SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY     -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE  -- 출하일 기준				 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID     = @V_MP_VERSION          	    	    
          	            AND A.PLAN_QTY          > 0
						AND A.DMND_TP           = 'D'             -- 최종 독립 Demand						
						AND B.ACTV_YN           = 'Y'
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')			
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
	         GROUP BY A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '004'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI-2] 6. 차이 누계 (I) = 기말재고 (EOH)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE
			             , A.YYYYMM,  A.PLAN_DT, SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1					 
					   AND A.MEASURE_CD IN ('003', '004')
			         GROUP BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD
	  AND X.ITEM_CD    = Y.ITEM_CD
	  AND X.SALES_ZONE = Y.SALES_ZONE
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '005'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

/*******************************************************************************************************************************************************
  [4] Summary
    - 특정 Measure를 합산하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [단위 합계] 1. 완제품 출하 기준 공급 필요량 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '003' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '006'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [단위 합계] 2. 완제품 출하 기준 공급 계획 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '004' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '007'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [단위 합계] 3. 차이 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '005' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '008'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [SUMMARY] 주 / 년 단위 합산
	*************************************************************************************************************/	
	INSERT 
	  INTO #TB_PLAN
	     ( BRND_CD,     BRND_NM,    GRADE_CD,     GRADE_NM
		 , ITEM_CD,     ITEM_NM,    ITEM_TP,      CORP_CD
		 , CORP_NM,     PLNT_CD,    PLNT_NM,      SALES_ZONE
		 , MEASURE_CD,  MEASURE_NM, CDC_STCK_QTY, CY_STCK_QTY
		 , YYYY,        YYYYMM,     DT_TYPE,      REP_DT
		 , REP_DT_DESC, PLAN_DT,    PLAN_QTY,     DAT
		 )
	/*************************************************************************************
	  [주 단위 합산] 
	  001. 선적 기준 공급 필요량 
	  003. 완제품 출하 기준 공급 필요량
	  004. 완제품 출하 기준 공급 계획	 
	  006. 완제품 출하 기준 공급 필요량 합계
	  007. 완제품 출하 기준 공급 계획 합계
	*************************************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		 , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		 , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		 , A.YYYY,       A.YYYYMM
		 , 'S'                                               AS DT_TYPE
		 , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 , N'Sum'                                            AS REP_DT_DESC		 
		 , '999999'                                          AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0))                         AS PLAN_QTY
		 , MAX(A.DAT)                                        AS DAT
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.DT_TYPE     = 'W'
	   AND A.MEASURE_CD IN ('001', '003', '004', '006', '007')
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		    , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		    , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		    , A.YYYY,       A.YYYYMM
    ------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [주 단위 합산] 
	  002. CY 재고 차감
	  005. 차이 누계
	  008. 차이 합계
	***********************************************************************/
	SELECT A.BRND_CD,     A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		 , A.CORP_NM,     A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		 , A.MEASURE_CD,  A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		 , A.YYYY,        A.YYYYMM,     A.DT_TYPE,      A.REP_DT
		 , A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		          , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		          , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		          , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		          , A.YYYY,       A.YYYYMM,     A.DAT
				  , 'S'                                               AS DT_TYPE
			      , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
			      , N'Sum'                                            AS REP_DT_DESC		
			      , '999999'                                          AS PLAN_DT
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.MEASURE_CD, A.YYYYMM
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												)   AS PLAN_QTY			   
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.DT_TYPE     = 'W'
		        AND A.MEASURE_CD IN ('002', '005', '008')
	       ) A
	 GROUP BY A.BRND_CD,     A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		    , A.ITEM_CD,     A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		    , A.CORP_NM,     A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		    , A.MEASURE_CD,  A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		    , A.YYYY,        A.YYYYMM,     A.DT_TYPE,      A.REP_DT
			, A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***************************************************************************************
	  [년 단위 합산] 
	  001. 선적 기준 공급 필요량 
	  003. 완제품 출하 기준 공급 필요량
	  004. 완제품 출하 기준 공급 계획	 
	  006. 완제품 출하 기준 공급 필요량 합계
	  007. 완제품 출하 기준 공급 계획 합계
	***************************************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		 , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		 , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY		 
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
	  AND A.MEASURE_CD IN ('001', '003', '004', '006', '007')
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		    , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		    , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY		    
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [년 단위 합산] 
	  002. CY 재고 차감
	  005. 차이 누계
	  008. 차이 합계
	***********************************************************************/
	SELECT A.BRND_CD,     A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		 , A.CORP_NM,     A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		 , A.MEASURE_CD,  A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		 , A.YYYY,        A.YYYYMM,     A.DT_TYPE,      A.REP_DT
		 , A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		          , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		          , A.CORP_NM,    A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		          , A.MEASURE_CD, A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
				  , A.DAT
		          , '999999'                      AS YYYY
				  , '999999'                      AS YYYYMM     
			      , 'T'                           AS DT_TYPE
			      , N'Total'                      AS REP_DT
			      , N'Total'                      AS REP_DT_DESC			      
			      , '999999'                      AS PLAN_DT
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.MEASURE_CD--, A.YYYY
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												) AS PLAN_QTY		
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.MEASURE_CD IN ('002', '005', '008')
	       ) A
	 GROUP BY A.BRND_CD,     A.BRND_NM,    A.GRADE_CD,     A.GRADE_NM
		    , A.ITEM_CD,     A.ITEM_NM,    A.ITEM_TP,      A.CORP_CD
		    , A.CORP_NM,     A.PLNT_CD,    A.PLNT_NM,      A.SALES_ZONE
		    , A.MEASURE_CD,  A.MEASURE_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		    , A.YYYY,        A.YYYYMM,     A.DT_TYPE,      A.REP_DT
			, A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY

/*******************************************************************************************************************************************************
  [5] Saving
    - 상기 결과물을 정리하여 저장하는 영역
*******************************************************************************************************************************************************/

   /*************************************************************************************************************
	  [CY 재고 차감]
	  마이너스(-) 수량 0로 변경.	  
	*************************************************************************************************************/
	UPDATE P
	   SET P.PLAN_QTY = 0     
	  FROM #TB_PLAN P
	 WHERE 1 = 1
	   AND P.MEASURE_CD = '002'
	   AND P.PLAN_QTY   < 0

   /*************************************************************************************************************
	  [조회 제외 대상]
	  1. 대상 Measure 의 모든 수량이 0 인 경우, 조회대상에서 제외.
	  2. Total 수량이 0인 데이터가 다수인 관계로 추가된 제외 집합.	 	  
	*************************************************************************************************************/
	-- Total 열 기준 전체 0 인 데이터
	IF OBJECT_ID ('tempdb..#TB_COL_TOTAL_ZERO') IS NOT NULL DROP TABLE #TB_COL_TOTAL_ZERO
	SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.SALES_ZONE, A.PLNT_CD
	  INTO #TB_COL_TOTAL_ZERO
	  FROM ( -- Measure의 총량이 0 인 대상 수집	        
	         SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.SALES_ZONE, A.PLNT_CD
	              , SUM(ABS(A.PLAN_QTY)) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.SALES_ZONE, A.PLNT_CD) AS PLNT_PLAN_QTY -- 단위 Measure 기준
				  , SUM(ABS(A.PLAN_QTY)) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD)                          AS ITEM_PLAN_QTY -- 합계 Measure 기준
	           FROM #TB_PLAN A
	          WHERE A.REP_DT = 'Total'					   
		   ) A
	 WHERE 1 = 1
	   AND 0 = CASE WHEN LEFT(A.PLNT_CD, 1) = 'Z'  -- 합계 Measure
	                THEN A.ITEM_PLAN_QTY           -- 품목 단위 합계
					ELSE A.PLNT_PLAN_QTY           -- 플랜트 단위 합계
				END
	 GROUP BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.SALES_ZONE, A.PLNT_CD

	/*************************************************************************************************************
	  [데이터 생성]
	  - 공급 계획 분석 > 완제품 출하 화면 조회용 데이터
	  - 대량 데이터 조회로 인한 성능 이슈 대응 (MP 수립 후, 화면 데이터 저장)
	*************************************************************************************************************/
	DELETE FROM TB_SKC_MP_UI_GFRT_SHNG WHERE MP_VERSION_ID = @V_MP_VERSION

	INSERT 
	  INTO TB_SKC_MP_UI_GFRT_SHNG
         ( MP_VERSION_ID, ITEM_CD,     PLNT_CD,    SALES_ZONE
         , MEASURE_CD,    DT_TYPE,     YYYYMM,     PLAN_DT
         , DP_VERSION_ID, CORP_CD,     BRND_CD,    GRADE_CD
         , ITEM_NM,       PLNT_NM,     MEASURE_NM, CORP_NM
         , BRND_NM,       GRADE_NM,    ITEM_TP,    REP_DT
		 , REP_DT_DESC,   YYYY,        DAT,        CDC_STCK_QTY
		 , CY_STCK_QTY,   PLAN_QTY   
		 , CREATE_BY,     CREATE_DTTM, MODIFY_BY,  MODIFY_DTTM
		 )
	SELECT @V_MP_VERSION, A.ITEM_CD,  A.PLNT_CD,    A.SALES_ZONE
         , A.MEASURE_CD,  A.DT_TYPE,  A.YYYYMM,     A.PLAN_DT
         , @V_DP_VERSION, A.CORP_CD,  A.BRND_CD,    A.GRADE_CD
         , A.ITEM_NM,     A.PLNT_NM,  A.MEASURE_NM, A.CORP_NM
         , A.BRND_NM,     A.GRADE_NM, A.ITEM_TP,    A.REP_DT
		 , A.REP_DT_DESC, A.YYYY,     A.DAT,        A.CDC_STCK_QTY
		 , A.CY_STCK_QTY, A.PLAN_QTY
		 , @P_USER_ID,    GETDATE(),  @P_USER_ID,   GETDATE()
      FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND NOT EXISTS (SELECT 1
	                     FROM #TB_COL_TOTAL_ZERO Z
						WHERE Z.BRND_CD    = A.BRND_CD
						  AND Z.GRADE_CD   = A.GRADE_CD
						  AND Z.ITEM_CD    = A.ITEM_CD
						  AND Z.SALES_ZONE = A.SALES_ZONE
						  AND Z.PLNT_CD    = A.PLNT_CD
					  )
END
GO
