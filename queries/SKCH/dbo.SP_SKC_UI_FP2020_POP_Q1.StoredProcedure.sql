USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_POP_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_POP_Q1] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_POP_Q1
-- COPYRIGHT       : ZIONEX
-- REMARK          : DMT 생산계획
--                   1) DMT 생산계획 재수립 정보 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2020_POP_Q1'FP-20240722-DM-01','SCM System','UI_FP2020'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')

                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------
BEGIN
   
    -----------------------------------
    -- 조회 
    -----------------------------------

	IF EXISTS (SELECT 1 FROM TB_SKC_FP_RE_ESTB WHERE PLAN_SCOPE = 'FP-DMT' AND VERSION_CD = @P_FP_VERSION)
		BEGIN
			SELECT VERSION_CD AS FP_VERSION
				 , (SELECT ATTR_10 FROM TB_CM_ITEM_MST WHERE ITEM_CD = '104600') AS RSRC_CD
				 , (SELECT ATTR_11 FROM TB_CM_ITEM_MST WHERE ITEM_CD = '104600') AS RSRC_NM
				 , 'N' AS RE_ESTB_YN
				 --, RE_ESTB_YN
				 , CAST(PLAN_DTE AS DATE) AS RE_ESTB_DTE
				 , CAST(MAX_DTE AS DATE) AS MAX_DTE
				 , V.FROM_DT
			  FROM TB_SKC_FP_RE_ESTB A
			  LEFT JOIN (SELECT VER_ID, MAX(PLAN_DTE) AS MAX_DTE
						   FROM TB_SKC_FP_RS_PRDT_PLAN_DM
						  WHERE MODIFY_BY IS NOT NULL
						    AND VER_ID = @P_FP_VERSION
						  GROUP BY VER_ID) C
						    --) C
				ON A.VERSION_CD = C.VER_ID
			 LEFT JOIN											-- FROM_DT 추가
			  (
				SELECT DISTINCT VERSION, MAX(FROM_DT) AS FROM_DT
				FROM  VW_FP_PLAN_VERSION
				GROUP BY VERSION
			  ) V
			  ON A.VERSION_CD = V.VERSION
			 WHERE PLAN_SCOPE = 'FP-DMT'
			   AND VERSION_CD = @P_FP_VERSION;
		END;
	IF NOT EXISTS (SELECT 1 FROM TB_SKC_FP_RE_ESTB WHERE PLAN_SCOPE = 'FP-DMT' AND VERSION_CD = @P_FP_VERSION)
		BEGIN
			SELECT  A.VERSION AS FP_VERSION
				 ,  (SELECT ATTR_10 FROM TB_CM_ITEM_MST WHERE ITEM_CD = '104600') AS RSRC_CD
				 ,  (SELECT ATTR_11 FROM TB_CM_ITEM_MST WHERE ITEM_CD = '104600') AS RSRC_NM
				 ,  'N' AS RE_ESTB_YN
				 ,  CAST(A.PLAN_DT AS DATE) AS RE_ESTB_DTE
				 ,  CAST(C.MAX_DTE AS DATE) AS MAX_DTE
				 ,  V.FROM_DT
			  FROM  VW_FP_PLAN_VERSION A
			  LEFT JOIN (SELECT VER_ID, MAX(PLAN_DTE) AS MAX_DTE
						   FROM TB_SKC_FP_RS_PRDT_PLAN_DM
						  WHERE MODIFY_BY IS NOT NULL
						    AND VER_ID = @P_FP_VERSION
						  GROUP BY VER_ID) C
						    --) C
				ON  A.VERSION = C.VER_ID
			  LEFT JOIN											-- FROM_DT 추가
			  (
				SELECT DISTINCT VERSION, MAX(FROM_DT) AS FROM_DT
				FROM  VW_FP_PLAN_VERSION
				GROUP BY VERSION
			  ) V
			 ON A.VERSION = V.VERSION
			 WHERE  PLAN_SCOPE = 'FP-DMT'
			   AND  A.VERSION = @P_FP_VERSION
		END;

END;
GO
