USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_POP_Q8]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_POP_Q8] (
	  @P_DP_VERSION		 NVARCHAR(30)	-- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	-- MP 버전	
	, @P_BRND_CD		 NVARCHAR(MAX)	-- Brand코드	
	, @P_GRADE_CD		 NVARCHAR(MAX)	-- 그레이드코드
	, @P_ITEM_CD		 NVARCHAR(30)	-- 제품코드	
	, @P_ITEM_NM		 NVARCHAR(30)	-- 제품명	
	, @P_ITEM_TP		 NVARCHAR(30)	-- 제품타입	
	, @P_CORP_CD         NVARCHAR(30)   -- 법인코드	
	, @P_LANG_CD		 NVARCHAR(10)   -- 다국어처리
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID		 NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_POP_Q8
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > 공급 계획 분석
                     DMT 생산
-----------------------------------------------------------------------------------------------------------------------  
   CONTENTS        : ╬╬ DMT 생산 PSI 산출
                     1. Molten 출하 기준 공급 필요량        : 재고 Netting 및 L/T를 감안한 출하 시점의 Demand (= 고객 납품)
					 2. CHDM 투입 필요량                    : 재고 Netting 및 L/T를 감안한 출하 시점의 Demand (= CHDM 공정 투입)
					 3. Flake 출하 기준 공급 필요량         : 재고 Netting 및 L/T를 감안한 출하 시점의 Demand (= 고객 납품)
                     4. Briquette 출하 기준 공급 필요량     : 재고 Netting 및 L/T를 감안한 출하 시점의 Demand (= 고객 납품)
					 5. DMT 생산 필요량 (Molten)            : Molten 출하 기준 공급 필요량 + CHDM 투입 필요량	
					 6. DMT 생산 목표   (Molten)            : Molten 출하일 기준 공급계획					
					 7. 차이 누계       (Molten)            : Σ(Molten DMT 생산 목표 - Molten DMT 생산 필요량)
				     8. DMT 생산 필요량 (Flake + Briquette) : 출하 기준 공급 필요량 (Flake + Briquette)
					 9. DMT 생산 목표   (Flake + Briquette) : 출하일 기준 공급계획 (Flake + Briquette)			
					10. 차이 누계       (Flake + Briquette) : Σ(DMT 생산 목표(Flake + Briquette) - DMT 생산 필요량(Flake + Briquette))
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
   2024-07-16  Zionex          신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_POP_Q8' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_POP_Q8 'DP-202407-01-M','MP-20240823-01-M-10','ALL','ALL','','','','ALL','kr','zionex8',''
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
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD 		), '')  
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
	  , @V_CORP_CD		  NVARCHAR(30) = REPLACE(@P_CORP_CD,  'ALL', '')
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
	  DMT 생산 PSI 대상 목록 수집
	  1. 대상 품목 : DMT
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD,     I.BRND_NM,    I.GRADE_CD, I.GRADE_NM
	     , I.ITEM_CD,     I.ITEM_NM,    I.ITEM_TP,  I.DMT_TP
		 , I.MEASURE_CD,  I.MEASURE_NM, C.DT_TYPE,  C.REP_DT
		 , C.REP_DT_DESC, C.YYYY,       C.YYYYMM,   C.PLAN_DT		 
		 , CONVERT(NUMERIC(18, 6), 0) AS BOH_STCK_QTY -- 차월 예상 기초 재고
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY     -- 계획수량
		 , CONVERT(NUMERIC(18, 6), 0) AS PSI_QTY      -- PSI산출용 개별수량
	  INTO #TB_PLAN
	  FROM (SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		         , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  M.DMT_TP
				 , M.MEASURE_CD, M.MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN TB_CM_ITEM_MST         C WITH (NOLOCK)
			    ON C.ID = A.ITEM_MST_ID
			 INNER
			  JOIN ( SELECT COMN_CD     AS MEASURE_CD
		                  , COMN_CD_NM  AS MEASURE_NM
						  , ATTR_01_VAL AS DMT_TP
		               FROM FN_COMN_CODE ('MP1031_POP_8','')
	               ) M
				ON M.DMT_TP = C.ATTR_02  -- DMT 유형 (Molten, Flake, Briquette)
			 WHERE 1 = 1
			   AND A.ITEM_TP    = 'GFRT' 
			   AND C.ATTR_04    = '27'   -- DMT
			   AND C.DP_PLAN_YN = 'Y'			  
			   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
			   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	           AND ((@V_ITEM_CD = '') OR (A.ITEM_CD LIKE '%' + @V_ITEM_CD + '%'))
	           AND ((@V_ITEM_NM = '') OR (A.ITEM_NM LIKE '%' + @V_ITEM_NM + '%')) 
	           AND ((@V_ITEM_TP = '') OR (A.ITEM_TP LIKE '%' + @V_ITEM_TP + '%'))
	           AND ((@V_CORP_CD = '') OR (A.CORP_CD	   =       @V_CORP_CD))
			 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  M.DMT_TP
					, M.MEASURE_CD, M.MEASURE_NM  
		     UNION ALL
			-- 품목 단위 목록 (합계 표현)
	        SELECT A.BRND_CD, A.BRND_NM
			     , M.MEASURE_TP AS GRADE_CD
				 , M.MEASURE_TP AS GRADE_NM		      
				 , M.MEASURE_TP AS ITEM_CD
		         , M.MEASURE_TP AS ITEM_NM
				 , M.MEASURE_TP AS ITEM_TP
				 , M.MEASURE_TP AS DMT_TP
				 , M.MEASURE_CD AS MEASURE_CD
				 , M.MEASURE_NM AS MEASURE_NM				
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)			
			 INNER
			  JOIN TB_CM_ITEM_MST         C WITH (NOLOCK)
			    ON C.ID       = A.ITEM_MST_ID
			     , ( SELECT '002.1'                               AS MEASURE_CD
	             	      , 'DMT 생산 필요량 (Molten)'            AS MEASURE_NM
						  , 'ZZZZZZZ'                             AS MEASURE_TP						  
	             	  UNION ALL
					 SELECT '002.2'                               AS MEASURE_CD
	             	      , 'DMT 생산 목표 (Molten)'              AS MEASURE_NM
						  , 'ZZZZZZZZ'                            AS MEASURE_TP						
					  UNION ALL
					 SELECT '002.3'                               AS MEASURE_CD
	             	      , '차이 누계 (Molten)'                  AS MEASURE_NM
						  , 'ZZZZZZZZZ'                           AS MEASURE_TP						  
					  UNION ALL
					 SELECT '005'                                 AS MEASURE_CD
	             	      , 'DMT 생산 필요량 (Flake + Briquette)' AS MEASURE_NM
						  , 'ZZZZZZZ'                             AS MEASURE_TP						  
	             	  UNION ALL
					 SELECT '006'                                 AS MEASURE_CD
	             	      , 'DMT 생산 목표 (Flake + Briquette)'   AS MEASURE_NM
						  , 'ZZZZZZZZ'                            AS MEASURE_TP						  
					  UNION ALL
					 SELECT '007'                                 AS MEASURE_CD
	             	      , '차이 누계 (Flake + Briquette)'       AS MEASURE_NM
						  , 'ZZZZZZZZZ'                           AS MEASURE_TP		
	               ) M
			 WHERE 1 = 1
			   AND A.ITEM_TP    = 'GFRT'  
			   AND C.ATTR_04    = '27'    -- DMT
			   AND C.DP_PLAN_YN = 'Y'
			   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
			   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	           AND ((@V_ITEM_CD = '') OR (A.ITEM_CD  LIKE '%' + @V_ITEM_CD + '%'))
	           AND ((@V_ITEM_NM = '') OR (A.ITEM_NM  LIKE '%' + @V_ITEM_NM + '%')) 
	           AND ((@V_ITEM_TP = '') OR (A.ITEM_TP  LIKE '%' + @V_ITEM_TP + '%'))
	           AND ((@V_CORP_CD = '') OR (A.CORP_CD	    =       @V_CORP_CD))
			 GROUP BY A.BRND_CD, A.BRND_NM, M.MEASURE_CD, M.MEASURE_NM, M.MEASURE_TP
		   ) I
	 CROSS 
	 APPLY ( SELECT	'W'                                               AS DT_TYPE
				  , FORMAT(MAX(C.DAT),'yy-MM-dd')                     AS REP_DT
				  , CONCAT('W',SUBSTRING(C.PARTWK, 5, LEN(C.PARTWK))) AS REP_DT_DESC
  				  , C.YYYY                                            AS YYYY
				  , C.YYYYMM                                          AS YYYYMM
				  , C.PARTWK                                          AS PLAN_DT
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
	  [DISPLAY 전용] 1. 차월 예상 기초재고 (BOH)
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
			   AND C.ITEM_GRP_CD   = '27'   -- DMT			 
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

	/*****************************************************************************************************************
	  [PSI-1] 1. Molten 출하 기준 공급 필요량 - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)	
	*****************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.DMT_TP, B.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                              AS ITEM_CD	
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
						  , E.ATTR_04                              AS ITEM_GRP_CD
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)					 
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = A.ITEM_CD			 
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'        
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND E.ITEM_TP_ID    = 'GFRT'   						
						AND E.ATTR_04       = '27'            -- DMT
						AND E.ATTR_02       = '070'           -- Molten
			         /*
			         SELECT A.ITEM_CD                              AS ITEM_CD	
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
						  , D.ITEM_GRP_CD
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
					     ON D.ITEM_CD  = A.ITEM_CD
						AND D.LOCAT_CD = C.LOCAT_CD
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = D.ITEM_CD			 
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'        
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND D.ITEM_TP       = 'GFRT'   						
						AND D.ITEM_GRP_CD   = '27'            -- DMT
						AND E.ATTR_02       = '070'           -- Molten	
					*/
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.DMT_TP, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.DMT_TP     = Y.DMT_TP
	  AND X.PLAN_DT    = Y.PLAN_DT	  
	  AND X.MEASURE_CD = '001'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY			
	;

	/*****************************************************************************************************************
	  [PSI-1] 2. CHDM 투입 필요량 - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)	
	*****************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.DMT_TP, B.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                              AS ITEM_CD	
			              , B.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
					  INNER
					   JOIN TB_CM_ITEM_MST         B
					     ON B.ITEM_CD = A.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'C'             -- 다음 생산 공정에 연계되는 종속 Demand
						AND B.ITEM_TP_ID    = 'GFRT'          
						AND B.ATTR_04       = '27'            -- DMT
						AND B.ATTR_02       = '070'           -- Molten				 
/*
			         SELECT A.ITEM_CD                              AS ITEM_CD	
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
					     ON D.ITEM_CD  = A.ITEM_CD
						AND D.LOCAT_CD = C.LOCAT_CD
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = D.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'C'             -- 다음 생산 공정에 연계되는 종속 Demand
						AND D.ITEM_TP       = 'GFRT'          
						AND D.ITEM_GRP_CD   = '27'            -- DMT
						AND E.ATTR_02       = '070'           -- Molten	
*/						
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.DMT_TP, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.DMT_TP     = Y.DMT_TP
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY			
	;
	
	/*****************************************************************************************************************
	  [PSI-1] 3. Flake 출하 기준 공급 필요량 - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)	
	*****************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.DMT_TP, B.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                              AS ITEM_CD
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  					  
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = A.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'   
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND E.ITEM_TP_ID    = 'GFRT'          
						AND E.ATTR_04       = '27'            -- DMT
						AND E.ATTR_02       = '040'           -- Flake							
			         /*
			         SELECT A.ITEM_CD                              AS ITEM_CD
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
					     ON D.ITEM_CD  = A.ITEM_CD
						AND D.LOCAT_CD = C.LOCAT_CD
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = D.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'   
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND D.ITEM_TP       = 'GFRT'          
						AND D.ITEM_GRP_CD   = '27'            -- DMT
						AND E.ATTR_02       = '040'           -- Flake
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
	         GROUP BY A.ITEM_CD, A.DMT_TP, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.DMT_TP     = Y.DMT_TP
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '003'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY			
	;

	/*****************************************************************************************************************
	  [PSI-1] 4. Briquette 출하 기준 공급 필요량 - Demand 기반으로 L/T을 반영한 요구량임. (계획수립 결과와는 무관함)	
	*****************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.DMT_TP, B.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD                              AS ITEM_CD			              
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  					  
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = A.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'     
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND E.ITEM_TP_ID    = 'GFRT'          
						AND E.ATTR_04       = '27'            -- DMT
						AND E.ATTR_02       = '010'           -- Briquette	
			         /*
			         SELECT A.ITEM_CD                              AS ITEM_CD
			              , E.ATTR_02                              AS DMT_TP
			              , A.SHNG_QTY                             AS PLAN_QTY  
						  , CONVERT(DATETIME, A.SHNG_DATE, 112)    AS USABLE_DATE  -- 출하일
			           FROM TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
					  INNER
					   JOIN VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
					     ON D.ITEM_CD  = A.ITEM_CD
						AND D.LOCAT_CD = C.LOCAT_CD
					  INNER
			           JOIN TB_CM_ITEM_MST         E WITH (NOLOCK)
			             ON E.ITEM_CD  = D.ITEM_CD
          	          WHERE 1 = 1          	       	  
          	            AND A.DP_VERSION_ID = @V_DP_VERSION   -- 'DP-202406-03-M'     
						AND A.MP_VERSION_ID = @V_MP_VERSION
          	            AND A.SHNG_QTY      > 0	
						AND A.DMND_TP       = 'D'             -- 최종 판매 Demand
						AND D.ITEM_TP       = 'GFRT'          
						AND D.ITEM_GRP_CD   = '27'            -- DMT
						AND E.ATTR_02       = '010'           -- Briquette
					 */
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.ITEM_CD, A.DMT_TP, B.PLAN_DT
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.DMT_TP     = Y.DMT_TP
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '004'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY			
	;

	/*************************************************************************************************************
	  [PSI-2] 1. DMT 생산 필요량 (Molten) 
	  001. Molten 출하 기준 공급 필요량	
	  002. CHDM 투입 필요량
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( -- CHDM 생산필요량 = CHDM 출하 기준 공급 필요량 + CHDM 투입 필요량
	        SELECT A.BRND_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1					 
			   AND A.MEASURE_CD IN ('001', '002')
			 GROUP BY A.BRND_CD, A.YYYYMM, A.PLAN_DT
          ) Y
       ON X.BRND_CD    = Y.BRND_CD		  
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002.1'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
			   , X.PSI_QTY   = - Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI-2] 2. DMT 생산 목표 (Molten)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.BRND_CD, B.PLAN_DT, SUM(A.PLAN_QTY)        AS PLAN_QTY				 
	          FROM ( SELECT B.ATTR_06                           AS BRND_CD		            
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE -- 생산일 기준					 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_CM_ITEM_MST    B WITH (NOLOCK)
					     ON B.ITEM_CD = A.ITEM_CD					 
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID = @V_MP_VERSION  
          	            AND A.PLAN_QTY      > 0					
						AND B.ITEM_TP_ID    = 'GFRT'          
						AND B.ATTR_04       = '27'            -- DMT	
						AND B.ATTR_02       = '070'           -- Molten
			         /*
			         SELECT B.BRND_CD                           AS BRND_CD				      
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE -- 생산일 기준					 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO B WITH (NOLOCK)
					     ON B.ITEM_CD  = A.ITEM_CD
						AND B.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = B.LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID     = @V_MP_VERSION  
          	            AND A.PLAN_QTY          > 0					
						AND B.ITEM_TP           = 'GFRT'          
						AND B.ITEM_GRP_CD       = '27'            -- DMT
					 */
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.BRND_CD, B.PLAN_DT
          ) Y
       ON X.BRND_CD    = Y.BRND_CD	  
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002.2'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI-2] 3. 차이 누계 (Molten) = 기말재고 (EOH)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.BRND_CD, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.BRND_CD
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.BRND_CD, A.YYYYMM,  A.PLAN_DT, SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1					 
					   AND A.MEASURE_CD IN ('002.1', '002.2')
			         GROUP BY A.BRND_CD, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.BRND_CD    = Y.BRND_CD	  
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '002.3'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;	

	/*************************************************************************************************************
	  [PSI-3] 1. DMT 생산 필요량 (Flake + Briquette) 
	  003. Flake 출하 기준 공급 필요량
	  004. Briquette 출하 기준 공급 필요량
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( -- CHDM 생산필요량 = Flake 출하 기준 공급 필요량 + Briquette 출하 기준 공급 필요량
	        SELECT A.BRND_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1					 
			   AND A.MEASURE_CD IN ('003', '004')
			 GROUP BY A.BRND_CD, A.YYYYMM, A.PLAN_DT
          ) Y
       ON X.BRND_CD    = Y.BRND_CD	  
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '005'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
			   , X.PSI_QTY   = - Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI-3] 2. DMT 생산 목표 (Flake + Briquette)
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.BRND_CD, B.PLAN_DT, SUM(A.PLAN_QTY)        AS PLAN_QTY				 
	          FROM ( SELECT B.ATTR_06                           AS BRND_CD				      
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE -- 생산일 기준					 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_CM_ITEM_MST    B WITH (NOLOCK)
					     ON B.ITEM_CD = A.ITEM_CD					 
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID = @V_MP_VERSION  
          	            AND A.PLAN_QTY      > 0					
						AND B.ITEM_TP_ID    = 'GFRT'          
						AND B.ATTR_04       = '27'            -- DMT	
						AND B.ATTR_02      <> '070'           -- Molten 제외 (Flake, Briquette)
			         /*
			         SELECT B.BRND_CD                           AS BRND_CD				      
			              , A.PLAN_QTY * 1000                   AS PLAN_QTY    -- KG 단위로 환산 (공급계획은 톤 단위 수량임. 재고 수량은 KG 단위 이므로, 동기화 필요) 
						  , CONVERT(DATETIME, A.PLAN_DATE, 112) AS USABLE_DATE -- 생산일 기준					 
			           FROM TB_SKC_MP_RT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN VW_LOCAT_ITEM_DTS_INFO B WITH (NOLOCK)
					     ON B.ITEM_CD  = A.ITEM_CD
						AND B.LOCAT_CD = A.TO_LOCAT_CD
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = B.LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
          	            AND A.MP_VERSION_ID     = @V_MP_VERSION  
          	            AND A.PLAN_QTY          > 0					
						AND B.ITEM_TP           = 'GFRT'          
						AND B.ITEM_GRP_CD       = '27'            -- DMT
					 */
				   ) A
			 CROSS 
			 APPLY ( SELECT C.PARTWK AS PLAN_DT
			           FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_FROM_DATE      --CONVERT(DATETIME, '20240701', 112)
					    AND C.DAT_ID  < @V_VAR_START_DATE --CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.YYYYMM, C.PARTWK, C.YYYY
					  UNION ALL
					 SELECT C.YYYYMM AS PLAN_DT
					   FROM TB_CM_CALENDAR C WITH (NOLOCK)
					  WHERE 1 = 1
					    AND C.DAT_ID >= @V_VAR_START_DATE  -- CONVERT(DATETIME, '20241001', 112)--@V_VAR_START_DATE
					    AND C.DAT_ID <= @V_TO_DATE         -- CONVERT(DATETIME, '20241231', 112)--@V_TO_DATE
					    AND C.DAT	  = A.USABLE_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY
		           ) B 
	         WHERE 1 = 1
	         GROUP BY A.BRND_CD, B.PLAN_DT
          ) Y
       ON X.BRND_CD    = Y.BRND_CD		 
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '006'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
			   , X.PSI_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [PSI-3] 3. 차이 누계 (Flake + Briquette) = 기말재고 (EOH)	  
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.BRND_CD, A.YYYYMM, A.PLAN_DT
	             , SUM(A.PSI_QTY) OVER (PARTITION BY A.BRND_CD
				                            ORDER BY A.YYYYMM,  A.PLAN_DT
									   ) AS PLAN_QTY
	          FROM (SELECT A.BRND_CD, A.YYYYMM,  A.PLAN_DT, SUM(A.PSI_QTY) AS PSI_QTY
			          FROM #TB_PLAN A
			         WHERE 1 = 1					 
					   AND A.MEASURE_CD IN ('005', '006')
			         GROUP BY A.BRND_CD, A.YYYYMM, A.PLAN_DT
		           ) A	         
          ) Y
       ON X.BRND_CD    = Y.BRND_CD	  
	  AND X.YYYYMM     = Y.YYYYMM	  
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '007'
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
	     ( BRND_CD,    BRND_NM,    GRADE_CD,    GRADE_NM
		 , ITEM_CD,    ITEM_NM,    ITEM_TP,     BOH_STCK_QTY
		 , MEASURE_CD, MEASURE_NM, YYYY,        YYYYMM
		 , DT_TYPE,    REP_DT,     REP_DT_DESC, PLAN_DT
		 , PLAN_QTY
		 )
	/*************************************************************************************
	  [주 단위 합산] 
	  001. Molten 출하 기준 공급 필요량
	  002. CHDM 투입 필요량
	  002.1. DMT 생산 필요량 (Molten)
	  002.2. DMT 생산 목표   (Molten)
	  003. Flake 출하 기준 공급 필요량
	  004. Briquette 출하 기준 공급 필요량	  
	  005. DMT 생산 필요량 (Flake + Briquette)
	  006. DMT 생산 목표   (Flake + Briquette)
	*************************************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  A.BOH_STCK_QTY
		 , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,     A.YYYYMM
		 , 'S'                                               AS DT_TYPE
		 , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 , N'Sum'                                            AS REP_DT_DESC		 
		 , '999999'                                          AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0))                         AS PLAN_QTY
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.DT_TYPE         = 'W'
	   AND A.MEASURE_CD NOT IN ('002.3', '007')
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  A.BOH_STCK_QTY
		    , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,     A.YYYYMM
    ------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [주 단위 합산] 	 
	  002.3. 차이 누계 (Molten)
	  007.   차이 누계 (Flake + Briquette)
	***********************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		 , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,        A.YYYYMM
		 , A.DT_TYPE,    A.REP_DT,     A.REP_DT_DESC, A.PLAN_DT
		 , A.PLAN_QTY
	  FROM ( SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		          , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,  A.BOH_STCK_QTY
		          , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,     A.YYYYMM
				  , 'S'                                               AS DT_TYPE
			      , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
			      , N'Sum'                                            AS REP_DT_DESC		
			      , '999999'                                          AS PLAN_DT
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.BRND_CD, A.ITEM_CD, A.MEASURE_CD, A.YYYYMM
				                                     ORDER BY A.YYYYMM,  A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												)   AS PLAN_QTY			   
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.DT_TYPE     = 'W'
		        AND A.MEASURE_CD IN ('002.3', '007')
	       ) A
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		    , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,        A.YYYYMM
		    , A.DT_TYPE,    A.REP_DT,     A.REP_DT_DESC, A.PLAN_DT
		    , A.PLAN_QTY
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***************************************************************************************
	  [년 단위 합산] 
	  001. Molten 출하 기준 공급 필요량
	  002. CHDM 투입 필요량
	  002.1. DMT 생산 필요량 (Molten)
	  002.2. DMT 생산 목표   (Molten)
	  003. Flake 출하 기준 공급 필요량
	  004. Briquette 출하 기준 공급 필요량	  
	  005. DMT 생산 필요량 (Flake + Briquette)
	  006. DMT 생산 목표   (Flake + Briquette)
	***************************************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		 , A.MEASURE_CD, A.MEASURE_NM
		 , '999999'                  AS YYYY
		 , '999999'                  AS YYYYMM
		 , 'T'                       AS DT_TYPE
		 , N'Total'                  AS REP_DT
		 , N'Total'                  AS REP_DT_DESC		
		 , '999999'                  AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0)) AS PLAN_QTY
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.MEASURE_CD NOT IN ('002.3', '007')
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		    , A.MEASURE_CD, A.MEASURE_NM
	------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [년 단위 합산] 	
	  002.3. 차이 누계 (Molten)
	  007.   차이 누계 (Flake + Briquette)	
	***********************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		 , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,        A.YYYYMM
		 , A.DT_TYPE,    A.REP_DT,     A.REP_DT_DESC, A.PLAN_DT
		 , A.PLAN_QTY
	  FROM ( SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		          , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		          , A.MEASURE_CD, A.MEASURE_NM
				  , '999999'                      AS YYYY
				  , '999999'                      AS YYYYMM     
			      , 'T'                           AS DT_TYPE
			      , N'Total'                      AS REP_DT
			      , N'Total'                      AS REP_DT_DESC			      
			      , '999999'                      AS PLAN_DT
				  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.BRND_CD, A.ITEM_CD, A.MEASURE_CD--, A.YYYY
				                                     ORDER BY A.YYYYMM, A.PLAN_DT
													  ROWS BETWEEN UNBOUNDED PRECEDING 
													           AND UNBOUNDED FOLLOWING
												) AS PLAN_QTY		
		       FROM #TB_PLAN A
		      WHERE 1 = 1
		        AND A.MEASURE_CD IN ('002.3', '007')
	       ) A
	 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,    A.GRADE_NM
		    , A.ITEM_CD,    A.ITEM_NM,    A.ITEM_TP,     A.BOH_STCK_QTY
		    , A.MEASURE_CD, A.MEASURE_NM, A.YYYY,        A.YYYYMM
		    , A.DT_TYPE,    A.REP_DT,     A.REP_DT_DESC, A.PLAN_DT
		    , A.PLAN_QTY	

/*******************************************************************************************************************************************************
  [5] Searching
    - 상기 정리된 결과물을 조회하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  [화면 조회]
	*************************************************************************************************************/
	SELECT A.BRND_CD,    A.BRND_NM, A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM, A.BOH_STCK_QTY, A.MEASURE_CD
		 , A.MEASURE_NM, A.DT_TYPE, A.REP_DT,       A.REP_DT_DESC
		 , A.YYYY,       A.YYYYMM,  A.PLAN_DT
		 , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
	  FROM #TB_PLAN A
	 WHERE 1 = 1	 
	 ORDER BY A.BRND_CD,    A.BRND_NM, A.MEASURE_CD, A.GRADE_CD
	        , A.GRADE_NM,   A.ITEM_CD, A.ITEM_NM,    A.BOH_STCK_QTY
		    , A.MEASURE_NM, A.YYYY,    A.YYYYMM,     A.PLAN_DT

END
GO
