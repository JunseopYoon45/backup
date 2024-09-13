USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP3010_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP3010_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     긴급 요청 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-04  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP3010_Q1] (
	 @P_CORP_CD             NVARCHAR(30)    = 'ALL'    -- 법인
   --, @P_EMP_CD              NVARCHAR(30)    = 'ALL'    -- 담당자 CODE
   , @p_ITEM_FILTER		    NVARCHAR(MAX)   = '[]'
   , @p_ACCOUNT_FILTER      NVARCHAR(MAX)   = '[]'
   , @P_FROM_DATE			NVARCHAR(100)
   , @P_TO_DATE				NVARCHAR(100)
   , @P_LANG_CD				NVARCHAR(10)	= 'ko'
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
BEGIN
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
	--IF @P_EMP_CD = 'ALL' SET @P_EMP_CD = '';

	SELECT A.ID
		 , C.ATTR_01 AS CORP_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ATTR_02
				WHEN @P_LANG_CD = 'en' THEN C.ATTR_11 END AS CORP_NM
		 , D.ANCESTER_CD AS TEAM_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN D.ANCESTER_NM
				WHEN @P_LANG_CD = 'en' THEN D.ANCESTER_NM_EN END AS TEAM_NM
		 , A.EMP_ID
		 , E.DISPLAY_NAME AS EMP_NM
		 , C.ATTR_03 AS ACCOUNT_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ACCOUNT_NM
				WHEN @P_LANG_CD = 'en' THEN C.ACCOUNT_NM_EN END AS ACCOUNT_NM
		 , C.ATTR_04 AS REGION
		 , B.ITEM_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN B.ITEM_NM
				WHEN @P_LANG_CD = 'en' THEN B.ITEM_NM_EN END AS ITEM_NM
		 , B.ATTR_01 AS PACK_UNIT
		 , C.ATTR_05 AS PLNT_CD
		 , (SELECT CASE WHEN @P_LANG_CD = 'ko' THEN PLNT_NM
						WHEN @P_LANG_CD = 'en' THEN PLNT_NM_EN END AS PLNT_NM
			  FROM TB_SKC_CM_PLNT_MST 
			 WHERE PLNT_CD = C.ATTR_05) AS PLNT_NM
		 , A.URNT_DMND_QTY
		 , CAST(A.REQUEST_DATE_ID AS DATE) AS REQUEST_DATE_ID
		 , CONVERT(VARCHAR, A.CREATE_DTTM, 23) AS REGISTER_DATE_ID
		 , A.PRDT_PLAN_QTY
		 , CAST(A.PRDT_PLAN_DATE_ID AS DATE) AS PRDT_PLAN_DATE_ID
		 , CAST(A.VER_DATE_ID AS DATE) AS VER_DATE_ID
		 , A.STATUS_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN F.COMN_CD_NM
				WHEN @P_LANG_CD = 'en' THEN F.ATTR_01_VAL END AS STATUS_NM
		 --, A.STATUS_CD AS STATUS_NM
		 , (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = A.CREATE_BY) AS CREATE_BY
		 , A.CREATE_DTTM
		 , (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = A.MODIFY_BY) AS MODIFY_BY
		 , A.MODIFY_DTTM
	  FROM TB_SKC_DP_URNT_DMND_MST A
	 INNER JOIN TB_CM_ITEM_MST B 
		ON A.ITEM_MST_ID = B.ID
	 INNER JOIN TB_DP_ACCOUNT_MST C
		ON A.ACCOUNT_ID = C.ID
	 INNER JOIN TB_DPD_SALES_HIER_CLOSURE D
		ON C.ID = D.DESCENDANT_ID
	   AND DEPTH_NUM = 2
	 INNER JOIN TB_AD_USER E
	    ON A.EMP_ID = E.USERNAME
	 INNER JOIN @TMP_ITEM TI
	    ON TI.ITEM_ID = B.ID
	 INNER JOIN @TMP_ACCOUNT TA
	    ON TA.ACCOUNT_ID = C.ID
	 INNER JOIN TB_AD_COMN_CODE F
	    ON A.STATUS_CD = F.COMN_CD
	   AND F.SRC_ID ='8a7776af8ef04b72018ef08538b70000'
	 WHERE 1=1
	 --(A.EMP_ID = @P_EMP_CD OR ISNULL(@P_EMP_CD, '') = '')
	   AND (C.ATTR_01 = @P_CORP_CD OR ISNULL(@P_CORP_CD, 'ALL') = '')
	   AND A.CREATE_DTTM BETWEEN @P_FROM_DATE AND @P_TO_DATE
	 ORDER BY 18
END
GO
