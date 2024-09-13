USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_UI_DP_94_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_UI_DP_94_Q1] (
			 @P_VER_CD		  NVARCHAR(255) = ''
			,@P_AUTH_TYPE     NVARCHAR(255) = NULL
			,@P_OPERATOR_ID   NVARCHAR(255) = NULL
			,@P_NEXT_ONLY     NVARCHAR(50) = NULL
								   ) AS 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
/**************************************************************************************************
	Process Status [SP_UI_DP_94_Q1]

	History ( date / writer / comment)
	- ****.**.** / ksh / draft 
	- 2020.12.07 / ksh / check work level about DP version by plan type
	- 2021.03.04 / ksh / 가상레벨은 안나오게 처리 
    - 2023.04.27 / ksh / ADD AUTO_APPV_YN 
	- 2024.03.26 / ksh / mapping hierarchy only
	- 2024.03.27 / ksh / bug fix and sorting 
	- 2024.04.22 / ksh / PROCESS_STATUS join bug fix 
	- 2024.05.28 / kim sohee /CANCEL => READY (custom)
**************************************************************************************************/

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_UI_DP_94_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM       NVARCHAR(100)  = ''
	  , @PARM_DESC      NVARCHAR(1000) = ''	
	  , @v_PLAN_SCOPE	NVARCHAR(30);

    SET @P_PGM_NM  = 'SP_UI_DP_94_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_CD    ), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_AUTH_TYPE ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_OPERATOR_ID   ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_NEXT_ONLY   ), '')	
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_OPERATOR_ID	;

---------- PGM LOG END ----------
 
BEGIN

