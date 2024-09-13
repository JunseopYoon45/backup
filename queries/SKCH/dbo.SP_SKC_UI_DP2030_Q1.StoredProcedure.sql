USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP2030_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP2030_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요 우선순위 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-21  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP2030_Q1] (
	  @P_VER_ID				NVARCHAR(30)
	, @P_CORP_CD			NVARCHAR(30) = NULL
	, @p_ITEM_FILTER        NVARCHAR(MAX)   = '[]'
    , @p_ACCOUNT_FILTER     NVARCHAR(MAX)   = '[]'
    , @P_MATCH_OPTION		NVARCHAR(10)    = ''
	, @p_FROM_DATE			VARCHAR(100) 
	, @p_TO_DATE			VARCHAR(100) 
	, @P_LANG_CD			NVARCHAR(10)	= 'ko'
	, @P_USER_ID			NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID			NVARCHAR(100)   = NULL    -- VIEW_ID
	)
AS
BEGIN
SET NOCOUNT ON

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP2030_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP2030_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD ), '')		
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(10) , @P_MATCH_OPTION ), '')		
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_FROM_DATE ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_TO_DATE),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID),'')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

	DECLARE @v_FROM_DATE DATE;
	DECLARE @v_TO_DATE DATE;
	DECLARE	@v_VER_ID	NVARCHAR(32);

	SELECT @v_FROM_DATE = @p_FROM_DATE;
	SELECT @v_TO_DATE = @p_TO_DATE;
	SELECT @v_VER_ID = ID
	  FROM TB_DP_CONTROL_BOARD_VER_MST
	 WHERE VER_ID = @p_VER_ID;

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

	IF OBJECT_ID('tempdb..#TM_STRTGY_ENTRY') IS NOT NULL DROP TABLE #TM_STRTGY_ENTRY -- 임시테이블 삭제
		SELECT A.ID
			 , A.ITEM_MST_ID
			 , A.ACCOUNT_ID
			 , A.BASE_DATE
			 , A.STRTGY_YN
		  INTO #TM_STRTGY_ENTRY
		  FROM TB_SKC_DP_STRTGY_ENTRY A
		 INNER JOIN @TMP_ITEM B
		    ON A.ITEM_MST_ID = B.ITEM_ID
		 INNER JOIN @TMP_ACCOUNT C
		    ON A.ACCOUNT_ID = C.ACCOUNT_ID
		 WHERE VER_ID = @P_VER_ID
		   AND BASE_DATE BETWEEN @p_FROM_DATE AND @p_TO_DATE;

	WITH DMND AS (
		SELECT /*+ USE_HASH (A) */ 
			   VER_ID
			 , E.EMP_ID
			 , A.ITEM_MST_ID
			 , A.ACCOUNT_ID
			 --, DATEADD(MONTH, DATEDIFF(MONTH, 0, BASE_DATE), 0) AS BASE_DATE
			 , CONVERT(DATE, YYYYMM + '01') AS BASE_DATE
			 , SUM(QTY) AS QTY
		  FROM TB_DP_ENTRY A WITH (INDEX(IDX_TB_DP_ENTRY_01))
		 INNER JOIN @TMP_ITEM B 
		    ON A.ITEM_MST_ID = B.ITEM_ID
		 INNER JOIN @TMP_ACCOUNT C
		    ON A.ACCOUNT_ID = C.ACCOUNT_ID
		 INNER JOIN TB_CM_CALENDAR D
			ON A.BASE_DATE = D.DAT
		 INNER JOIN TB_DP_USER_ITEM_ACCOUNT_MAP E
		    ON A.ITEM_MST_ID = E.ITEM_MST_ID
		   AND A.ACCOUNT_ID = E.ACCOUNT_ID
		   AND E.ACTV_YN = 'Y'
		 WHERE VER_ID = @v_VER_ID
		   AND A.AUTH_TP_ID = (SELECT ID FROM TB_CM_LEVEL_MGMT WHERE LV_CD = 'MARKETER')
		   AND BASE_DATE BETWEEN @v_FROM_DATE AND @v_TO_DATE
		   AND A.ACTV_YN = 'Y'
		 GROUP BY VER_ID, E.EMP_ID, A.ITEM_MST_ID, A.ACCOUNT_ID, YYYYMM
	)
	SELECT D.ID
		 , A.VER_ID
		 , B.ID AS ITEM_MST_ID
		 , C.ID AS ACCOUNT_ID
		 , C.ATTR_01 AS CORP_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ATTR_02 
				ELSE C.ATTR_11 END AS CORP_NM
		 , E.ANCESTER_CD AS TEAM_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN E.ANCESTER_NM 
				ELSE E.ANCESTER_NM_EN END AS TEAM_NM
		 , A.EMP_ID AS EMP_CD
		 , F.DISPLAY_NAME AS EMP_NM
		 , C.ATTR_03 AS ACCOUNT_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ACCOUNT_NM 
				ELSE C.ACCOUNT_NM_EN END AS ACCOUNT_NM
		 , C.ATTR_04 AS REGION
		 , B.ITEM_CD
		 , CASE WHEN @P_LANG_CD = 'ko' THEN B.ITEM_NM
				WHEN @P_LANG_CD = 'en' AND LEN(B.ITEM_NM_EN) = 0 THEN B.ITEM_NM
				ELSE B.ITEM_NM_EN END AS ITEM_NM
		 , B.ATTR_01 AS PACK_UNIT
		 , C.ATTR_05 AS PLNT_CD
		 , C.ATTR_06 AS PLNT_NM
		 , CONVERT(CHAR(8), A.BASE_DATE, 112) AS BASE_DATE
		 , A.QTY
		 , D.STRTGY_YN
	  FROM DMND A
	 INNER JOIN TB_CM_ITEM_MST B 
		ON A.ITEM_MST_ID = B.ID 
	 INNER JOIN TB_DP_ACCOUNT_MST C 
		ON A.ACCOUNT_ID = C.ID
	 INNER JOIN #TM_STRTGY_ENTRY D WITH(NOLOCK)
		ON A.ITEM_MST_ID = D.ITEM_MST_ID
	   AND A.ACCOUNT_ID = D.ACCOUNT_ID
	   AND A.BASE_DATE = D.BASE_DATE
	 INNER JOIN TB_DPD_SALES_HIER_CLOSURE E
	    ON C.ID = E.DESCENDANT_ID
	   AND DEPTH_NUM = 2
	 INNER JOIN TB_AD_USER F
		ON A.EMP_ID = F.USERNAME
	 WHERE (C.ATTR_01 = @P_CORP_CD OR ISNULL(@P_CORP_CD, '') = '')
	 ORDER BY C.ATTR_03, C.ATTR_05, C.ATTR_07, B.ITEM_CD, BASE_DATE;

END
GO
