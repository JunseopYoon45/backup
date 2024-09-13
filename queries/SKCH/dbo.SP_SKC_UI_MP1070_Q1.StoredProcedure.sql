USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1070_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1070_Q1] (
	  @P_MP_VERSION		 NVARCHAR(30)	
	, @P_BRND_CD		 NVARCHAR(MAX)   = 'ALL'
	, @P_GRADE_CD 		 NVARCHAR(MAX)   = 'ALL'
	, @P_PLNT_CD		 NVARCHAR(30)    = 'ALL'
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1070_Q1
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 RTF > 법인 선적계획
-----------------------------------------------------------------------------------------------------------------------  
   CONTENTS        : 1. 본사 선적 : MP 선적일 기준 공급계획
					 2. 법인 입고 : Σ(법인 창고 재고(I) - 수요 계획(S) + In-transit 재고(P))
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
   2024-09-11  Zionex         신규 생성
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1070_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1070_Q1 'MP-20240910-03-M-02','ALL','ALL','ALL','I23671'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRND_CD	  ), '')			
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD	  ), '')			
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLNT_CD	  ), '')			
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID	  ), '')
                   + ''''

DECLARE @V_MP_VERSION	  NVARCHAR(30) = @P_MP_VERSION		-- MP 버전	 
	  , @V_DP_VERSION     NVARCHAR(30) 	
	  , @V_BRND_CD		  NVARCHAR(MAX) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(MAX) = REPLACE(@P_GRADE_CD, 'ALL', '')
	  , @V_PLNT_CD		  NVARCHAR(30)  = REPLACE(@P_PLNT_CD, 'ALL', '')
	  , @V_DTF_DATE		  DATETIME
	  , @V_FROM_DATE	  DATETIME   
	  , @V_VAR_START_DATE DATETIME
	  , @V_TO_DATE		  DATETIME	  

   EXEC SP_PGM_LOG  'MP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------
BEGIN

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
	SELECT @V_DP_VERSION = DMND_VER_ID
	  FROM TB_CM_CONBD_MAIN_VER_MST
	 WHERE ID = (SELECT CONBD_MAIN_VER_MST_ID 
				   FROM TB_CM_CONBD_MAIN_VER_DTL
				  WHERE SIMUL_VER_ID = @V_MP_VERSION 
				)

	SELECT @V_DTF_DATE		 = MA.DTF_DATE
		 , @V_FROM_DATE		 = MA.FROM_DATE
		 , @V_VAR_START_DATE = MA.VER_S_HORIZON_DATE 
		 , @V_TO_DATE		 = MA.TO_DATE
	  FROM TB_DP_CONTROL_BOARD_VER_MST MA
	 WHERE VER_ID = @V_DP_VERSION

    /*************************************************************************************************************
	  울산 선적 PSI 대상 목록 수집
	  1. 내수 제외 (내수는 선적하지 않으므로, 대상에서 제외.)	  
	*************************************************************************************************************/
	IF OBJECT_ID ('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN
	SELECT I.BRND_CD,  I.BRND_NM,    I.GRADE_CD,    I.GRADE_NM
		 , I.ITEM_CD,  I.ITEM_NM,    I.CORP_CD,     I.CORP_NM
		 , I.PLNT_CD,    I.PLNT_NM,  I.MEASURE_CD,  I.MEASURE_NM
		 , C.DT_TYPE,  C.REP_DT,     C.REP_DT_DESC, C.YYYY
		 , C.YYYYMM,   C.PLAN_DT,    C.DAT	 
		 , CONVERT(NUMERIC(18, 6), 0) AS PLAN_QTY      -- 계획수량
	  INTO #TB_PLAN
	  FROM (SELECT A.BRND_CD,    A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		         , A.ITEM_CD,    A.ITEM_NM,    A.CORP_CD,    A.CORP_NM
				 , B.PLNT_CD,    B.PLNT_NM,    M.MEASURE_CD, M.MEASURE_NM				 
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD
			     , ( SELECT COMN_CD    AS MEASURE_CD
		                  , COMN_CD_NM AS MEASURE_NM
		               FROM FN_COMN_CODE ('MP1070','')
	               ) M
			 WHERE 1 = 1
			   AND B.LOC_TP_NM = 'RDC'
			   AND B.CORP_CD != '1000'
			   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
			   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
			 GROUP BY A.BRND_CD,  A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		            , A.ITEM_CD,  A.ITEM_NM,    A.CORP_CD,    A.CORP_NM
					, B.PLNT_CD,  B.PLNT_NM,    M.MEASURE_CD, M.MEASURE_NM
			 UNION ALL
			-- 품목 단위 목록 (합계 표현)
	        SELECT A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		         , A.ITEM_CD, A.ITEM_NM    
				 , M.MEASURE_TP AS CORP_CD
		         , M.MEASURE_TP AS CORP_NM
				 , M.MEASURE_TP AS PLNT_CD
				 , M.MEASURE_TP AS PLNT_NM
				 , M.MEASURE_CD AS MEASURE_CD
				 , M.MEASURE_NM AS MEASURE_NM
	          FROM VW_LOCAT_ITEM_DTS_INFO A WITH (NOLOCK)
			 INNER
			  JOIN VW_LOCAT_DTS_INFO      B WITH (NOLOCK)
			    ON B.LOCAT_CD = A.LOCAT_CD			 
			     , ( SELECT '08'                         AS MEASURE_CD
	             	      , '제품 별 본사 선적 합계'	 AS MEASURE_NM
						  , 'ZZZZ'						 AS MEASURE_TP
					  UNION 
					 SELECT '09'                         AS MEASURE_CD
	             	      , '제품 별 법인 입고 합계'	 AS MEASURE_NM
						  , 'ZZZZ'						 AS MEASURE_TP
	               ) M
			 WHERE 1 = 1			
			   AND B.LOC_TP_NM = 'RDC'
			   AND B.CORP_CD != '1000'
			   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
			   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
			 GROUP BY A.BRND_CD,    A.BRND_NM,    A.GRADE_CD, A.GRADE_NM
		            , A.ITEM_CD,    A.ITEM_NM,    M.MEASURE_CD
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
  [2] Processing
    - 각 Measure 별 수치를 계산 및 저장하는 영역
*******************************************************************************************************************************************************/

	/*************************************************************************************************************
	  1. 본사 선적
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( SELECT A.ITEM_CD, C.PLNT_CD
			              , A.SHMT_QTY                          AS PLAN_QTY    -- 톤 단위 수량
						  , CONVERT(DATETIME, A.SHMT_DATE, 112) AS USABLE_DATE -- 선적일 기준					 
			           FROM TB_SKC_MP_SHMT_PLAN A WITH (NOLOCK)
					  INNER
					   JOIN TB_DP_ACCOUNT_MST B WITH (NOLOCK)
					     ON B.ID = A.ACCOUNT_ID
					  INNER
					   JOIN VW_LOCAT_DTS_INFO C WITH (NOLOCK)
					     ON C.LOCAT_CD = A.TO_LOCAT_CD     	   	  
          	          WHERE 1 = 1          	       	  
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
	         GROUP BY A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
          ) Y
       ON X.PLNT_CD    = Y.PLNT_CD  
	  AND X.ITEM_CD    = Y.ITEM_CD	
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '01'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  2. 법인 입고
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.PLNT_CD, B.PLAN_DT
	             , SUM(A.PLAN_QTY) AS PLAN_QTY				 
	          FROM ( -- In-transit 입고
					 SELECT C.ITEM_CD, D.PLNT_CD 
					      , B.QTY                AS PLAN_QTY
					      , A.ESTIMT_USABLE_DATE AS USABLE_DATE              -- DATEADD(DAY, 7, A.ESTIMT_USABLE_DATE) AS USABLE_DATE	-- In-Transit 입고일 + 7일 적용 (현업 요청 사항)
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
	  AND X.MEASURE_CD = '02'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY = Y.PLAN_QTY
	;

/*******************************************************************************************************************************************************
  [4] Summary
    - 특정 Measure를 합산하는 영역
*******************************************************************************************************************************************************/


	/*************************************************************************************************************
	  [단위 합계] 1. 제품 별 본사 선적 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '01' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '08'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [단위 합계] 2. 제품 별 법인 입고 합계
	*************************************************************************************************************/	
	MERGE 
     INTO #TB_PLAN X
    USING ( SELECT A.ITEM_CD, A.YYYYMM, A.PLAN_DT, SUM(A.PLAN_QTY) AS PLAN_QTY
			  FROM #TB_PLAN A
			 WHERE 1 = 1     
			   AND A.MEASURE_CD = '02' 
			 GROUP BY A.ITEM_CD, A.YYYYMM, A.PLAN_DT	         
          ) Y
       ON X.ITEM_CD    = Y.ITEM_CD
	  AND X.YYYYMM     = Y.YYYYMM
	  AND X.PLAN_DT    = Y.PLAN_DT
	  AND X.MEASURE_CD = '09'
     WHEN MATCHED 
     THEN UPDATE
             SET X.PLAN_QTY  = Y.PLAN_QTY
	;

	/*************************************************************************************************************
	  [SUMMARY] 주 / 년 단위 합산
	*************************************************************************************************************/	
	INSERT 
	  INTO #TB_PLAN
	     ( BRND_CD,     BRND_NM,       GRADE_CD,     GRADE_NM
		 , ITEM_CD,     ITEM_NM,       CORP_CD,      CORP_NM
		 , PLNT_CD,     PLNT_NM,       MEASURE_CD,   MEASURE_NM
		 , YYYY,        YYYYMM,        DT_TYPE,      REP_DT
		 , REP_DT_DESC, PLAN_DT,       PLAN_QTY,     DAT
		 )
	/*************************************************************************************
	  [주 단위 합산] 
	  01. 본사 선적
	  02. 법인 입고
	*************************************************************************************/
	SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
		 , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    		 
		 , A.YYYY,        A.YYYYMM
		 , 'S'                                               AS DT_TYPE
		 , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 , N'Sum'                                            AS REP_DT_DESC		 
		 , '999999'                                          AS PLAN_DT
		 , SUM(ISNULL(A.PLAN_QTY,0))                         AS PLAN_QTY
		 , MAX(A.DAT)                                        AS DAT
	  FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND A.DT_TYPE    = 'W'
	   AND A.MEASURE_CD IN ('01', '02', '08', '09')
	 GROUP BY A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
			, A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
			, A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM  
		    , A.YYYY,        A.YYYYMM
    ------------------------------------------------------------------------	 
	 UNION ALL	
	------------------------------------------------------------------------
	/***********************************************************************
	  [주 단위 합산] 
	  08. 제품 별 본사 선적 합계
	  09. 제품 별 법인 입고 합계
	***********************************************************************/
	--SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	 , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
	--	 , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    
	--	 , A.YYYY,        A.YYYYMM,        A.DT_TYPE,      A.REP_DT
	--	 , A.REP_DT_DESC, A.PLAN_DT,       A.PLAN_QTY
	--	 , MAX(A.DAT) AS DAT
	--  FROM ( SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	          , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
	--	          , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    
	--	          , A.YYYY,        A.YYYYMM,        A.DAT
	--			  , 'S'                                               AS DT_TYPE
	--		      , CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
	--		      , N'Sum'                                            AS REP_DT_DESC		
	--		      , '999999'                                          AS PLAN_DT
	--			  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.MEASURE_CD, A.YYYYMM
	--			                                     ORDER BY A.YYYYMM,  A.PLAN_DT
	--												  ROWS BETWEEN UNBOUNDED PRECEDING 
	--												           AND UNBOUNDED FOLLOWING
	--											)   AS PLAN_QTY			   
	--	       FROM #TB_PLAN A
	--	      WHERE 1 = 1
	--	        AND A.DT_TYPE     = 'W'
	--	        AND A.MEASURE_CD IN ('08', '09')
	--       ) A
	-- GROUP BY A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	    , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,	  A.CORP_NM
	--	    , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    
	--	    , A.YYYY,        A.YYYYMM,        A.DT_TYPE,      A.REP_DT
	--	    , A.REP_DT_DESC, A.PLAN_DT,       A.PLAN_QTY
	------------------------------------------------------------------------	 
	 --UNION ALL	
	------------------------------------------------------------------------
	/***************************************************************************************
	  [년 단위 합산] 
	  01. 본사 선적
	  02. 법인 입고
	  08. 제품 별 본사 선적 합계
	  09. 제품 별 법인 입고 합계
	***************************************************************************************/
	SELECT A.BRND_CD,     A.BRND_NM,      A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,      A.CORP_CD,	  A.CORP_NM
		 , A.PLNT_CD,     A.PLNT_NM,      A.MEASURE_CD,   A.MEASURE_NM   
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
	  AND A.MEASURE_CD IN ('01', '02', '08', '09')
	 GROUP BY A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
		    , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,	  A.CORP_NM
		    , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM
		   
	--------------------------------------------------------------------------	 
	-- UNION ALL	
	--------------------------------------------------------------------------
	--/***********************************************************************
	--  [년 단위 합산] 
	--  003. 재고 차감
	--  007. 차이 누계
	--  010. 차이
	--***********************************************************************/
	--SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	 , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
	--	 , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    
	--	 , A.YYYY,        A.YYYYMM,        A.DT_TYPE,      A.REP_DT
	--	 , A.REP_DT_DESC, A.PLAN_DT,       A.PLAN_QTY
	--	 , MAX(A.DAT) AS DATT
	--  FROM ( SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	          , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,      A.CORP_NM
	--	          , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM    
	--	          , A.YYYY,        A.YYYYMM,        A.DAT
	--	          , '999999'                      AS YYYY
	--			  , '999999'                      AS YYYYMM     
	--		      , 'T'                           AS DT_TYPE
	--		      , N'Total'                      AS REP_DT
	--		      , N'Total'                      AS REP_DT_DESC			      
	--		      , '999999'                      AS PLAN_DT
	--			  , LAST_VALUE(A.PLAN_QTY) OVER (PARTITION BY A.PLNT_CD, A.ITEM_CD, A.SALES_ZONE, A.MEASURE_CD--, A.YYYY
	--			                                     ORDER BY A.YYYYMM,  A.PLAN_DT
	--												  ROWS BETWEEN UNBOUNDED PRECEDING 
	--												           AND UNBOUNDED FOLLOWING
	--											) AS PLAN_QTY		
	--	       FROM #TB_PLAN A
	--	      WHERE 1 = 1
	--	        AND A.MEASURE_CD IN ('08', '007', '010')
	--       ) A
	-- GROUP BY A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
	--	    , A.ITEM_CD,     A.ITEM_NM,       A.CORP_CD,	  A.CORP_NM
	--	    , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM

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
	SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
	  INTO #TB_COL_TOTAL_ZERO
	  FROM ( -- Measure의 총량이 0 인 대상 수집	        
	         SELECT A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
	              , SUM(ABS(A.PLAN_QTY)) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD) AS PLNT_PLAN_QTY -- 단위 Measure 기준
				  , SUM(ABS(A.PLAN_QTY)) OVER (PARTITION BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD)            AS ITEM_PLAN_QTY -- 합계 Measure 기준
	           FROM #TB_PLAN A
	          WHERE A.REP_DT = 'Total'					   
		   ) A
	 WHERE 1 = 1
	   AND 0 = CASE WHEN LEFT(A.PLNT_CD, 1) = 'Z'  -- 합계 Measure
	                THEN A.ITEM_PLAN_QTY           -- 품목 단위 합계
					ELSE A.PLNT_PLAN_QTY           -- 플랜트 단위 합계
				END
	 GROUP BY A.BRND_CD, A.GRADE_CD, A.ITEM_CD, A.PLNT_CD
	
	/*************************************************************************************************************
	  [화면 조회]
	*************************************************************************************************************/

	SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,	   A.CORP_CD,	   A.CORP_NM
		 , A.PLNT_CD,     A.PLNT_NM
		 , A.MEASURE_CD,  A.MEASURE_NM,    A.DT_TYPE,      A.REP_DT
		 , A.REP_DT_DESC, A.YYYY,		   A.YYYYMM,       A.PLAN_DT
		 , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
      FROM #TB_PLAN A
	 WHERE 1 = 1
	   AND NOT EXISTS (SELECT 1
                         FROM #TB_COL_TOTAL_ZERO Z
                        WHERE Z.BRND_CD    = A.BRND_CD
             		      AND Z.GRADE_CD   = A.GRADE_CD
             		      AND Z.ITEM_CD    = A.ITEM_CD
             		      AND Z.PLNT_CD    = A.PLNT_CD
             		  )
	   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
	   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	   AND ((@V_PLNT_CD = '') OR (A.PLNT_CD	   =     @V_PLNT_CD))
	 ORDER BY A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD, A.ITEM_NM,    A.PLNT_CD,	 A.PLNT_NM
			, A.MEASURE_CD, A.MEASURE_NM, A.YYYY
			, A.YYYYMM,  A.PLAN_DT


END
GO
