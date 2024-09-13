USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP2020_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP2020_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     고객 우선순위 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-19  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP2020_Q1] (
	 @P_VER_ID			   NVARCHAR(30)
   , @p_ACCOUNT_FILTER     NVARCHAR(MAX)   = '[]'
   , @P_LANG_CD			   NVARCHAR(10)	   = 'ko'
   , @P_USER_ID			   NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID			   NVARCHAR(100)   = NULL    -- VIEW_ID
	)
AS
BEGIN
SET NOCOUNT ON;


---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP2020_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP2020_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @P_USER_ID ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @P_VIEW_ID ), '')	
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

/************************************************************************************************************************
	-- Account Search
************************************************************************************************************************/
	DECLARE @TMP_ACCOUNT TABLE (ACCOUNT_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ACCOUNT_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);
	DECLARE @TMP_ACCOUNT2 TABLE (ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, REGION NVARCHAR(4) COLLATE DATABASE_DEFAULT);

	DECLARE @P_STR	NVARCHAR(MAX);
	SELECT @P_STR = dbo.FN_G_ACCT_FILTER_EXTENDS('CONTAINS', @p_ACCOUNT_FILTER);

	INSERT INTO @TMP_ACCOUNT
	EXECUTE sp_executesql @P_STR;

	INSERT INTO @TMP_ACCOUNT2 (ACCOUNT_CD, REGION)
	SELECT DISTINCT SUBSTRING(ACCOUNT_CD, 1, CHARINDEX('-', ACCOUNT_CD) - 1) AS ACCOUNT_CD
		 , PARSENAME(REPLACE(ACCOUNT_CD, '-', '.'), 2) AS REGION 
	  FROM @TMP_ACCOUNT;

	SELECT A.ID
		 , VER_ID
		 , A.ACCOUNT_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ACCOUNT_NM
				ELSE C.ACCOUNT_NM_EN END AS ACCOUNT_NM
		 , A.REGION
		 , ANNUAL_YN
		 , STRTGY_YN
		 , A.PRIORT		 
		 , A.CREATE_BY
		 , A.CREATE_DTTM
		 , A.MODIFY_BY
		 , A.MODIFY_DTTM
	  FROM TB_SKC_DP_STRTGY_ACCOUNT_MST A
	 INNER JOIN @TMP_ACCOUNT2 B 
	    ON A.ACCOUNT_CD = B.ACCOUNT_CD
	   AND A.REGION = B.REGION
	   --AND A.REGION = PARSENAME(REPLACE(B.ACCOUNT_CD, '-', '.'), 2)
	 INNER JOIN (SELECT DISTINCT ATTR_03, ACCOUNT_NM, ACCOUNT_NM_EN FROM TB_DP_ACCOUNT_MST) C
	    ON A.ACCOUNT_CD = C.ATTR_03
	 WHERE VER_ID = @P_VER_ID
	 ORDER BY PRIORT, A.ACCOUNT_CD;

END
GO
