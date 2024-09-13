USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_POP_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_POP_Q1] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_POP_Q1
-- COPYRIGHT       : ZIONEX
-- REMARK          : CHDM 생산계획
--                   1) CHDM 생산계획 재수립 정보 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2010_POP_Q1 'FP-20240909-CH-02','I23693','UI_FP2010'
EXEC SP_SKC_UI_FP2010_POP_Q1'FP-20240712-CH-01','SCM System','UI_FP2010'
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
   
  --             SELECT RSRC_CD, MAX(PLAN_DTE) AS MAX_DTE
		--				   FROM TB_SKC_FP_RS_PRDT_PLAN_CH 
		--				  WHERE MODIFY_BY IS NOT NULL
		--				    AND VER_ID = 'FP-20240803-CH-10'
		--				  GROUP BY RSRC_CD

       
		--BEGIN
		--	SELECT VERSION_CD AS FP_VERSION
		--		 , A.RSRC_CD
		--		 , B.RSRC_NM
		--		 , RE_ESTB_YN
		--		 , CAST(PLAN_DTE AS DATE) AS RE_ESTB_DTE
		--		 , CAST(MAX_DTE AS DATE) AS MAX_DTE
		--	  FROM TB_SKC_FP_RE_ESTB A
		--	 INNER JOIN TB_SKC_FP_RSRC_MST B
		--		ON A.RSRC_CD = B.RSRC_CD
		--	  LEFT JOIN (SELECT RSRC_CD, MAX(PLAN_DTE) AS MAX_DTE
		--				   FROM TB_SKC_FP_RS_PRDT_PLAN_CH 
		--				  WHERE MODIFY_BY IS NOT NULL
		--				    AND VER_ID = @P_FP_VERSION
		--				  GROUP BY RSRC_CD) C
		--		ON A.RSRC_CD = C.RSRC_CD
		--	 WHERE PLAN_SCOPE = 'FP-CHDM'
		--	   AND VERSION_CD = @P_FP_VERSION;
    -----------------------------------
    -- 조회 
    -----------------------------------

	IF EXISTS (SELECT 1 FROM TB_SKC_FP_RE_ESTB WHERE PLAN_SCOPE = 'FP-CHDM' AND VERSION_CD = @P_FP_VERSION)
		BEGIN
			SELECT VERSION_CD AS FP_VERSION
				 , A.RSRC_CD
				 , B.SCM_RSRC_NM AS RSRC_NM
				 , 'N' AS RE_ESTB_YN		
				 --, RE_ESTB_YN
				 , ISNULL(CAST(PLAN_DTE AS DATE), V.FROM_DT)  AS RE_ESTB_DTE
				 --, CAST(PLAN_DTE AS DATE)  AS RE_ESTB_DTE
				 , CAST(C.MAX_DTE AS DATE) AS MAX_DTE
				 , V.FROM_DT
			  FROM TB_SKC_FP_RE_ESTB A
			 INNER JOIN TB_SKC_FP_RSRC_MST B
				ON A.RSRC_CD = B.RSRC_CD
			  LEFT JOIN (SELECT RSRC_CD, MAX(PLAN_DTE) AS MAX_DTE
						   FROM TB_SKC_FP_RS_PRDT_PLAN_CH 
						  WHERE MODIFY_BY IS NOT NULL
						    AND VER_ID = @P_FP_VERSION
						  GROUP BY RSRC_CD) C
				ON A.RSRC_CD = C.RSRC_CD
			  LEFT JOIN											-- FROM_DT 추가
			  (
				SELECT DISTINCT VERSION, MAX(FROM_DT) AS FROM_DT
				FROM  VW_FP_PLAN_VERSION
				GROUP BY VERSION
			  ) V
			  ON A.VERSION_CD = V.VERSION
			 WHERE PLAN_SCOPE = 'FP-CHDM'
			   AND VERSION_CD = @P_FP_VERSION
			   AND B.SCM_USE_YN = 'Y'
			   AND B.USE_YN = 'Y'
		END;
	IF NOT EXISTS (SELECT 1 FROM TB_SKC_FP_RE_ESTB WHERE PLAN_SCOPE = 'FP-CHDM' AND VERSION_CD = @P_FP_VERSION)
		BEGIN
			SELECT A.VERSION AS FP_VERSION
				 , B.RSRC_CD
				 , B.SCM_RSRC_NM AS RSRC_NM
				 , 'N' AS RE_ESTB_YN
				 --, CAST(A.PLAN_DT AS DATE) AS RE_ESTB_DTE
				 --, CONVERT(CHAR(8), A.PLAN_DT, 112) AS RE_ESTB_DTE
				 , CAST(A.PLAN_DT AS DATE) AS RE_ESTB_DTE
				 , CAST( C.MAX_DTE AS DATE)  AS MAX_DTE
				 , V.FROM_DT
			   FROM VW_FP_PLAN_VERSION A
			 CROSS JOIN (SELECT DISTINCT RSRC_CD, SCM_RSRC_NM FROM TB_SKC_FP_RSRC_MST WHERE PLNT_CD = '1130' AND ATTR_01 = '12' AND SCM_USE_YN = 'Y' AND USE_YN = 'Y' ) B
			  LEFT JOIN (SELECT RSRC_CD, MAX(PLAN_DTE) AS MAX_DTE
						   FROM TB_SKC_FP_RS_PRDT_PLAN_CH 
						  WHERE MODIFY_BY IS NOT NULL
						    AND VER_ID = @P_FP_VERSION
						  GROUP BY RSRC_CD) C
				ON B.RSRC_CD = C.RSRC_CD
			  LEFT JOIN											-- FROM_DT 추가
			  (
				SELECT DISTINCT VERSION, MAX(FROM_DT) AS FROM_DT
				FROM  VW_FP_PLAN_VERSION
				GROUP BY VERSION
			  ) V
			 ON A.VERSION = V.VERSION
			 WHERE PLAN_SCOPE = 'FP-CHDM'
			   AND A.VERSION = @P_FP_VERSION
		END;

END;

		
GO