IF EXISTS (	-- 영업사원
			SELECT 1
			  FROM TB_CM_LEVEL_MGMT 
			  WHERE LV_CD = @P_AUTH_TYPE
			   AND LEAF_YN = 'Y' 
			   AND COALESCE(DEL_YN,'N') = 'N'
			   AND ACTV_YN = 'Y'
		   )
	BEGIN
		 WITH TOP_USER
			AS (
				SELECT ANCS_CD 
					 , ANCS_ROLE_CD
					 , ANCS_ID 
					 , ANCS_ROLE_ID 
				  FROM TB_DPD_USER_HIER_CLOSURE
				WHERE DESC_CD = @P_OPERATOR_ID
				  AND DESC_ROLE_CD = @P_AUTH_TYPE
				  AND DEPTH_NUM = 1	 
			)
			--, PROCESS_STATUS
			--AS (
			--	SELECT --TU.DESC_ID, EP.DESC_CD, EP.DESC_ROLE_ID, EP.DESC_ROLE_CD, ANCS_ID, ANCS_CD, ANCS_ROLE_ID, ANCS_ROLE_CD	
			--		   US.ID			  AS DESC_ID
			--		 , TU.ANCS_CD		  AS DESC_CD
			--		 , TU.ANCS_ROLE_ID	  AS DESC_ROLE_ID
			--		 , TU.ANCS_ROLE_CD	  AS DESC_ROLE_CD
			--		 , US.ID			  AS ANCS_ID
			--		 , TU.ANCS_CD		  AS ANCS_CD
			--		 , TU.ANCS_ROLE_ID	  AS ANCS_ROLE_ID
			--		 , TU.ANCS_ROLE_CD	  AS ANCS_ROLE_CD
			--		 , ROW_NUMBER () OVER (ORDER BY PS.STATUS_DATE DESC) AS RW
			--		 , REPLACE(PS.STATUS, 'CANCEL', 'READY') AS "STATUS"
			--		 , PS.STATUS_DATE
			--		 , AUTO_APPV_YN
			--	FROM TOP_USER TU
			--		 INNER JOIN 
			--		 TB_AD_USER US
			--	  ON TU.ANCS_ID = US.ID 
			--		 LEFT OUTER JOIN 
			--		 TB_DP_PROCESS_STATUS_LOG PS 
			--	  ON PS.AUTH_TYPE = TU.ANCS_ROLE_CD
			--	 AND PS.OPERATOR_ID = TU.ANCS_CD
			--     AND VER_CD = @P_VER_CD
			--)
			, PROCESS_STATUS AS (
			SELECT --TU.DESC_ID, EP.DESC_CD, EP.DESC_ROLE_ID, EP.DESC_ROLE_CD, ANCS_ID, ANCS_CD, ANCS_ROLE_ID, ANCS_ROLE_CD	
					   US.DESC_ID			  AS DESC_ID
					 , US.DESC_CD		  AS DESC_CD
					 , TU.ANCS_ROLE_ID	  AS DESC_ROLE_ID
					 , TU.ANCS_ROLE_CD	  AS DESC_ROLE_CD
					 , US.ANCS_ID			  AS ANCS_ID
					 , TU.ANCS_CD		  AS ANCS_CD
					 , TU.ANCS_ROLE_ID	  AS ANCS_ROLE_ID
					 , TU.ANCS_ROLE_CD	  AS ANCS_ROLE_CD
					 , ROW_NUMBER () OVER (ORDER BY PS.STATUS_DATE DESC) AS RW
					 , REPLACE(PS.STATUS, 'CANCEL', 'READY') AS "STATUS"
					 , PS.STATUS_DATE
					 , AUTO_APPV_YN
				FROM TOP_USER TU
					 INNER JOIN 
					 TB_DPD_USER_HIER_CLOSURE US
				  ON TU.ANCS_ID = US.ANCS_ID
					 LEFT OUTER JOIN 
					 TB_DP_PROCESS_STATUS_LOG PS 
				  ON PS.AUTH_TYPE = TU.ANCS_ROLE_CD
				 AND PS.OPERATOR_ID = TU.ANCS_CD
			     AND VER_CD = @P_VER_CD
			) 
			, SALES_USER_MAP
			AS (
				SELECT SA.EMP_ID, SA.SALES_LV_ID, SL.SALES_LV_CD, SL.SALES_LV_NM, LV_MGMT_ID, LV.LV_CD, LV.LV_NM
				  FROM TB_DP_SALES_AUTH_MAP SA
					   INNER JOIN 
					   TB_DP_SALES_LEVEL_MGMT SL 
					ON SA.SALES_LV_ID = SL.ID 
				   AND SL.ACTV_YN = 'Y'
				   AND COALESCE(SL.DEL_YN,'N') = 'N'
					   INNER JOIN 
					   TB_CM_LEVEL_MGMT LV
					ON SL.LV_MGMT_ID = LV.ID 
--				   AND LV.LV_LEAF_YN = 'Y' 
				   AND COALESCE(LV.DEL_YN,'N') = 'N'
				   AND LV.ACTV_YN = 'Y'
				)
			SELECT SALES_LV_ID AS NODE_ID
				  ,SALES_LV_CD
				  ,SALES_LV_NM 
				  ,LV_MGMT_ID 
				  ,LV_CD 
				  ,LV_NM
				  ,DESC_ID AS USERID
				  ,US.DISPLAY_NAME AS USERNAME 
				  ,''+ANCS_ID		AS PARENT_ID
				  ,COALESCE(STATUS, 'READY') AS STATUS
				  ,STATUS_DATE
				  ,AUTO_APPV_YN
				  ,ROW_NUMBER () OVER (ORDER BY LV_CD, SALES_LV_CD, DISPLAY_NAME) AS SORTING
			  FROM PROCESS_STATUS PS
				   INNER JOIN 
				   SALES_USER_MAP SA
				ON PS.ANCS_ROLE_ID = SA.LV_MGMT_ID
			   AND PS.ANCS_ID = SA.EMP_ID 
				   INNER JOIN 
				   TB_AD_USER US
				ON PS.DESC_ID = US.ID
			 --WHERE RW = 1
			 ;
	END
