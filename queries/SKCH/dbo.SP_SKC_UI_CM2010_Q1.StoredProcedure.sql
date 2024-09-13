USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2010_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2010_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 단위 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-25  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2010_Q1] (
	 @P_CORP_CD             NVARCHAR(30)    = NULL    -- 법인
   , @P_EMP_CD              NVARCHAR(32)    = NULL    -- 담당자 CODE
   , @p_ITEM_FILTER        	NVARCHAR(MAX)   = '[]'
   , @p_ACCOUNT_FILTER      NVARCHAR(MAX)   = '[]'
   , @p_LANG_CD				NVARCHAR(10)    = 'ko'
   , @P_MATCH_OPTION		NVARCHAR(10)    = ''
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
BEGIN

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_CM2010_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_CM2010_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_CORP_CD), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_EMP_CD ), '')				  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_LANG_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MATCH_OPTION), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID),  '')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

/************************************************************************************************************************
	-- Item Search 
		--	ex) '[{"ITEM_CD":"41660"},{"ITEM_CD":"41875"}, {"ATTR_01": "Black"}, {"ATTR_02": "B"}]'
************************************************************************************************************************/
	DECLARE @TMP_ITEM TABLE (ITEM_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ITEM_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ITEM_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);
	DECLARE @P_STR	NVARCHAR(MAX);

	SELECT @P_STR = dbo.FN_G_ITEM_FILTER_EXTENDS('CONTAINS', @p_ITEM_FILTER);

	INSERT INTO @TMP_ITEM
	EXECUTE sp_executesql   @P_STR; 
	
/************************************************************************************************************************
	-- Account Search
************************************************************************************************************************/
	DECLARE @TMP_ACCOUNT TABLE (ACCOUNT_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ACCOUNT_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);

	SELECT @P_STR = dbo.FN_G_ACCT_FILTER_EXTENDS('CONTAINS', @p_ACCOUNT_FILTER);

	INSERT INTO @TMP_ACCOUNT
	EXECUTE sp_executesql @P_STR;

	IF @P_CORP_CD = 'ALL' SET @P_CORP_CD = '';

	DECLARE @TMP_EMP TABLE (EMP_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT);

	IF EXISTS (SELECT 1 
				 FROM TB_AD_AUTHORITY 
				WHERE AUTHORITY = 'ADMIN' 
				  AND USER_ID = (SELECT ID FROM TB_AD_USER WHERE USERNAME = @P_EMP_CD)) -- SET @P_EMP_CD = '';
		BEGIN
			INSERT INTO @TMP_EMP (EMP_ID)
			SELECT DISTINCT DESC_ID AS EMP_ID
			  FROM TB_DPD_USER_HIER_CLOSURE 
			 WHERE DESC_ROLE_CD = 'MARKETER';
		END
	ELSE
		BEGIN
			IF EXISTS (SELECT DISTINCT DESC_ID AS EMP_ID FROM TB_DPD_USER_HIER_CLOSURE WHERE ANCS_CD = @P_EMP_CD AND DESC_ROLE_CD = 'MARKETER')
				BEGIN
				INSERT INTO @TMP_EMP (EMP_ID)
				SELECT DISTINCT DESC_ID AS EMP_ID 
				  FROM TB_DPD_USER_HIER_CLOSURE 
				 WHERE ANCS_CD = @P_EMP_CD 
				   --AND ANCS_ROLE_CD = 'TEAM' 
				   AND DESC_ROLE_CD = 'MARKETER';
				END
			ELSE
			BEGIN
				INSERT INTO @TMP_EMP (EMP_ID)
				SELECT ID AS EMP_ID
				  FROM TB_AD_USER
				 WHERE USERNAME = @P_EMP_CD;
			END
		END


	SELECT A.ID
		 , B.ID AS ITEM_MST_ID
		 , C.ID AS ACCOUNT_ID
		 , C.ATTR_01 AS CORP_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ATTR_02 
				WHEN @P_LANG_CD = 'en' THEN COALESCE(C.ATTR_11, C.ATTR_02) END AS CORP_NM
		 , E.ANCESTER_CD AS TEAM_CD
		 , E.ANCESTER_NM AS TEAM_NM
		 , UPPER(TRIM(A.EMP_ID)) AS EMP_NM
		 , D.DISPLAY_NAME AS EMP_ID
		 , C.ACCOUNT_CD AS ACCOUNT_CD_ORG
		 , C.ATTR_03 AS ACCOUNT_CD
		 , CASE WHEN (@P_LANG_CD = 'ko' OR C.ACCOUNT_NM_EN = '')THEN C.ACCOUNT_NM
				WHEN @P_LANG_CD = 'en' THEN C.ACCOUNT_NM_EN END AS ACCOUNT_NM
		 , C.ATTR_04 AS REGION_CD
		 , C.ATTR_04 AS REGION_NM
		 , B.ITEM_CD
		 , CASE WHEN (@P_LANG_CD = 'ko' OR B.ITEM_NM_EN = '' )THEN B.ITEM_NM
				WHEN @P_LANG_CD = 'en' THEN B.ITEM_NM_EN END AS ITEM_NM
		 , C.ATTR_05 AS PLNT_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ATTR_06 
				WHEN @P_LANG_CD = 'en' THEN F.PLNT_NM_EN END AS PLNT_NM
		 , A.ACTV_YN
		 , A.MANAGER_YN
		 , A.CREATE_BY
		 , A.CREATE_DTTM
		 , A.MODIFY_BY
		 , A.MODIFY_DTTM
	  FROM TB_DP_USER_ITEM_ACCOUNT_MAP A 
	 INNER JOIN TB_CM_ITEM_MST B 
		ON A.ITEM_MST_ID = B.ID
	 INNER JOIN TB_DP_ACCOUNT_MST C
		ON A.ACCOUNT_ID = C.ID
	  LEFT JOIN TB_AD_USER D
		--ON UPPER(A.EMP_ID) = UPPER(D.USERNAME)
		ON A.EMP_ID = D.ID
	 INNER JOIN TB_DPD_SALES_HIER_CLOSURE E
		ON C.ID = E.DESCENDANT_ID
	   AND DEPTH_NUM = 2
	 INNER JOIN @TMP_ITEM TI
	    ON A.ITEM_MST_ID = TI.ITEM_ID
	 INNER JOIN @TMP_ACCOUNT TA
	    ON A.ACCOUNT_ID = TA.ACCOUNT_ID
	 INNER JOIN TB_SKC_CM_PLNT_MST F
	    ON C.ATTR_05 = F.PLNT_CD
	 INNER JOIN @TMP_EMP EMP
	    ON A.EMP_ID = EMP.EMP_ID
	 WHERE (C.ATTR_01 = @P_CORP_CD OR ISNULL(@P_CORP_CD, 'ALL') = '')
	 ORDER BY C.ATTR_03, B.ITEM_CD, C.ATTR_05, D.DISPLAY_NAME, A.ACTV_YN;
END
GO
