USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_RAW_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_RAW_Q1] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_RSRC_CD				NVARCHAR(30)	= N'ALL'  /*생산 라인*/
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_RAW_Q1
-- COPYRIGHT       : ZIONEX
-- REMARK          : CHDM 생산계획
--                   1) CHDM 생산계획 로직 기반 자동으로 산출된 생산계획 조회/수정/확정 및 유관부서에 배포
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-15  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_RAW_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_FP2010_RAW_Q1 'FP-20240823-CH-03','ALL','I23670','UI_FP2010'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''
	  , @P_FROM_DT	  NVARCHAR(8)
	  , @P_TO_DT	  NVARCHAR(8)
	  , @BOH_DTE	  NVARCHAR(8)

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')

                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------
BEGIN

    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    BEGIN
        IF OBJECT_ID('TM_FP2010') IS NOT NULL DROP TABLE TM_FP2010 -- 임시테이블 삭제

        CREATE TABLE TM_FP2010
        (
          VER_ID          NVARCHAR(100)
        , RSRC_CD		  NVARCHAR(10)
		, RSRC_NM		  NVARCHAR(100)
        , MAX_CAPA_QTY    DECIMAL(18,1)
        , BOH_QTY		  DECIMAL(18,1)
        , PLAN_DTE		  CHAR(8)
        , OPER_RATE       DECIMAL(18,1)
        , FP_PLAN_QTY     DECIMAL(18,1)
        , SUM_PLAN_QTY    DECIMAL(18,1)
        , CHDM_REQ_QTY    DECIMAL(18,1)
        , MAX_STK_LVL     DECIMAL(18,0)
        , MIN_STK_LVL     DECIMAL(18,0)
		, PRED_BOH_QTY	  DECIMAL(18,1)
		, CNSM_REQ_QTY    DECIMAL(18,1)  -- 자사 투입량 추가
		, MEASURE_CD	  NVARCHAR(10)
		, MEASURE_NM	  NVARCHAR(100)
		, COL_CD		  CHAR(10)
        );
	END;

	SET @P_FROM_DT = (SELECT CONVERT(NVARCHAR(8), FROM_DT, 112) FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION)
	SET @P_TO_DT = (SELECT CONVERT(NVARCHAR(8), TO_DT, 112) FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION)

	SELECT @P_FROM_DT = CONVERT(NVARCHAR(8), FROM_DT, 112) 
		 , @BOH_DTE = CONVERT(NVARCHAR(8), DATEADD(DAY, -1, FROM_DT), 112)
	  FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION
	;

    -----------------------------------
    -- #TM_RSRC
    -----------------------------------
        --IF OBJECT_ID('tempdb..#TM_RSRC') IS NOT NULL DROP TABLE #TM_RSRC -- 임시테이블 삭제

        --SELECT Value VAL
        --  INTO #TM_RSRC
        --  FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_RSRC_CD),''),'|')

    -----------------------------------
    -- 조회 
    -----------------------------------

	IF OBJECT_ID('tempdb..#TM_MES') IS NOT NULL DROP TABLE #TM_MES -- 임시테이블 삭제
		SELECT A.RSRC_CD
			 , A.SCM_RSRC_NM AS RSRC_NM
			 , MEASURE_CD
			 , MEASURE_NM
			 , CASE WHEN MEASURE_CD = '03'   THEN '#a59ed9'
					WHEN MEASURE_CD = '04'   THEN '#2f57d2'
					WHEN MEASURE_CD = '04_2' THEN '#23bd19'
					WHEN MEASURE_CD = '05'   THEN '#b5e14d'
					WHEN MEASURE_CD = '06'   THEN '#44546a'
					WHEN MEASURE_CD = '07'   THEN '#ffc000' END AS COL_CD
		  INTO #TM_MES
		  FROM TB_SKC_FP_RSRC_MST A
		 CROSS JOIN (SELECT COMN_CD AS MEASURE_CD
						  , COMN_CD_NM AS MEASURE_NM
					FROM FN_COMN_CODE('FP2010', '')) B
		 WHERE A.ATTR_01 = '12'	
		   AND A.SCM_CAPA_USE_YN = 'Y'
		   AND A.SCM_USE_YN = 'Y'
		   AND (A.RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL');
		   --AND (RSRC_CD IN (SELECT VAL FROM #TM_RSRC) OR ISNULL(@P_RSRC_CD , 'ALL') = 'ALL');

	IF OBJECT_ID('tempdb..#TM_FP_QTY') IS NOT NULL DROP TABLE #TM_FP_QTY -- 임시테이블 삭제
   --     SELECT VER_ID
			-- , A.RSRC_CD
			-- , MAX(A.MAX_CAPA_QTY)/1000  AS MAX_CAPA_QTY
			-- , PLAN_DTE
			-- , ITEM_CD
			-- , SUM(ADJ_OPER_RATE)*100 AS OPER_RATE			 
			-- , SUM(ADJ_PLAN_QTY)/1000  AS FP_PLAN_QTY		
			-- , SUM(PRDT_REQ_QTY)/1000 AS PRDT_REQ_QTY		 
		 -- INTO #TM_FP_QTY
		 -- FROM TB_SKC_FP_RS_PRDT_PLAN_CH A
		 --INNER JOIN TB_SKC_FP_RSRC_MST B 
		 --   ON A.RSRC_CD = B.RSRC_CD
		 --WHERE (A.RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL')
		 --  AND VER_ID = @P_FP_VERSION
		 --GROUP BY VER_ID, A.RSRC_CD, PLAN_DTE, ITEM_CD;

        SELECT @P_FP_VERSION AS VER_ID
			 , A.RSRC_CD
			 , IIF(MAX(A.MAX_CAPA_QTY) IS NULL, 0, MAX(A.MAX_CAPA_QTY)) AS MAX_CAPA_QTY
			 , A.PLAN_DTE
			 , B.ITEM_CD
			 , IIF(SUM(B.ADJ_OPER_RATE) IS NULL, 0, SUM(B.ADJ_OPER_RATE)*100) AS OPER_RATE			 
			 , IIF(SUM(B.ADJ_PLAN_QTY) IS NULL, 0, SUM(B.ADJ_PLAN_QTY)/1000)  AS FP_PLAN_QTY		
			 , IIF(SUM(B.PRDT_REQ_QTY) IS NULL, 0, SUM(B.PRDT_REQ_QTY)/1000) AS PRDT_REQ_QTY
			 , IIF(MAX(C.DMND_QTY) IS NULL, 0, MAX(C.DMND_QTY)/1000) AS DMND_QTY
		  INTO #TM_FP_QTY
		  FROM
		  (
		    SELECT DISTINCT RSRC_CD, A.MAX_CAPA_QTY, B.PLAN_DTE
			FROM 
			(
				SELECT DISTINCT RSRC_CD, MAX(MAX_CAPA_QTY)/1000 AS MAX_CAPA_QTY FROM TB_SKC_FP_RS_PRDT_PLAN_CH
				WHERE VER_ID = @P_FP_VERSION
				GROUP BY VER_ID, RSRC_CD, PLAN_DTE, ITEM_CD
			) A
			CROSS JOIN 
			(
				SELECT DAT_ID AS PLAN_DTE FROM TB_CM_CALENDAR
				WHERE DAT_ID>= @P_FROM_DT
				AND DAT_ID <=  @P_TO_DT	
			) B
		  ) A
		  LEFT JOIN 
		  (
			SELECT A.* 
			FROM TB_SKC_FP_RS_PRDT_PLAN_CH A
			INNER JOIN TB_SKC_FP_RSRC_MST B 
			ON A.RSRC_CD = B.RSRC_CD
			WHERE  VER_ID =  @P_FP_VERSION
			AND (A.RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL')
		  ) B
		  ON A.PLAN_DTE = B.PLAN_DTE
		  AND A.RSRC_CD = B.RSRC_CD
		  LEFT JOIN 
		  (  SELECT  PRDT_REQ_DTE
                  ,  SUM(PRDT_REQ_QTY) AS DMND_QTY FROM TB_SKC_FP_RS_PRDT_REQ_CH
              WHERE  VER_ID    = @P_FP_VERSION
			    AND  DMND_TYPE = 'MP'
              GROUP  BY PRDT_REQ_DTE
           )  C
		  ON  A.PLAN_DTE = C.PRDT_REQ_DTE
		 GROUP BY A.RSRC_CD, A.PLAN_DTE, B.ITEM_CD


	
	-- 생산량 합계
	IF OBJECT_ID('tempdb..#TM_FP_SUM') IS NOT NULL DROP TABLE #TM_FP_SUM -- 임시테이블 삭제
		SELECT PLAN_DTE
			 , RSRC_CD
			 , SUM(FP_PLAN_QTY) AS SUM_PLAN_QTY
		  INTO #TM_FP_SUM
		  FROM #TM_FP_QTY
		 WHERE (RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL')
		 GROUP BY PLAN_DTE, RSRC_CD;
	
	-- CHDM 필요량
	IF OBJECT_ID('tempdb..#TM_REQ_QTY') IS NOT NULL DROP TABLE #TM_REQ_QTY -- 임시테이블 삭제
		SELECT PLAN_DTE
			 , RSRC_CD
			 , SUM(PRDT_REQ_QTY) AS CHDM_REQ_QTY
			 , MAX(DMND_QTY)     AS DMND_QTY
		  INTO #TM_REQ_QTY
		  FROM #TM_FP_QTY
		 GROUP BY PLAN_DTE, RSRC_CD;

	-- 기초재고
	IF OBJECT_ID('tempdb..#TM_BOH') IS NOT NULL DROP TABLE #TM_BOH -- 임시테이블 삭제
		
		SELECT  B.RSRC_CD    	AS RSRC_CD
			 ,  A.STCK_QTY/1000 AS BOH_QTY
		  INTO  #TM_BOH
		  FROM  TB_SKC_CM_MES_LINE_STCK_HST A
         INNER  JOIN TB_SKC_FP_RSRC_MST B
		    ON  ISNULL(B.SCM_CAPA_USE_YN,'N') = 'Y'
           AND  ISNULL(B.SCM_USE_YN,'N')      = 'Y'
		   AND  A.RSRC_NM  = B.SCM_RSRC_NM 
		 WHERE  CLOSE_DT = (SELECT DATEADD(DAY, -1, FROM_DT) FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION)
		   AND  (A.RSRC_NM = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL')
		   AND  ITEM_CD = '100001';


	IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제
		SELECT VER_ID
			 , A.RSRC_CD
			 , A.MAX_CAPA_QTY
			 , COALESCE(E.BOH_QTY, 0) AS BOH_QTY
			 , A.PLAN_DTE
			 , A.OPER_RATE
			 , A.FP_PLAN_QTY		 
		  INTO #TM_QTY
		  FROM #TM_FP_QTY A
		 INNER JOIN #TM_FP_SUM B	    
			ON A.PLAN_DTE = B.PLAN_DTE
		 INNER JOIN #TM_REQ_QTY C
		    ON A.PLAN_DTE = C.PLAN_DTE
		  LEFT JOIN #TM_BOH E
		    ON A.RSRC_CD = E.RSRC_CD
		 ;

	IF OBJECT_ID('tempdb..#TM_SUM_QTY') IS NOT NULL DROP TABLE #TM_SUM_QTY -- 임시테이블 삭제
		SELECT A.PLAN_DTE
			 , A.SUM_PLAN_QTY
			 , B.CHDM_REQ_QTY
			 , B.DMND_QTY
			 , C.MAX_STK_LVL
			 , C.MIN_STK_LVL
			 , (SELECT ISNULL(SUM(BOH_QTY), 0) FROM #TM_BOH) AS BOH_QTY
		  INTO #TM_SUM_QTY
		  FROM (SELECT PLAN_DTE, SUM(SUM_PLAN_QTY) AS SUM_PLAN_QTY 
		          FROM #TM_FP_SUM 
				 GROUP BY PLAN_DTE) A
		 INNER JOIN (SELECT PLAN_DTE, SUM(CHDM_REQ_QTY) AS CHDM_REQ_QTY     
		                  , MAX(DMND_QTY) AS DMND_QTY
					   FROM #TM_REQ_QTY 
					  GROUP BY PLAN_DTE) B
		    ON A.PLAN_DTE = B.PLAN_DTE
		 INNER JOIN (SELECT CALD_DATE_ID AS PLAN_DTE
						  , SUM(MAX_STK_LVL) AS MAX_STK_LVL
						  , SUM(MIN_STK_LVL) AS MIN_STK_LVL
					   FROM TB_SKC_FP_SFG_STK_LVL A
					  WHERE 1=1 
					    AND EXISTS ( SELECT 1 FROM TB_SKC_FP_RSRC_MST X WHERE A.CORP_CD = X.CORP_CD AND A.PLNT_CD = X.PLNT_CD AND A.RSRC_CD = X.RSRC_CD AND X.ATTR_01 = '12')
					    --AND VER_ID = @P_FP_VERSION
						AND (RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD, 'ALL') = 'ALL')
					  GROUP BY CALD_DATE_ID) C
			ON A.PLAN_DTE = C.PLAN_DTE

	-- 예상 기말재고
	IF OBJECT_ID('tempdb..#TM_PRED_BOH') IS NOT NULL DROP TABLE #TM_PRED_BOH -- 임시테이블 삭제
		SELECT PLAN_DTE
			 , BOH_QTY + SUM_PLAN_QTY - CHDM_REQ_QTY AS PRED_BOH_QTY
		  INTO #TM_PRED_BOH
		  FROM (SELECT PLAN_DTE
				 	 , BOH_QTY
					 , SUM(SUM_PLAN_QTY) OVER (ORDER BY PLAN_DTE) AS SUM_PLAN_QTY
					 , SUM(CHDM_REQ_QTY) OVER (ORDER BY PLAN_DTE) AS CHDM_REQ_QTY
				  FROM #TM_SUM_QTY) A
	--IF OBJECT_ID('tempdb..#TM_PRED_BOH') IS NOT NULL DROP TABLE #TM_PRED_BOH -- 임시테이블 삭제
	--	SELECT MAX(PLAN_DTE) AS PLAN_DTE
	--		 , MAX(BOH_QTY) + MAX(SUM_PLAN_QTY) - MAX(CHDM_REQ_QTY) - MAX(CNSM_REQ_QTY) AS PRED_BOH_QTY
	--	  INTO #TM_PRED_BOH
	--	  FROM (SELECT PLAN_DTE
	--			 	 , BOH_QTY
	--				 , SUM(SUM_PLAN_QTY) OVER (ORDER BY PLAN_DTE) AS SUM_PLAN_QTY
	--				 , SUM(CHDM_REQ_QTY) OVER (ORDER BY PLAN_DTE) AS CHDM_REQ_QTY
	--				 , 0										  AS CNSM_REQ_QTY
	--			  FROM #TM_SUM_QTY
	--			  UNION ALL 
	--			SELECT PRDT_REQ_DTE AS PLAN_DTE
	--			 	 , 0 AS BOH_QTY
	--				 , 0 AS SUM_PLAN_QTY
	--				 , 0 AS CHDM_REQ_QTY
	--				 --, SUM(CNSM_REQ_QTY) OVER (ORDER BY PRDT_REQ_DTE)/1000 AS CNSM_REQ_QTY
	--				 , IIF(SUM(CNSM_REQ_QTY) IS NULL, 0, SUM(CNSM_REQ_QTY)/1000)  AS CNSM_REQ_QTY
	--			FROM TB_SKC_FP_RS_LINE_REQ_CH 
	--			WHERE VER_ID =  @P_FP_VERSION
	--			AND PRDT_REQ_DTE >= (SELECT MIN(PLAN_DTE) FROM #TM_SUM_QTY)
	--			AND PRDT_REQ_DTE <= (SELECT MAX(PLAN_DTE) FROM #TM_SUM_QTY)
	--			GROUP BY PRDT_REQ_DTE  
	--			  ) A
	--	GROUP BY PLAN_DTE

		INSERT TM_FP2010
		SELECT DISTINCT A1.VER_ID
			 , A1.RSRC_CD
			 , A4.RSRC_NM
			 , A1.MAX_CAPA_QTY
			 , A1.BOH_QTY
			 , A1.PLAN_DTE
			 , A1.OPER_RATE
			 , A1.FP_PLAN_QTY
			 , A2.SUM_PLAN_QTY
			 , A2.DMND_QTY AS CHDM_REQ_QTY
			 , A2.MAX_STK_LVL
			 , A2.MIN_STK_LVL
			 , A3.PRED_BOH_QTY
			 , NULL AS CNSM_REQ_QTY
			 , A4.MEASURE_CD
			 , A4.MEASURE_NM
			 , A4.COL_CD
		  FROM #TM_QTY A1
		 INNER JOIN #TM_SUM_QTY A2
			ON A1.PLAN_DTE = A2.PLAN_DTE
		 INNER JOIN #TM_PRED_BOH A3
			ON A1.PLAN_DTE = A3.PLAN_DTE
		 INNER JOIN #TM_MES A4
		    ON A1.RSRC_CD = A4.RSRC_CD
		 WHERE MEASURE_CD != '04_2'

		UNION ALL

		SELECT 
			 @P_FP_VERSION AS VER_ID
			, A.RSRC_CD		 
			, A.RSRC_NM		 
			, NULL AS MAX_CAPA_QTY   
			, NULL AS BOH_QTY		 
			, A.PLAN_DTE AS PLAN_DTE		 
			, NULL AS OPER_RATE      
			, NULL AS FP_PLAN_QTY    
			, NULL AS SUM_PLAN_QTY   
			, NULL AS CHDM_REQ_QTY   
			, NULL AS MAX_STK_LVL    
			, NULL AS MIN_STK_LVL    
			, NULL AS PRED_BOH_QTY	 
			, ISNULL(B.CNSM_REQ_QTY/1000,0)	AS CNSM_REQ_QTY
			, '04_2' AS MEASURE_CD	 
			, 'CHDM 필요량(자사 투입)' AS MEASURE_NM	 
			, '#23bd19' AS COL_CD		 
		FROM 
		(
			 SELECT * FROM
			( SELECT RSRC_CD, RSRC_NM FROM TB_SKC_FP_RSRC_MST
				WHERE PLNT_CD IN ('1110', '1230')
				AND RSRC_CD != 'SSP20'
				AND SCM_USE_YN    = 'Y'
				AND ATTR_01  = '11'
			) A
			 CROSS JOIN 
			 (
				SELECT DAT_ID AS PLAN_DTE FROM TB_CM_CALENDAR
				WHERE DAT_ID>= @P_FROM_DT
				AND DAT_ID <=  @P_TO_DT
			 ) B
		) A
		LEFT JOIN
		(
			SELECT * 
			FROM TB_SKC_FP_RS_LINE_REQ_CH
			WHERE VER_ID = @P_FP_VERSION
		) B
		ON A.RSRC_CD = B.RSRC_CD
		AND A.PLAN_DTE = B.PRDT_REQ_DTE

		--SELECT 
		--	  A.VER_ID         
		--	, A.RSRC_CD		 
		--	, B.RSRC_NM		 
		--	, NULL AS MAX_CAPA_QTY   
		--	, NULL AS BOH_QTY		 
		--	, A.PRDT_REQ_DTE AS PLAN_DTE		 
		--	, NULL AS OPER_RATE      
		--	, NULL AS FP_PLAN_QTY    
		--	, NULL AS SUM_PLAN_QTY   
		--	, NULL AS CHDM_REQ_QTY   
		--	, NULL AS MAX_STK_LVL    
		--	, NULL AS MIN_STK_LVL    
		--	, NULL AS PRED_BOH_QTY	 
		--	, A.CNSM_REQ_QTY/1000		AS CNSM_REQ_QTY
		--	, '04_2' AS MEASURE_CD	 
		--	, 'CHDM 필요량(자사 투입)' AS MEASURE_NM	 
		--	, '#23bd19' AS COL_CD		 
		--FROM TB_SKC_FP_RS_LINE_REQ_CH A
		--INNER JOIN TB_SKC_FP_RSRC_MST B
		--ON A.RSRC_CD = B.RSRC_CD
		--WHERE A.VER_ID = @P_FP_VERSION

		UNION ALL

		--SELECT 
		--	  A.VER_ID         
		--	, '합계' AS RSRC_CD		 
		--	, '합계' AS RSRC_NM		 
		--	, NULL AS MAX_CAPA_QTY   
		--	, NULL AS BOH_QTY		 
		--	, A.PRDT_REQ_DTE AS PLAN_DTE		 
		--	, NULL AS OPER_RATE      
		--	, NULL AS FP_PLAN_QTY    
		--	, NULL AS SUM_PLAN_QTY   
		--	, NULL AS CHDM_REQ_QTY   
		--	, NULL AS MAX_STK_LVL    
		--	, NULL AS MIN_STK_LVL    
		--	, NULL AS PRED_BOH_QTY	 
		--	, SUM(A.CNSM_REQ_QTY/1000)		AS CNSM_REQ_QTY
		--	, '04_2' AS MEASURE_CD	 
		--	, 'CHDM 필요량(자사 투입)' AS MEASURE_NM	 
		--	, '#23bd19' AS COL_CD		 
		--FROM TB_SKC_FP_RS_LINE_REQ_CH A
		--WHERE A.VER_ID = @P_FP_VERSION
		--GROUP BY A.VER_ID, A.PRDT_REQ_DTE

		SELECT 
			 @P_FP_VERSION   AS VER_ID
			, '합계' AS RSRC_CD		 
			, '합계' AS RSRC_NM		 
			, NULL AS MAX_CAPA_QTY   
			, NULL AS BOH_QTY		 
			, A.PLAN_DTE AS PLAN_DTE		 
			, NULL AS OPER_RATE      
			, NULL AS FP_PLAN_QTY    
			, NULL AS SUM_PLAN_QTY   
			, NULL AS CHDM_REQ_QTY   
			, NULL AS MAX_STK_LVL    
			, NULL AS MIN_STK_LVL    
			, NULL AS PRED_BOH_QTY	 
			, IIF(SUM(B.CNSM_REQ_QTY) IS NULL, 0, SUM(B.CNSM_REQ_QTY/1000))		AS CNSM_REQ_QTY
			, '04_2' AS MEASURE_CD	 
			, 'CHDM 필요량(자사 투입)' AS MEASURE_NM	 
			, '#23bd19' AS COL_CD		 
		FROM 
		(
			SELECT DAT_ID AS PLAN_DTE FROM TB_CM_CALENDAR
			WHERE DAT_ID>= @P_FROM_DT
			AND DAT_ID <=  @P_TO_DT		
		) A
		LEFT JOIN 
		(
			SELECT * FROM TB_SKC_FP_RS_LINE_REQ_CH B
			WHERE VER_ID =  @P_FP_VERSION
		) B
		ON A.PLAN_DTE = B.PRDT_REQ_DTE
		GROUP BY A.PLAN_DTE

END;
GO
