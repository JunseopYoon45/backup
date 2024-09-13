USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_Q1] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_RSRC_CD				NVARCHAR(30)	= N'ALL'  /*생산 라인*/
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2010_Q1'FP-20240904-CH-01','ALL','I23670','UI_FP2010'
EXEC SP_SKC_UI_FP2010_Q1'','CDP-1','','UI_FP1110'
EXEC SP_SKC_UI_FP2010_Q1'','CDP-4','','UI_FP1110'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''
	  , @P_FROM_DT	  NVARCHAR(8)
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

	SET @P_FROM_DT = (SELECT CONVERT(NVARCHAR(8), FROM_DT, 112) FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION)

	SELECT @P_FROM_DT = CONVERT(NVARCHAR(8), FROM_DT, 112) 
		 , @BOH_DTE = CONVERT(NVARCHAR(8), DATEADD(DAY, -1, FROM_DT), 112)
	  FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_FP_VERSION
	;

    -----------------------------------
    -- 조회 
    -----------------------------------

	EXEC SP_SKC_UI_FP2010_RAW_Q1 @P_FP_VERSION, @P_RSRC_CD, @P_USER_ID, @P_VIEW_ID;
	
	IF OBJECT_ID('tempdb..#TM_MES') IS NOT NULL DROP TABLE #TM_MES -- 임시테이블 삭제
		SELECT A.RSRC_CD
			 , A.RSRC_NM
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
		   AND (RSRC_CD = @P_RSRC_CD OR ISNULL(@P_RSRC_CD , 'ALL') = 'ALL');

		

	SELECT DISTINCT VER_ID
		 --, A.RSRC_CD
		 , CASE WHEN MEASURE_CD IN ('01', '02') THEN RSRC_CD
				ELSE 'TOT'+MEASURE_CD END AS RSRC_CD						-- 3줄
		 --, B.RSRC_NM
		 , CASE WHEN MEASURE_CD IN ('01', '02') THEN RSRC_NM
				WHEN MEASURE_CD IN ('06', '07') THEN '재고 관리 Level'
				ELSE MEASURE_NM END AS RSRC_NM
		 , MAX_CAPA_QTY
		 , CASE WHEN MEASURE_CD IN ('01', '02') THEN ROUND(A.BOH_QTY, 1)
				ELSE NULL END AS BOH_QTY
		 , A.PLAN_DTE
		 , DOW_NM
		 , HOLID_YN
		 , CASE 
				WHEN MEASURE_CD = '04_2' THEN 
					CASE 
						WHEN RSRC_CD = 'CPR10' THEN  '04_3'
						WHEN RSRC_CD = 'CPR20' THEN  '04_4'
						WHEN RSRC_CD = 'CPR30' THEN  '04_5'
						WHEN RSRC_CD = 'CPR40' THEN  '04_6'
						WHEN RSRC_CD = 'SCP20' THEN	 '04_7'
						WHEN RSRC_CD = '합계'  THEN  '04_8'
					END 
				ELSE MEASURE_CD
			END AS MEASURE_CD
		 , CASE WHEN MEASURE_CD = '04_2' THEN RSRC_CD
		   ELSE MEASURE_NM END AS MEASURE_NM
		 , CASE WHEN MEASURE_CD = '01' THEN OPER_RATE
				WHEN MEASURE_CD = '02' THEN ROUND(FP_PLAN_QTY, 1)
				WHEN MEASURE_CD = '03' THEN ROUND(SUM_PLAN_QTY, 1)
				WHEN MEASURE_CD = '04' THEN ROUND(CHDM_REQ_QTY, 1)
				WHEN MEASURE_CD = '04_2' THEN ROUND(CNSM_REQ_QTY, 1)
				WHEN MEASURE_CD = '05' THEN ROUND(PRED_BOH_QTY, 1)
				WHEN MEASURE_CD = '06' THEN MAX_STK_LVL
				WHEN MEASURE_CD = '07' THEN MIN_STK_LVL END AS QTY
		 , CASE WHEN PLAN_DTE >= FORMAT(GETDATE(), 'yyyyMMdd') THEN 'Y'
				ELSE 'N' END AS ADJ_YN
		 --, CASE WHEN PLAN_DTE < FORMAT(GETDATE(), 'yyyyMMdd') THEN 'Y'
			--	ELSE 'Y' END AS ADJ_YN
		 , COL_CD
	  FROM TM_FP2010 A
	 INNER JOIN TB_CM_CALENDAR C
	    ON A.PLAN_DTE = C.DAT
	 ORDER BY 6, 2, 9 

END;
GO
