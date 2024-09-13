USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2020_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2020_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     PLANT 정보 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-18  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2020_Q1] (
	 @P_CORP_CD             NVARCHAR(30)    = NULL    -- 법인
   , @P_PLNT_CD             NVARCHAR(30)    = NULL    -- PLANT CODE
   , @P_LANG_CD				NVARCHAR(10)	= 'ko'
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
BEGIN
SET NOCOUNT ON;

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_CM2020_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_CM2020_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_CORP_CD), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLNT_CD ), '')				  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_LANG_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID),  '')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

	IF @P_CORP_CD = 'ALL' SET @P_CORP_CD = '';
	IF @P_PLNT_CD = 'ALL' SET @P_PLNT_CD = '';

	SELECT ID
		 , CASE WHEN @P_LANG_CD = 'ko' THEN CORP_NM
				WHEN @P_LANG_CD = 'en' THEN CORP_NM_EN END AS CORP_NM
		 , PLNT_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN PLNT_NM
				WHEN @P_LANG_CD = 'en' THEN PLNT_NM_EN END AS PLNT_NM
		 , PRDT_YN
		 , STCK_YN
		 , ACTV_YN
		 , CREATE_BY
		 , CREATE_DTTM
		 , MODIFY_BY
		 , MODIFY_DTTM
	  FROM TB_SKC_CM_PLNT_MST
	 WHERE (CORP_CD = @P_CORP_CD OR ISNULL(@P_CORP_CD, 'ALL') = '')
	   AND (PLNT_CD = @P_PLNT_CD OR ISNULL(@P_PLNT_CD, 'ALL') = '')
	   AND CORP_CD != 'Y100'			-- SAP에서 인터페이스 받는 Y100을 'C100'으로 변경해서 사용
	   --AND DEL_YN = 'N'
	 ORDER BY CORP_NM, PLNT_CD;
END


GO
