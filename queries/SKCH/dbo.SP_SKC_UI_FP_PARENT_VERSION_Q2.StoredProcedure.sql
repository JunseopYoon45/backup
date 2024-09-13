USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP_PARENT_VERSION_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP_PARENT_VERSION_Q2] (
     @P_VERSION             NVARCHAR(100)   = NULL    
   , @P_LANG_CD             NVARCHAR(100)   = NULL    -- LANG_CD
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP_PARENT_VERSION_Q2
-- COPYRIGHT       : ZIONEX
-- REMARK          : 확정된 MP 버전 호출
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-08-28  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP_PARENT_VERSION_Q2' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP_PARENT_VERSION_Q2 'DP-202407-01-M','ko','I23971','UI_FP1070'
*/
DECLARE @P_PGM_NM       NVARCHAR(100)  = ''
      , @PARM_DESC      NVARCHAR(1000) = ''
	  , @V_MP_VERSION	NVARCHAR(30);

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_VERSION   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------


BEGIN

	SELECT TOP 1 @V_MP_VERSION = SIMUL_VER_ID 
	  FROM TB_CM_CONBD_MAIN_VER_DTL A
	 INNER JOIN TB_CM_CONBD_MAIN_VER_MST B
		ON A.CONBD_MAIN_VER_MST_ID = B.ID
	 WHERE CONFRM_YN = 'Y'
	   AND DMND_VER_ID = @P_VERSION
	 ORDER BY A.CONFRM_DTTM DESC;

	SELECT LANG_VALUE + ' ' + @V_MP_VERSION
	  FROM TB_AD_LANG_PACK WITH(NOLOCK)
	 WHERE LANG_CD  = @P_LANG_CD
	   AND LANG_KEY = 'FP_PARENT_VERSION_3'

END

GO
