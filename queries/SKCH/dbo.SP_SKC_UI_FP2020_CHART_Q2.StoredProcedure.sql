USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_CHART_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_CHART_Q2] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_CHART_Q2
-- COPYRIGHT       : ZIONEX
-- REMARK          : DMT 생산계획
--                   1) Flake/Briquet, Molten 에 대한 일 단위 생산계획을 수립 유관부서에 배포
--					 2) 하단GRID
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-19  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_CHART_Q1' ORDER BY LOG_DTTM DESC
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''
	  , @P_FROM_DT	  NVARCHAR(8)
	  , @BOH_DTE	  NVARCHAR(8)

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')

                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------
BEGIN

	EXEC SP_SKC_UI_FP2020_RAW_Q2 @P_FP_VERSION, @P_USER_ID, @P_VIEW_ID;

    -----------------------------------
    -- 조회 
    -----------------------------------
	
	SELECT A.PLAN_DTE
		 , PARTWK
		 , SUM_PLAN_QTY
		 , DMT_REQ_QTY
		 , SP_REQ_QTY
		 , 0 AS SD_REQ_QTY
		 , PRED_BOH_QTY
		 , MAX_STK_LVL
		 , MIN_STK_LVL		 
	  FROM (SELECT DISTINCT MAX(PLAN_DTE) AS PLAN_DTE
				 , PARTWK
				 , SUM(PLAN_QTY)/1000 AS SUM_PLAN_QTY
				 , SUM(DMT_REQ_QTY)/1000 AS DMT_REQ_QTY
				 , SUM(SP_REQ_QTY/1000) AS SP_REQ_QTY
				 , SUM(SD_REQ_QTY)/1000 AS SD_REQ_QTY
				 , MAX(MAX_STK_LVL)/1000 AS MAX_STK_LVL
				 , MIN(MIN_STK_LVL)/1000 AS MIN_STK_LVL
			  FROM (SELECT DISTINCT DAT_ID AS PLAN_DTE
						 , PLAN_QTY
						 , DMND_REQ_QTY AS DMT_REQ_QTY
						 , SP_REQ_QTY
						 , SD_REQ_QTY
						 , MAX_STK_LVL
						 , MIN_STK_LVL 
					  FROM TM_FP2020) A 
			INNER JOIN TB_CM_CALENDAR B
			   ON A.PLAN_DTE = B.DAT
			GROUP BY PARTWK) A
	  INNER JOIN (SELECT DISTINCT DAT_ID AS PLAN_DTE, EOH_QTY/1000 AS PRED_BOH_QTY FROM TM_FP2020) B
		 ON A.PLAN_DTE = B.PLAN_DTE
	  ORDER BY 1
		


END;
GO
