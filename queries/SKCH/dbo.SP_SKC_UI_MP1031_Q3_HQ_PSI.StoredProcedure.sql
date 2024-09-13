USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_Q3_HQ_PSI]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_Q3_HQ_PSI] (
	  @P_DP_VERSION		 NVARCHAR(30)	         -- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	         -- MP 버전	
    , @P_USER_ID		 NVARCHAR(100) = NULL    -- USER_ID   
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_Q3_HQ_PSI
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > PSI 및 공급 계획 확정
                     본사 PSI
  
   CONTENTS        : ╬╬ 울산 창고 완제품 / 임가공 / 사급자재 출하 PSI 산출
                     1. 출하 필요량    : 재고 Netting 및 L/T를 감안한 출하 시점(납기)의 Demand 
					 2. 생산 목표      : MP 출하일 기준 공급계획
					 3. 예상 창고 재고 : Σ(기초 재고(I) – 출하 필요량 합계(S) + 생산 목표 합계(P))					
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------  
   2024-08-05  Zionex         신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_Q3_HQ_PSI' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_Q3_HQ_PSI 'DP-202407-01-M','MP-20240814-01-M-06','zionex8'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_DP_VERSION), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION), '')					  
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID	 ), '')                 
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
	  본사 PSI 대상 목록 수집	 
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD, I.BRND_NM,    I.GRADE_CD,    I.GRADE_NM
		 , I.ITEM_CD, I.ITEM_NM,    I.ITEM_TP,     I.PLNT_CD
		 , I.PLNT_NM, I.SALES_ZONE, I.MEASURE_CD,  I.MEASURE_NM
		 , C.DT_TYPE, C.REP_DT,     C.REP_DT_DESC, C.YYYY
		 , C.YYYYMM,  C.PLAN_DT,    C.DAT	 
		 , CONVERT(NUMERIC(18, 6), 0) AS BOH_STCK_QTY -- 차월 예상 기초재고			 
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY     -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0) AS PSI_QTY      -- PSI산출용 개별수량
	  INTO #TB_PLAN
	  FROM (-- 권역 별 플랜트 단위 목록
	        -- 법인향 기준
	        SELECT A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		         , A.ITEM_CD, A.ITEM_NM,    A.ITEM_TP,    B.PLNT_CD
				 , B.PLNT_NM, C.SALES_ZONE, M.MEASURE_CD, M.MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD
			 INNER
			  JOIN ( SELECT A.ATTR_01              AS CORP_CD
			              , A.ATTR_05              AS PLNT_CD
			              , ISNULL(A.ATTR_04, 'X') AS SALES_ZONE
			           FROM TB_DP_ACCOUNT_MST A WITH (NOLOCK)
					  WHERE 1 = 1
					    AND A.ACTV_YN = 'Y'
					  GROUP BY A.ATTR_01, A.ATTR_05, A.ATTR_04
				   ) C
			    ON C.CORP_CD = B.CORP_CD
			   AND C.PLNT_CD = B.PLNT_CD
			     , ( SELECT COMN_CD    AS MEASURE_CD
	             	      , COMN_CD_NM AS MEASURE_NM
	             	   FROM FN_COMN_CODE ('MP1031_3','')
	               ) M
			 WHERE 1 = 1			
			 GROUP BY A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		            , A.ITEM_CD, A.ITEM_NM,    A.ITEM_TP,    B.PLNT_CD
				    , B.PLNT_NM, C.SALES_ZONE, M.MEASURE_CD, M.MEASURE_NM
			 UNION ALL
			-- 권역 별 플랜트 단위 목록
			-- 직수출, 지점 기준 (자사 -> 자사 투입량을 표현하기 위함)
	        SELECT A.BRND_CD, A.BRND_NM, A.GRADE_CD, A.GRADE_NM
		         , A.ITEM_CD, A.ITEM_NM, A.ITEM_TP,  B.PLNT_CD
				 , B.PLNT_NM
				 , 'ZZ' AS SALES_ZONE
				 , M.MEASURE_CD, M.MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD		 			
			     , ( SELECT COMN_CD    AS MEASURE_CD
	             	      , COMN_CD_NM AS MEASURE_NM
	             	   FROM FN_COMN_CODE ('MP1031_3','')
	               ) M
			 WHERE 1 = 1
			   AND B.PLNT_CD = '1110'     -- 울산 기준
			 GROUP BY A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		            , A.ITEM_CD, A.ITEM_NM,    A.ITEM_TP,    B.PLNT_CD
				    , B.PLNT_NM, M.MEASURE_CD, M.MEASURE_NM
			 UNION ALL
			-- 품목 단위 목록 (합계 표현)
	        SELECT A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		         , A.ITEM_CD, A.ITEM_NM,    A.ITEM_TP
				 , M.MEASURE_TP AS PLNT_CD
				 , M.MEASURE_TP AS PLNT_NM
				 , M.MEASURE_TP AS SALES_ZONE
				 , M.MEASURE_CD AS MEASURE_CD
				 , M.MEASURE_NM AS MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD
			 INNER
			  JOIN ( SELECT A.ATTR_01              AS CORP_CD
			              , A.ATTR_05              AS PLNT_CD
			              , ISNULL(A.ATTR_04, 'X') AS SALES_ZONE
			           FROM TB_DP_ACCOUNT_MST A WITH (NOLOCK)
					  WHERE 1 = 1
					    AND A.ACTV_YN = 'Y'
					  GROUP BY A.ATTR_01, A.ATTR_05, A.ATTR_04
				   ) C
			    ON C.CORP_CD = B.CORP_CD
			   AND C.PLNT_CD = B.PLNT_CD
			     , ( SELECT '003'              AS MEASURE_CD
	             	      , '출하 필요량 합계' AS MEASURE_NM
						  , 'ZZZZZZ'           AS MEASURE_TP
	             	  UNION ALL
					 SELECT '004'              AS MEASURE_CD
	             	      , '생산 목표 합계'   AS MEASURE_NM
						  , 'ZZZZZZZ'          AS MEASURE_TP
					  UNION ALL
					 SELECT '004_2'            AS MEASURE_CD
	             	      , '안전 재고 보충량' AS MEASURE_NM
						  , 'ZZZZZZZ2'         AS MEASURE_TP
					  UNION ALL
					 SELECT '005'              AS MEASURE_CD
	             	      , '예상 창고 재고'   AS MEASURE_NM
						  , 'ZZZZZZZZ'         AS MEASURE_TP
	               ) M
			 WHERE 1 = 1			
			 GROUP BY A.BRND_CD,    A.BRND_NM, A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,    A.ITEM_NM, A.ITEM_TP,  M.MEASURE_CD
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
			  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
			  UNION ALL
			 SELECT	'M'                                               AS DT_TYPE
				  , CONCAT(C.YYYY, N'년 ', RIGHT(C.YYYYMM, 2), N'월') AS REP_DT
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
	  [DISPLAY 전용] 차월 예상 기초재고 (CDC = BOH)
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
	           AND A.DT_TYPE      = 'W'
	           AND A.MEASURE_CD   = '005'
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
	  [PSI] 2. 출하필요량 (S) - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)
	*************************************************************************************************************/		
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- 법인향 출하필요량
			         SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.SHNG_QTY                          AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE -- 출하일 기준				 
			           FROM TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST  B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO  C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID     = @V_DP_VERSION   --'DP-202406-03-M'
						AND A.MP_VERSION_ID     = @V_MP_VERSION
          	            AND A.SHNG_QTY          > 0						
						AND A.DMND_TP           = 'D'             -- 최종 독립 Demand
						--AND LEFT(A.DMND_ID, 1) <> 'S'             -- 안전재고 보충량 제외
						AND B.ACTV_YN           = 'Y'
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')
					  UNION ALL
					 -- 직수출 자사투입량
					 SELECT A.ITEM_CD, C.PLNT_CD
					      , 'ZZ'                                AS SALES_ZONE
			              , A.REQ_QTY                           AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112) AS USABLE_DATE -- 출하일 기준					 
			           FROM TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)				  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO  C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID     = @V_DP_VERSION   --'DP-202406-03-M' 
						AND A.MP_VERSION_ID     = @V_MP_VERSION
          	            AND A.REQ_QTY           > 0						
						AND A.DMND_TP           = 'C'             -- 최종 독립 Demand	
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
	  [PSI] 3. 생산 목표 (P) = 공급계획
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, A.SALES_ZONE, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- 법인향 
			         SELECT A.ITEM_CD, C.PLNT_CD
					      , B.ATTR_04                           AS SALES_ZONE
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY  -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE						 
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
						--AND LEFT(A.DMND_ID, 1) <> 'S'             -- 안전재고 보충량 제외
				        AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')
					  UNION ALL
					 -- 직수출
					 SELECT A.ITEM_CD, C.PLNT_CD
					      , 'ZZ'                                AS SALES_ZONE
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY  -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE						 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)				
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID     = @V_MP_VERSION          	    	    
          	            AND A.PLAN_QTY          > 0
						AND A.DMND_TP           = 'C'             -- 최종 독립 Demand	
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
	  AND X.MEASURE_CD = '002'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI] 4. 안전 재고 보충량 (P) = 공급계획
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
	  [단위 합계] 1. 출하 필요량 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '001' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
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
	  [단위 합계] 2. 생산 목표 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '002' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '004'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [단위 합계] 3. 안전 재고 보충량
	*************************************************************************************************************/	
	--MERGE 
 --    INTO #TB_PLAN X
 --   USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
	--		  FROM #TB_PLAN A
	--		 WHERE 1 = 1     
	--		   AND A.MEASURE_CD = '004_2' 
	--		 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
 --         ) Y
 --      ON X.ITEM_CD    = Y.ITEM_CD
	--  AND X.YYYYMM     = Y.YYYYMM
	--  AND X.PLAN_DT    = Y.PLAN_DT
	--  AND X.MEASURE_CD = '004_2'
 --    WHEN MATCHED 
 --    THEN UPDATE
 --            SET X.PLAN_QTY  = Y.PLAN_QTY
	--;

	/*************************************************************************************************************
	  [SUMMARY] 주 / 년 단위 합산
	*************************************************************************************************************/	
	INSERT 
	  INTO #TB_PLAN
	     ( BRND_CD,      BRND_NM,     GRADE_CD,   GRADE_NM
		 , ITEM_CD,      ITEM_NM,     ITEM_TP,    SALES_ZONE
		 , PLNT_CD,      PLNT_NM,     MEASURE_CD, MEASURE_NM
		 , BOH_STCK_QTY, YYYY,        YYYYMM,     DT_TYPE
		 , REP_DT,       REP_DT_DESC, PLAN_DT,    PLAN_QTY
		 , DAT
		 )
	/***********************************************************************
	  [주 단위 합산] 
	  1) 출하 필요량      (MEASURE_CD = 001)
	  2) 생산 목표        (MEASURE_CD = 002)
	  3) 출하 필요량 합계 (MEASURE_CD = 003)
	  4) 생산 목표 합계   (MEASURE_CD = 004)
	  5) 안전 재고 보충량 (MEASURE_CD = 004_2)
	***********************************************************************/
	SELECT A.BRND_CD,      A.BRND_NM, A.GRADE_CD,   A.GRADE_NM
		 , A.ITEM_CD,      A.ITEM_NM, A.ITEM_TP,    A.SALES_ZONE
		 , A.PLNT_CD,      A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM
		 , A.BOH_STCK_QTY, A.YYYY,    A.YYYYMM
		 , 'S'                                               AS DT_TYPE
		 , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 , N'Sum'                                            AS REP_DT_DESC		 
		 , '999999'                                          AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0))                         AS PLAN_QTY
		 , MAX(A.DAT)                                        AS DAT
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.DT_TYPE = 'W'
	   AND A.MEASURE_CD <> '005'
	 GROUP BY A.BRND_CD,      A.BRND_NM, A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD,      A.ITEM_NM, A.ITEM_TP,    A.SALES_ZONE
		    , A.PLNT_CD,      A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM
		    , A.BOH_STCK_QTY, A.YYYY,    A.YYYYMM
    ------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [주 단위 합산] 예상 창고 재고 (MEASURE_CD = 005)
	***********************************************************************/
	SELECT A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		 , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		 , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		 , A.BOH_STCK_QTY, A.YYYY,        A.YYYYMM,     A.DT_TYPE
		 , A.REP_DT,       A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,      A.BRND_NM, A.GRADE_CD,   A.GRADE_NM
		          , A.ITEM_CD,      A.ITEM_NM, A.ITEM_TP,    A.SALES_ZONE
		          , A.PLNT_CD,      A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM
		          , A.BOH_STCK_QTY, A.YYYY,    A.YYYYMM,     A.DAT
				  , 'S'                                               AS DT_TYPE
			      , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
			      , N'Sum'                                            AS REP_DT_DESC		
			      , '999999'                                          AS PLAN_DT
			      , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.ITEM_CD, A.YYYYMM 
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												)   AS PLAN_QTY
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.DT_TYPE    = 'W'
		        AND A.MEASURE_CD = '005'
	       ) A
	 GROUP BY A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		    , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		    , A.BOH_STCK_QTY, A.YYYY,        A.YYYYMM,     A.DT_TYPE
		    , A.REP_DT,       A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY		
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [년 단위 합산]
	  1) 출하 필요량      (MEASURE_CD = 001)
	  2) 생산 목표        (MEASURE_CD = 002)
	  3) 출하 필요량 합계 (MEASURE_CD = 003)
	  4) 생산 목표 합계   (MEASURE_CD = 004)
	  5) 안전 재고 보충량 (MEASURE_CD = 004_2)
	***********************************************************************/
	SELECT A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		 , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		 , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		 , A.BOH_STCK_QTY
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
	   AND A.MEASURE_CD <> '005'
	 GROUP BY A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		    , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		    , A.BOH_STCK_QTY
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [년 단위 합산] 예상 창고 재고 (MEASURE_CD = 005)
	***********************************************************************/
	SELECT A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		 , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		 , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		 , A.BOH_STCK_QTY, A.YYYY,        A.YYYYMM,     A.DT_TYPE
		 , A.REP_DT,       A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
		 , MAX(A.DAT) AS DAT
	  FROM ( SELECT A.BRND_CD,      A.BRND_NM, A.GRADE_CD,   A.GRADE_NM
		          , A.ITEM_CD,      A.ITEM_NM, A.ITEM_TP,    A.SALES_ZONE
		          , A.PLNT_CD,      A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM
		          , A.BOH_STCK_QTY, A.DAT
				  , '999999'                      AS YYYY   
				  , '999999'                      AS YYYYMM     
			      , 'T'                           AS DT_TYPE
			      , N'Total'                      AS REP_DT
			      , N'Total'                      AS REP_DT_DESC			      
			      , '999999'                      AS PLAN_DT
			      , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.ITEM_CD--, A.YYYY 
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
											          ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
					                            ) AS PLAN_QTY
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.MEASURE_CD = '005'	
	       ) A
	 GROUP BY A.BRND_CD,      A.BRND_NM,     A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD,      A.ITEM_NM,     A.ITEM_TP,    A.SALES_ZONE
		    , A.PLNT_CD,      A.PLNT_NM,     A.MEASURE_CD, A.MEASURE_NM
		    , A.BOH_STCK_QTY, A.YYYY,        A.YYYYMM,     A.DT_TYPE
		    , A.REP_DT,       A.REP_DT_DESC, A.PLAN_DT,    A.PLAN_QTY
		
