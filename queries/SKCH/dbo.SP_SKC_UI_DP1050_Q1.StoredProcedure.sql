USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP1050_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP1050_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 변경 이력 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-06-17  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP1050_Q1] (
	 @P_VER_ID				NVARCHAR(32)
   , @P_EMP_CD		        NVARCHAR(30)			  
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

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP1050_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP1050_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_EMP_CD ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_FROM_DATE ), '')		
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_DATE ), '')						   			   				   				   			  	   
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

	DECLARE @TMP_EMP TABLE (EMP_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT);
	INSERT INTO @TMP_EMP
	SELECT DISTINCT DESC_CD AS EMP_ID 
	  FROM TB_DPD_USER_HIER_CLOSURE
	 WHERE ANCS_CD = @P_EMP_CD
	   --AND MAPPING_SELF_YN = 'Y'
	   --AND DEPTH_NUM != 0
	   --AND DESC_ROLE_CD = 'MARKETER'

	BEGIN
		SELECT A.ID
			 , @P_VER_ID AS DP_VER_ID
			 , CASE WHEN @P_LANG_CD = 'ko' THEN C.ACCOUNT_NM
					WHEN @P_LANG_CD = 'en' THEN C.ACCOUNT_NM_EN END AS ACCOUNT_NM
			 , C.ATTR_04 AS REGION
			 , C.ATTR_06 AS PLNT_NM
			 , CASE WHEN @P_LANG_CD = 'ko' THEN B.ITEM_NM
					WHEN @P_LANG_CD = 'en' THEN B.ITEM_NM_EN END AS ITEM_NM
			 , CONVERT(CHAR(10), A.BASE_DATE, 23) AS BASE_DATE
			 , QTY
			 , D2.DISPLAY_NAME AS ENTRY_BY
			 , D1.DISPLAY_NAME AS MODIFY_BY
			 , CONVERT(CHAR(23), A.CREATE_DTTM, 20) AS MODIFY_DTTM
		  FROM TB_DP_ENTRY_LOG A
		 INNER JOIN (SELECT ITEM_ID
						  , ACCOUNT_ID
						  , BASE_DATE
						  , MAX(CREATE_DTTM) AS CREATE_DTTM 
					   FROM TB_DP_ENTRY_LOG 
					  WHERE VER_ID = (SELECT ID FROM TB_DP_CONTROL_BOARD_VER_MST WHERE VER_ID = @P_VER_ID)
					  GROUP BY ITEM_ID, ACCOUNT_ID, BASE_DATE) A2
		    ON A.ITEM_ID = A2.ITEM_ID
		   AND A.ACCOUNT_ID = A2.ACCOUNT_ID
		   AND A.BASE_DATE = A2.BASE_DATE
		   AND A.CREATE_DTTM = A2.CREATE_DTTM
		 INNER JOIN TB_CM_ITEM_MST B
			ON A.ITEM_ID = B.ID
		 INNER JOIN TB_DP_ACCOUNT_MST C
			ON A.ACCOUNT_ID = C.ID
		 INNER JOIN @TMP_ITEM TI
		    ON A.ITEM_ID = TI.ITEM_ID
		 INNER JOIN @TMP_ACCOUNT TA
		    ON A.ACCOUNT_ID = TA.ACCOUNT_ID
		 INNER JOIN @TMP_EMP TE
		    ON A.USERNAME = TE.EMP_ID
		 INNER JOIN TB_AD_USER D1
		    ON A.CREATE_BY = D1.USERNAME		 
		 INNER JOIN TB_AD_USER D2
		    ON A.USERNAME = D2.USERNAME		 
		 WHERE COMMENT IS NULL
		   AND QTY != 0
		   AND VER_ID = (SELECT ID FROM TB_DP_CONTROL_BOARD_VER_MST WHERE VER_ID = @P_VER_ID)
		   AND A.BASE_DATE BETWEEN CONVERT(VARCHAR, @P_FROM_DATE, 112) AND CONVERT(VARCHAR, @P_TO_DATE, 112)
		 ORDER BY 3, 4, 5, 6, 7
		END;
		
END
GO
