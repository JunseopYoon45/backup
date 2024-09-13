USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_CHART_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_CHART_Q1] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_RSRC_CD				NVARCHAR(30)	= N'ALL'  /*생산 라인*/
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_CHART_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_CHART_Q1' ORDER BY LOG_DTTM DESC
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

    -----------------------------------
    -- 조회 
    -----------------------------------

	EXEC SP_SKC_UI_FP2010_RAW_Q1 @P_FP_VERSION, @P_RSRC_CD, @P_USER_ID, @P_VIEW_ID;
	
SELECT A.PLAN_DTE
		 , PARTWK
		 , SUM_PLAN_QTY
		 , CHDM_REQ_QTY
		 , CNSM_REQ_QTY AS CHDM_INPUT_QTY
		 , PRED_BOH_QTY
		 , MAX_STK_LVL
		 , MIN_STK_LVL		 
	  FROM (SELECT DISTINCT MAX(PLAN_DTE) AS PLAN_DTE
				 , PARTWK
				 , SUM(SUM_PLAN_QTY) AS SUM_PLAN_QTY
				 , SUM(CHDM_REQ_QTY) AS CHDM_REQ_QTY
				 , MAX(MAX_STK_LVL) AS MAX_STK_LVL
				 , MIN(MIN_STK_LVL) AS MIN_STK_LVL
				 , MAX(CNSM_REQ_QTY) AS CNSM_REQ_QTY
			  FROM (SELECT DISTINCT PLAN_DTE
						 , SUM_PLAN_QTY
						 , CHDM_REQ_QTY
						 , MAX_STK_LVL
						 , MIN_STK_LVL 
						 , CNSM_REQ_QTY
					  FROM TM_FP2010) A 
			INNER JOIN TB_CM_CALENDAR B
			   ON A.PLAN_DTE = B.DAT
			GROUP BY PARTWK) A
	  INNER JOIN (SELECT DISTINCT PLAN_DTE, PRED_BOH_QTY FROM TM_FP2010 WHERE PRED_BOH_QTY IS NOT NULL) B
		 ON A.PLAN_DTE = B.PLAN_DTE
	  ORDER BY 1
		


END;
GO