/*******************************************************************************************************************************************************
  [5] Saving
    - 상기 결과물을 정리하여 저장하는 영역
*******************************************************************************************************************************************************/
		
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
	              , SUM(ABS(A.PLAN_QTY)) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.SALES_ZONE, A.PLNT_CD
				                              )                               AS PLNT_PLAN_QTY -- 단위 Measure 기준
				  -- [예상 창고 재고] 차월 예상 기초 재고 수량만 있는 케이스 제외 
				  -- 재고 누적합이므로, 수량 값들이 없음에도 합계 표현되는 현상 필터 역할
				  , SUM(CASE WHEN A.MEASURE_CD <> '005'  
				             THEN ABS(A.PLAN_QTY)
							 ELSE 0
						 END
					   ) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD) AS ITEM_PLAN_QTY -- 합계 Measure 기준
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
	  - 본사 PSI 화면 조회용 데이터
	  - 대량 데이터 조회로 인한 성능 이슈 대응 (MP 수립 후, 화면 데이터 저장)
	*************************************************************************************************************/
	DELETE FROM TB_SKC_MP_UI_HQ_PSI WHERE MP_VERSION_ID = @V_MP_VERSION

	INSERT 
	  INTO TB_SKC_MP_UI_HQ_PSI
         ( MP_VERSION_ID, ITEM_CD,      PLNT_CD,     SALES_ZONE
         , MEASURE_CD,    DT_TYPE,      YYYYMM,      PLAN_DT
         , DP_VERSION_ID, BRND_CD,      GRADE_CD,    ITEM_NM
         , PLNT_NM,       MEASURE_NM,   BRND_NM,     GRADE_NM
         , ITEM_TP,       REP_DT,       REP_DT_DESC, YYYY
         , DAT,           BOH_STCK_QTY, PLAN_QTY
		 , CREATE_BY,     CREATE_DTTM,  MODIFY_BY,   MODIFY_DTTM
		 )	
	SELECT @V_MP_VERSION, A.ITEM_CD,      A.PLNT_CD,     A.SALES_ZONE
         , A.MEASURE_CD,  A.DT_TYPE,      A.YYYYMM,      A.PLAN_DT
         , @V_DP_VERSION, A.BRND_CD,      A.GRADE_CD,    A.ITEM_NM
         , A.PLNT_NM,     A.MEASURE_NM,   A.BRND_NM,     A.GRADE_NM
         , A.ITEM_TP,     A.REP_DT,       A.REP_DT_DESC, A.YYYY
         , A.DAT,         A.BOH_STCK_QTY, A.PLAN_QTY
		 , @P_USER_ID,    GETDATE(),      @P_USER_ID,    GETDATE()
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