ELSE IF	EXISTS ( -- 상위 사용자
				 SELECT SALES_LV_ID
				   FROM TB_DP_SALES_AUTH_MAP
				  WHERE SALES_LV_ID IN (SELECT ID FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID IN (SELECT ID FROM TB_CM_LEVEL_MGMT WHERE LV_CD = @P_AUTH_TYPE))
				    AND EMP_ID = (SELECT ID FROM TB_AD_USER WHERE USERNAME = @P_OPERATOR_ID)
			   )
	BEGIN 
		WITH USER_MAP
		 AS (	
 				SELECT DESC_ID, DESC_CD, DESC_ROLE_ID, MAPPING_SELF_YN
				 FROM TB_DPD_USER_HIER_CLOSURE
				WHERE ANCS_ROLE_CD = @P_AUTH_TYPE 
				  AND ANCS_CD = @P_OPERATOR_ID
			), SALES_USER
		 AS (	-- 나와 하위 사용자의 판매계층
			SELECT SL.ID		AS SALES_LV_ID
				 , SL.SALES_LV_CD
				 , SL.SALES_LV_NM
				 , UM.DESC_ID	AS EMP_ID
				 , UM.DESC_CD	AS USERNAME
				 , SL.LV_MGMT_ID
			  FROM TB_DP_SALES_AUTH_MAP SA
				   INNER JOIN 
				   TB_DP_SALES_LEVEL_MGMT SL 
				ON SA.SALES_LV_ID = SL.ID 
				   INNER JOIN 
				   USER_MAP UM
				ON SL.LV_MGMT_ID = UM.DESC_ROLE_ID
			   AND SA.EMP_ID = UM.DESC_ID
	), TOP_USER
	 AS (	   -- 매니저 사용자
		   SELECT SU.EMP_ID+SU.SALES_LV_ID			AS NODE_ID
				, SU.EMP_ID							AS USERID
				, SU.SALES_LV_ID					AS SALES_LV_ID 
				, SU.SALES_LV_CD					AS SALES_LV_CD
				, SU.SALES_LV_NM					AS SALES_LV_NM
				, LV.ID		 						AS LV_ID
				, LV.LV_CD							AS LV_CD
				, LV.LV_NM
				, US.USERNAME						AS USERNAME
				, US.DISPLAY_NAME	
				, UH.ANCS_ID+MAX(PL.SALES_LV_ID)		AS PARENT_ID
				, DENSE_RANK () OVER (ORDER BY LV.SEQ ASC) AS RW_ASC
				, DENSE_RANK () OVER (ORDER BY LV.SEQ DESC) AS RW_DESC
				, ROW_NUMBER () OVER (PARTITION BY SU.SALES_LV_CD ORDER BY US.DISPLAY_NAME ASC) AS PRIORT
		     FROM SALES_USER SU
				  INNER JOIN 
				  TB_AD_USER US 
			   ON SU.EMP_ID = US.ID
				  INNER JOIN 
				  TB_CM_LEVEL_MGMT LV			-- 나의 판매계층의 레벨
			   ON SU.LV_MGMT_ID = LV.ID 
				  LEFT OUTER JOIN 
				  TB_DPD_USER_HIER_CLOSURE UH	-- 내..바로 상위 (실질적인 매핑)
			   ON LV.ID = UH.DESC_ROLE_ID 
			  AND SU.EMP_ID = UH.DESC_ID
			  AND DEPTH_NUM = 1
				  LEFT OUTER JOIN 
				  SALES_USER PL		-- 내 상위의 판매계층 (여러개 나올 수도 있는데 하나만) 
			   ON UH.ANCS_ROLE_ID = PL.LV_MGMT_ID
			  AND UH.ANCS_ID = PL.EMP_ID
		GROUP BY  SU.EMP_ID+SU.SALES_LV_ID		
				, SU.EMP_ID			
				, US.USERNAME	
				, SU.SALES_LV_ID			
				, SU.SALES_LV_CD
				, SU.SALES_LV_NM
				, LV.ID		 	
				, LV.LV_CD		
				, LV.LV_NM
				, LV.SEQ
				, DISPLAY_NAME
				, UH.ANCS_ID
	), PROCESS_STATUS
	  AS (
			SELECT AUTH_TYPE, OPERATOR_ID
				 , ROW_NUMBER () OVER (PARTITION BY AUTH_TYPE, OPERATOR_ID ORDER BY STATUS_DATE DESC) AS RW
				 , AUTO_APPV_YN
				 , REPLACE(STATUS, 'CANCEL', 'READY') AS "STATUS"
				 , STATUS_DATE
			  FROM TB_DP_PROCESS_STATUS_LOG
			 WHERE VER_CD = @P_VER_CD
	),USER_ACCT_MAP
	AS (
		SELECT DISTINCT 
			   MM.EMP_ID, MM.AUTH_TP_ID, AC.ACCOUNT_CD AS ACCT_CD, AC.ID AS ACCT_ID, AC.ACCOUNT_NM AS ACCT_NM
		  FROM TB_DP_USER_ITEM_ACCOUNT_MAP MM
			   INNER JOIN 
			   USER_MAP UM 
			ON MM.EMP_ID = UM.DESC_ID
		   AND MM.AUTH_TP_ID = UM.DESC_ROLE_ID
			   INNER JOIN 
			   TB_DP_ACCOUNT_MST AC 
			ON MM.ACCOUNT_ID = AC.ID 
		   AND MM.ACTV_YN = 'Y'
		   AND AC.ACTV_YN = 'Y' 
		 UNION
		 SELECT DISTINCT MM.EMP_ID, MM.AUTH_TP_ID, AC.ACCOUNT_CD AS ACCT_CD, AC.ID AS ACCT_ID, AC.ACCOUNT_NM AS ACCT_NM
		   FROM TB_DP_USER_ACCOUNT_MAP MM
			   INNER JOIN 
			   USER_MAP UM 
			ON MM.EMP_ID = UM.DESC_ID
		   AND MM.AUTH_TP_ID = UM.DESC_ROLE_ID
			    INNER JOIN 
				TB_DP_ACCOUNT_MST AC
			 ON MM.ACCOUNT_ID = AC.ID 
			AND AC.ACTV_YN = 'Y'
			AND COALESCE(AC.DEL_YN,'N') = 'N'
		   AND MM.ACTV_YN = 'Y'
		   AND AC.ACTV_YN = 'Y' 
		 UNION
		 SELECT DISTINCT MM.EMP_ID, MM.AUTH_TP_ID, SH.DESCENDANT_CD AS ACCT_CD, SH.DESCENDANT_ID AS ACCT_ID, SH.DESCENDANT_NM AS ACCT_NM
		   FROM TB_DP_USER_ACCOUNT_MAP MM
			   INNER JOIN 
			   USER_MAP UM 
			ON MM.EMP_ID = UM.DESC_ID
		   AND MM.AUTH_TP_ID = UM.DESC_ROLE_ID
			    INNER JOIN 
				TB_DPD_SALES_HIER_CLOSURE SH
			 ON MM.SALES_LV_ID = SH.ANCESTER_ID
		   AND MM.ACTV_YN = 'Y'
		   AND SH.LV_TP_CD = 'S'
		 WHERE SH.LEAF_YN = 'Y'
	), ACCT_MAP
	AS (
		SELECT EMP_ID, AUTH_TP_ID
			 , MAX(ACCT_CD)  AS ACCT_CD
			 , COUNT(ACCT_CD) AS CNT 
		  FROM USER_ACCT_MAP 
	  GROUP BY EMP_ID, AUTH_TP_ID
	), MAIN
	AS (
		 SELECT NODE_ID
			  , USERID
			  , USERNAME
			  , DISPLAY_NAME
			  , SALES_LV_ID 
			  , SALES_LV_CD
			  , SALES_LV_NM
			  , LV_ID
			  , LV_CD
			  , LV_NM
			  , CASE WHEN RW_ASC =1 THEN NULL ELSE PARENT_ID END AS PARENT_ID
			  , ROW_NUMBER () OVER (ORDER BY LV_CD, SALES_LV_CD, DISPLAY_NAME) AS SORTING
		   FROM TOP_USER 
		  WHERE RW_ASC =1 OR PARENT_ID IN (SELECT NODE_ID FROM TOP_USER WHERE PRIORT = 1) -- 중복된 사용자-판매계층은 표시하고, 그 하위를 생략
		 UNION
		 SELECT  
			    UH.DESC_ID+AC.ID AS NODE_ID
			  , UH.DESC_ID
			  , US.USERNAME 
			  , US.DISPLAY_NAME
			  , AC.ID AS ACCT_ID 
			  , AM.ACCT_CD +CASE WHEN AM.CNT = 1 THEN '' ELSE ' (+'+CAST(AM.CNT-1 AS NVARCHAR(10))+')' END
			  , AC.ACCOUNT_NM +CASE WHEN AM.CNT = 1 THEN '' ELSE ' (+'+CAST(AM.CNT-1 AS NVARCHAR(10))+')' END
			  , UH.DESC_ROLE_ID
			  , LV.LV_CD 
			  , LV.LV_NM 
			  , PH.ANCS_ID		+MAX(TU.SALES_LV_ID) 
			  , (SELECT COUNT(1) FROM TOP_USER) +ROW_NUMBER () OVER (ORDER BY US.DISPLAY_NAME) AS SORTING
		   FROM USER_MAP UH	-- 최하위 사용자
				INNER JOIN 
				TB_AD_USER US 
			 ON UH.DESC_ID = US.ID 
				INNER JOIN 
				TB_CM_LEVEL_MGMT LV
			 ON UH.DESC_ROLE_ID = LV.ID 
			AND LV.LEAF_YN = 'Y'
				INNER JOIN 
				TB_DPD_USER_HIER_CLOSURE PH
			 ON UH.DESC_ID = PH.DESC_ID
			AND UH.DESC_ROLE_ID = PH.DESC_ROLE_ID
			AND PH.DEPTH_NUM = 1	
				INNER JOIN 
				TOP_USER TU
			 ON PH.ANCS_ID = TU.USERID
			AND PH.ANCS_ROLE_ID = TU.LV_ID
			AND TU.PRIORT = 1
				INNER JOIN 
				ACCT_MAP AM
			 ON UH.DESC_ID = AM.EMP_ID
			AND UH.DESC_ROLE_ID = AM.AUTH_TP_ID
				INNER JOIN 
				TB_DP_ACCOUNT_MST AC
			 ON AM.ACCT_CD = AC.ACCOUNT_CD
		  WHERE 1=1
			AND UH.MAPPING_SELF_YN = 'Y'
		GROUP BY UH.DESC_ID 
			   , UH.DESC_ID
			   , UH.DESC_CD
 			   , US.USERNAME 
			   , US.DISPLAY_NAME
			   , UH.DESC_ROLE_ID
			   , LV.LV_CD 
			   , LV.LV_NM 
			   , PH.ANCS_ID
			   , AC.ID
			   , AM.ACCT_CD
			   , AC.ACCOUNT_NM	
			   , AM.CNT 
			   )
		SELECT NODE_ID
			 , USERID
			 , DISPLAY_NAME USERNAME
			 , SALES_LV_ID 
			 , SALES_LV_CD
			 , SALES_LV_NM
			 , LV_ID
			 , LV_CD
			 , LV_NM
			 , PARENT_ID
			 , COALESCE(PROCESS_STATUS.STATUS, 'READY') AS "STATUS"
			 , PROCESS_STATUS.STATUS_DATE, PROCESS_STATUS.AUTO_APPV_YN
			 , SORTING
		  FROM MAIN 
			   LEFT OUTER JOIN 
			   PROCESS_STATUS
			ON MAIN.USERNAME = PROCESS_STATUS.OPERATOR_ID
		   AND MAIN.LV_CD = PROCESS_STATUS.AUTH_TYPE
		   AND PROCESS_STATUS.RW = 1
		ORDER BY SORTING	
	END

END
GO
