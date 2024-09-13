USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP2010_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP2010_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     제품 우선순위 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-19  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP2010_Q1] (
	 @P_VER_ID      NVARCHAR(30)
	,@P_ITEM_FILTER NVARCHAR(MAX)   = '[]'
	,@P_LANG_CD		NVARCHAR(10)	
	,@P_USER_ID     NVARCHAR(100)   = NULL    -- USER_ID
    ,@P_VIEW_ID     NVARCHAR(100)   = NULL    -- VIEW_ID
	)
AS
BEGIN

	SET NOCOUNT ON;

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP2010_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP2010_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER ), '')		   				   				   			  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_LANG_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID),  '')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID;

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

	SELECT ID
		 , VER_ID
		 , LVL02_CD AS GROUP_CD
		 , LVL02_NM AS GROUP_NM
		 , LVL03_CD AS BRAND_CD
		 , LVL03_NM AS BRAND_NM
		 , LVL04_CD AS SERIES_CD
		 , LVL04_NM AS SERIES_NM
		 , LVL05_CD AS GRADE_CD
		 , LVL05_NM AS GRADE_NM
		 , ITEM_MST_ID AS ITEM_ID
		 , A.ITEM_CD
		 --, CASE WHEN (@P_LANG_CD = 'ko' OR C.ITEM_NM_EN = '')   THEN A.ITEM_NM
			--	WHEN (@P_LANG_CD = 'en' AND C.ITEM_NM_EN != '') THEN C.ITEM_NM_EN END AS ITEM_NM
		 , CASE WHEN @P_LANG_CD = 'en' AND LEN(C.ITEM_NM_EN) > 0 THEN C.ITEM_NM_EN
				ELSE A.ITEM_NM END AS ITEM_NM
		 , M03
		 , M02
		 , M01
		 , MAVG
		 , CUM_RATE
		 , STRTGY_YN
		 , PRIORT
		 , A.CREATE_BY
		 , A.CREATE_DTTM
		 , A.MODIFY_BY
		 , A.MODIFY_DTTM
	  FROM TB_SKC_DP_STRTGY_ITEM_MST A
	 INNER JOIN @TMP_ITEM B 
	    ON A.ITEM_CD = B.ITEM_CD
	 INNER JOIN TB_DPD_ITEM_HIERACHY2 C
	    ON A.ITEM_CD = C.ITEM_CD
	 WHERE VER_ID = @P_VER_ID
	 ORDER BY PRIORT, CUM_RATE, A.ITEM_CD;

END
GO
