USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP1031_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP1031_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     사업계획 점검 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-05-17  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP1031_Q1] (
	 @P_VER_ID				NVARCHAR(32)
   , @P_MANAGER_CD          NVARCHAR(30)			  -- 팀장/법인장 CODE
   , @P_EMP_CD				NVARCHAR(30)	= NULL    -- 마케터 CODE
   , @p_ITEM_FILTER		    NVARCHAR(MAX)   = '[]'
   , @p_ACCOUNT_FILTER      NVARCHAR(MAX)   = '[]'
   , @P_REGION				NVARCHAR(10)	
   , @P_LANG_CD				NVARCHAR(10)    = 'ko'
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
BEGIN

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP1031_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_DP1031_Q1 'DP-202409-01-BP','139383','','[]','[]','ALL','ko','I23671','UI_DP1031'

*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP1031_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MANAGER_CD ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_EMP_CD ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_REGION ), '')					   				   				   			  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_LANG_CD),  '')
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

	DECLARE @v_VER_ID VARCHAR(32);
	DECLARE @v_FROM_DATE DATE;
	DECLARE @v_TO_DATE DATE;
	--SET @P_VER_ID = 'DP-202405-03-M';

	SELECT @v_VER_ID = ID 
		 , @v_FROM_DATE = FROM_DATE
		 , @v_TO_DATE = TO_DATE
	  FROM TB_DP_CONTROL_BOARD_VER_MST WHERE VER_ID = @P_VER_ID
	
	IF @P_EMP_CD IS NULL SET @P_EMP_CD = '';
	IF @P_REGION = 'ALL' SET @P_REGION = '';

	DECLARE @TMP_EMP TABLE (EMP_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT);
	INSERT INTO @TMP_EMP
	SELECT DESC_ID AS EMP_ID 
	  FROM TB_DPD_USER_HIER_CLOSURE
	 WHERE ANCS_CD = @P_MANAGER_CD
	   AND MAPPING_SELF_YN = 'Y'
	   AND DEPTH_NUM != 0
	   AND DESC_ROLE_CD = 'MARKETER'
	   AND (DESC_CD = @P_EMP_CD OR ISNULL(@P_EMP_CD, '') = '');

	IF OBJECT_ID('tempdb..#TM_USER') IS NOT NULL DROP TABLE #TM_USER
		SELECT B.ITEM_MST_ID
			 , B.ACCOUNT_ID
			 , A.EMP_ID
		  INTO #TM_USER
		  FROM @TMP_EMP A
		 INNER JOIN TB_DP_USER_ITEM_ACCOUNT_MAP B
		    ON A.EMP_ID = B.EMP_ID
		 INNER JOIN @TMP_ITEM TI
		    ON B.ITEM_MST_ID = TI.ITEM_ID
	     INNER JOIN @TMP_ACCOUNT TA
		    ON B.ACCOUNT_ID = TA.ACCOUNT_ID
		 WHERE B.ACTV_YN = 'Y'

	IF OBJECT_ID('tempdb..#TM_ENTRY') IS NOT NULL DROP TABLE #TM_ENTRY
		SELECT A.ITEM_MST_ID
			 , A.ACCOUNT_ID
			 , B.EMP_ID
			 , CAL.YYYYMM AS BASE_DATE
			 , SUM(QTY) AS QTY
		  INTO #TM_ENTRY
		  FROM TB_DP_ENTRY A
		 INNER JOIN #TM_USER B
		    ON A.ITEM_MST_ID = B.ITEM_MST_ID
		   AND A.ACCOUNT_ID = B.ACCOUNT_ID
		 INNER JOIN TB_DP_ACCOUNT_MST C
			ON B.ACCOUNT_ID = C.ID
		   AND (C.ATTR_04 = @P_REGION OR ISNULL(@P_REGION, 'ALL') = '')
		 INNER JOIN TB_CM_CALENDAR CAL
		    ON A.BASE_DATE = CAL.DAT
		 WHERE VER_ID = @v_VER_ID
		   AND A.BASE_DATE BETWEEN @v_FROM_DATE AND @v_TO_DATE	
		   AND A.ACTV_YN = 'Y'
		 GROUP BY A.ITEM_MST_ID, A.ACCOUNT_ID, B.EMP_ID, CAL.YYYYMM;		 

	IF OBJECT_ID('tempdb..#TM_ANNUAL') IS NOT NULL DROP TABLE #TM_ANNUAL
		SELECT A.ITEM_MST_ID
			 , A.ACCOUNT_ID
			 , YYYY
			 , ROUND(SUM(ANNUAL_QTY), -1) AS ANNUAL_QTY
		  INTO #TM_ANNUAL
		  FROM TB_DP_MEASURE_DATA A WITH (INDEX(IDX_DP_MEASURE_DATA02))
		 INNER JOIN TB_CM_CALENDAR B
			ON A.BASE_DATE = B.DAT
		 WHERE YYYY = LEFT(CONVERT(VARCHAR, @v_FROM_DATE, 112), 4)
		 GROUP BY A.ITEM_MST_ID, A.ACCOUNT_ID, YYYY
		HAVING SUM(ANNUAL_QTY) IS NOT NULL;

	IF OBJECT_ID('tempdb..#TM_M3') IS NOT NULL DROP TABLE #TM_M3
		SELECT A.ITEM_MST_ID
		 	 , A.ACCOUNT_ID
	 		 , ROUND(SUM(M3_QTY), -1) AS M3_QTY
		  INTO #TM_M3
		  FROM TB_DP_MEASURE_DATA A WITH (INDEX(IDX_DP_MEASURE_DATA03))
		 INNER JOIN TB_CM_CALENDAR B
			ON A.BASE_DATE = B.DAT
		 WHERE YYYYMM = LEFT(CONVERT(VARCHAR, @v_FROM_DATE, 112), 6)
		 GROUP BY A.ITEM_MST_ID, A.ACCOUNT_ID, YYYYMM
		HAVING SUM(M3_QTY) IS NOT NULL;

	BEGIN

		 SELECT /*+ USE_HASH (IH, SH) */ 
			    @P_VER_ID AS VER_ID
			  , @P_MANAGER_CD AS MANAGER_CD
			  , (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = @P_MANAGER_CD) AS MANAGER_NM
			  , SH.ATTR_04 AS REGION
			  ,	RT.EMP_ID   AS EMP_ID
			  , AU.DISPLAY_NAME AS EMP_NM
			  , SH.ACCOUNT_CD
			  , CASE WHEN @P_LANG_CD = 'ko' THEN SH.ACCOUNT_NM
					 WHEN @P_LANG_CD = 'en' AND SH.ACCOUNT_NM_EN IS NOT NULL THEN SH.ACCOUNT_NM_EN END AS ACCOUNT_NM
			  , SH.ATTR_05 AS PLNT_CD
			  , SH.ATTR_06 AS PLNT_NM
			  , IH.ATTR_07 AS BRAND_NM
			  , IH.ATTR_09 AS SERIES_NM
			  , IH.ATTR_11 AS GRADE_NM			  
			  , IH.ITEM_CD
			  , CASE WHEN @P_LANG_CD = 'ko' THEN IH.ITEM_NM
					 WHEN @P_LANG_CD = 'en' AND IH.ITEM_NM_EN IS NOT NULL THEN IH.ITEM_NM_EN END AS ITEM_NM
			  , RT.BASE_DATE AS "DATE" 
			  , COALESCE(YR.ANNUAL_QTY, 0) AS ANNUAL_QTY
			  , COALESCE(M3.M3_QTY, 0) AS M3_QTY
			  , QTY
		   FROM #TM_ENTRY RT 		 
		 -- INNER JOIN TB_DPD_ITEM_HIERACHY2 IH
			-- ON RT.ITEM_MST_ID = IH.ITEM_ID  
			--AND IH.LV_TP_CD='I'  
			--AND IH.USE_YN = 'Y' 
		  INNER JOIN TB_CM_ITEM_MST IH
		     ON RT.ITEM_MST_ID = IH.ID
		  INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 SH
			 ON RT.ACCOUNT_ID = SH.ACCOUNT_ID  
			AND SH.LV_TP_CD='S'  
			--AND SH.USE_YN = 'Y'
		  INNER JOIN TB_AD_USER AU
		     ON RT.EMP_ID = AU.ID
		   LEFT JOIN #TM_ANNUAL YR
			 ON RT.ITEM_MST_ID = YR.ITEM_MST_ID
			AND RT.ACCOUNT_ID = YR.ACCOUNT_ID
		   LEFT JOIN #TM_M3 M3
			 ON RT.ITEM_MST_ID = M3.ITEM_MST_ID
			AND RT.ACCOUNT_ID = M3.ACCOUNT_ID
		  ORDER BY SH.ATTR_04, SH.ACCOUNT_NM, SH.ATTR_05, IH.ITEM_CD, RT.BASE_DATE;
		END;
		
END
GO
