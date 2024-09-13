USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2010_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2010_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 단위 관리 수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-25  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2010_S1] (
	 @P_WORK_TYPE          NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
   , @P_ID				   NVARCHAR(100) = NULL
   , @P_ITEM_CD			   NVARCHAR(100) = NULL
   , @P_ACCOUNT_CD		   NVARCHAR(100) = NULL
   , @P_EMP_ID			   NVARCHAR(100) = NULL
   , @P_ACTV_YN            NVARCHAR(10)
   , @P_MANAGER_YN         NVARCHAR(10)
   , @P_USER_ID            NVARCHAR(100) 
   , @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
   , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
---------- PGM LOG START ----------
-- T3 Server와 동일하게 Log를 볼 수 있는 구문
-- 하단 SELECT 를 조회하면 해당 SP에 들어온 변수들을 확인할 수 있다.
-- 이후 EXEC SP 실행을 통해서 결과값을 확인할 수 있다.
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_CM2010_S1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_CM2010_S1 '75C68FC39AD44D029DC71DBC69569845','102550', '1100625-KR-1110','143614', 'N', 'N', '176093'
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_CM2010_S1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(1000), @P_WORK_TYPE), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(1000), @P_ID ), '')				  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_CD), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ACCOUNT_CD), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_EMP_ID),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ACTV_YN), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MANAGER_YN),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),  '')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------



DECLARE  
		  @v_ITEM_ID NVARCHAR(100)
		, @v_ACCOUNT_ID NVARCHAR(100)
		, @v_ID			NVARCHAR(32)
		, @v_EMP_NM		NVARCHAR(100)
		, @v_EMP_ID		NVARCHAR(100)
		, @P_ERR_STATUS INT = 0
        , @P_ERR_MSG NVARCHAR(4000)=''

		SELECT @v_EMP_NM = DISPLAY_NAME
		  FROM TB_AD_USER
		 WHERE USERNAME = @P_USER_ID;

		IF EXISTS (SELECT 1 FROM TB_AD_USER WHERE USERNAME = @P_EMP_ID)
			SELECT @v_EMP_ID = USERNAME FROM TB_AD_USER WHERE USERNAME = @P_EMP_ID;
		IF EXISTS (SELECT 1 FROM TB_AD_USER WHERE DISPLAY_NAME = @P_EMP_ID)
			SELECT @v_EMP_ID = USERNAME FROM TB_AD_USER WHERE DISPLAY_NAME = @P_EMP_ID;

		SELECT @v_ITEM_ID = ITEM_MST_ID
			 , @v_ACCOUNT_ID = ACCOUNT_ID
	 	  FROM TB_DP_USER_ITEM_ACCOUNT_MAP
		 WHERE ID = @P_ID

BEGIN TRY
	BEGIN
		IF @P_WORK_TYPE IN ('U')
			BEGIN
				SELECT @v_ITEM_ID = ITEM_MST_ID
					 , @v_ACCOUNT_ID = ACCOUNT_ID
				  FROM TB_DP_USER_ITEM_ACCOUNT_MAP
				 WHERE ID = @P_ID

				--IF EXISTS (SELECT 1 FROM TB_DP_USER_ITEM_ACCOUNT_MAP WHERE EMP_ID = @v_EMP_ID AND ITEM_MST_ID = @v_ITEM_ID AND ACCOUNT_ID = @v_ACCOUNT_ID AND ACTV_YN ='Y' AND @P_ACTV_YN = 'Y')
				IF EXISTS (SELECT 1 FROM TB_DP_USER_ITEM_ACCOUNT_MAP WHERE EMP_ID = @v_EMP_ID AND ITEM_MST_ID = @v_ITEM_ID AND ACCOUNT_ID = @v_ACCOUNT_ID AND ID != @P_ID)
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_008' 
						RAISERROR (@P_ERR_MSG,12, 1);
					END

					UPDATE TB_DP_USER_ITEM_ACCOUNT_MAP 
					   SET ACTV_YN = @P_ACTV_YN
						 , EMP_ID = @v_EMP_ID
						 , MODIFY_BY = @v_EMP_NM
						 , MODIFY_DTTM = GETDATE()
					 WHERE ID = @P_ID
				IF EXISTS (SELECT 1 FROM TB_DP_USER_ITEM_ACCOUNT_MAP 
							WHERE ITEM_MST_ID = @v_ITEM_ID AND ACCOUNT_ID = @v_ACCOUNT_ID AND ACTV_YN = 'Y'
							GROUP BY ITEM_MST_ID, ACCOUNT_ID
							HAVING COUNT(*) > 1)
					BEGIN
						  UPDATE TB_DP_USER_ITEM_ACCOUNT_MAP SET ACTV_YN = 'N' WHERE ID = @P_ID
						  SET @P_ERR_MSG = 'MSG_SKC_006' 
						  RAISERROR (@P_ERR_MSG,12, 1);						  
					END	
			END;

		IF @P_WORK_TYPE IN ('N')
			BEGIN
				SELECT @v_ITEM_ID = ID
				  FROM TB_CM_ITEM_MST 
				 WHERE ITEM_CD = @P_ITEM_CD;

				SELECT @v_ACCOUNT_ID = ID
				  FROM TB_DP_ACCOUNT_MST
				 WHERE ACCOUNT_CD = @P_ACCOUNT_CD;

				IF EXISTS (SELECT 1 FROM TB_CM_ITEM_MST WHERE ID = @v_ITEM_ID AND DP_PLAN_YN = 'N')
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_024'
						RAISERROR (@P_ERR_MSG, 12, 1);
					END;

				   SET @v_ID = REPLACE(NEWID(), '-', '')
				IF (@v_ITEM_ID IS NULL) OR (@v_ACCOUNT_ID IS NULL)
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_005' 
						RAISERROR (@P_ERR_MSG,12, 1);
					END
			
				IF EXISTS (SELECT 1 FROM TB_DP_USER_ITEM_ACCOUNT_MAP WHERE EMP_ID = @v_EMP_ID AND ITEM_MST_ID = @v_ITEM_ID AND ACCOUNT_ID = @v_ACCOUNT_ID)
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_008' 
						RAISERROR (@P_ERR_MSG,12, 1);
					END

				INSERT INTO TB_DP_USER_ITEM_ACCOUNT_MAP(ID, AUTH_TP_ID, EMP_ID, ACCOUNT_ID, ITEM_MST_ID, CREATE_BY, CREATE_DTTM, MODIFY_BY, MODIFY_DTTM, ACTV_YN)
					SELECT @v_ID AS ID
						, (SELECT ID FROM TB_CM_LEVEL_MGMT WHERE LV_CD = 'MARKETER') AS AUTH_TP_ID
						, @v_EMP_ID AS EMP_ID
						, @v_ACCOUNT_ID AS ACCOUNT_ID
						, @v_ITEM_ID AS ITEM_MST_ID
						, @v_EMP_NM AS CREATE_BY
						, GETDATE() AS CREATE_DTTM
						, @v_EMP_NM AS MODIFY_BY
						, GETDATE() AS MODIFY_DTTM 
						, @P_ACTV_YN AS ACTV_YN;
						--, @P_MANAGER_YN AS MANAGER_YN;

				IF EXISTS (SELECT 1 FROM TB_DP_USER_ITEM_ACCOUNT_MAP 
							WHERE ITEM_MST_ID = @v_ITEM_ID AND ACCOUNT_ID = @v_ACCOUNT_ID AND ACTV_YN = 'Y'
							GROUP BY ITEM_MST_ID, ACCOUNT_ID
							HAVING COUNT(*) > 1)
					BEGIN
						  DELETE FROM TB_DP_USER_ITEM_ACCOUNT_MAP WHERE ID = @v_ID
						  SET @P_ERR_MSG = 'MSG_SKC_006' 
						  RAISERROR (@P_ERR_MSG,12, 1);
					END				

			END;		 
		 
		 IF @P_WORK_TYPE IN ('D')
			BEGIN
				DELETE FROM TB_DP_USER_ITEM_ACCOUNT_MAP
				 WHERE ID = @P_ID;
			END;
			
	INSERT INTO TB_DP_DIMENSION_DATA (ID, ITEM_MST_ID, ACCOUNT_ID, CREATE_DTTM, CREATE_BY, PACK_UNIT)
		SELECT REPLACE(NEWID(), '-', '') AS ID
			 , A.ITEM_MST_ID
			 , A.ACCOUNT_ID 
			 , GETDATE()
			 , 'SCM System'
			 , CASE WHEN B.ITEM_CD = '100002' AND C.ATTR_04 = 'KR' THEN '23000'
					WHEN B.ITEM_CD = '100002' AND C.ATTR_04 = 'AM' THEN '19500'
					WHEN B.ITEM_CD = '100002' AND C.ATTR_04 = 'EU' THEN '22000'
					WHEN B.ITEM_CD = '100002' AND C.ATTR_04 = 'CN' THEN '23000' 
					ELSE B.ATTR_01 END AS PACK_UNIT
		  FROM TB_DP_USER_ITEM_ACCOUNT_MAP A
		 INNER JOIN TB_CM_ITEM_MST B 
			ON A.ITEM_MST_ID = B.ID	   
		 INNER JOIN TB_DP_ACCOUNT_MST C 
		    ON A.ACCOUNT_ID = C.ID
		WHERE NOT EXISTS (SELECT 1 FROM TB_DP_DIMENSION_DATA B WHERE A.ITEM_MST_ID = B.ITEM_MST_ID AND A.ACCOUNT_ID = B.ACCOUNT_ID)
		  AND A.ACTV_YN = 'Y';

		MERGE INTO TB_DP_DIMENSION_DATA A USING (
			SELECT ITEM_MST_ID
				 , ACCOUNT_ID
				 , EMP_ID
				 , B.DISPLAY_NAME AS EMP_NM 
		      FROM TB_DP_USER_ITEM_ACCOUNT_MAP A 
			 INNER JOIN TB_AD_USER B 
			    ON UPPER(A.EMP_ID) = UPPER(B.USERNAME) 
			 WHERE ACTV_YN = 'Y'
		) B ON (A.ITEM_MST_ID = B.ITEM_MST_ID AND A.ACCOUNT_ID = B.ACCOUNT_ID)
		WHEN MATCHED THEN UPDATE SET A.EMP_NM = B.EMP_NM;

	INSERT INTO TB_DP_MEASURE_DATA (ID, ITEM_MST_ID, ACCOUNT_ID, BASE_DATE, CREATE_BY, CREATE_DTTM)
		SELECT REPLACE(NEWID(), '-', '') AS ID
			 , ITEM_MST_ID
			 , ACCOUNT_ID
			 , BASE_DATE
			 , 'SCM System'
			 , GETDATE()
		  FROM (SELECT DISTINCT ITEM_MST_ID, ACCOUNT_ID 
				  FROM TB_DP_USER_ITEM_ACCOUNT_MAP
				 WHERE ACTV_YN = 'Y') A
		 CROSS JOIN (SELECT DISTINCT BASE_DATE from TB_DP_MEASURE_DATA) B
		 WHERE NOT EXISTS (SELECT 1 FROM TB_DP_MEASURE_DATA C WHERE A.ITEM_MST_ID = C.ITEM_MST_ID AND A.ACCOUNT_ID = C.ACCOUNT_ID)	  

/****************************************************************************************************************************
		-- Add new Demand into Entry 
	  ***************************************************************************************************************************/	   
	/************************************************************************************************************************************
		1. close 되지 않은 버전 이면서 TB_DP_ENTRY에 data가 존재하는 버전 : 엔진을 사용한다면 entry에 데이타가 없으므로

		2. TB_DP_ENTRY 에 이미 해당 item-account가 있는 경우 무시 
		     - 삭제되었다가 다시 추가되는 상황인 경우 이럴 수 있음
		3. Plan type별로 version이 있을수 있음 : 여러개일 가능성 있음 
				SELECT  CONBD_VER_MST_ID as VER_ID, max(create_dttm) OVER (PARTITION BY PLAN_TP_ID ORDER BY create_dttm DESC)  
				FROM TB_DP_CONTROL_BOARD_VER_DTL 
				WHERE WORK_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_WK_TP' AND CONF_CD = 'CL')
						AND CL_STATUS_ID IN (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_STATUS' AND CONF_CD != 'CLOSE')

		4. plan type 별로 해당 version의 auth type을 구함
				select  LV_MGMT_ID from TB_DP_CONTROL_BOARD_VER_DTL where CONBD_VER_MST_ID  = 'F4F716D3FBDD4252BDDC28B9575BD690' and LV_MGMT_ID is not null
		5. 각 auth type별로 초기값 반영은 2차로 진행해도 될듯... 일단 value가 0인 상태로 demand만 추가 되도록 필요
	************************************************************************************************************************************/
	/********************************************************************************************************************************************
		-- Make Entry data
	********************************************************************************************************************************************/
	-- USER_ITEM_MAP , USER_ACCOUNT_MAP 의 ACTV값도 체크해야..=> @p_ACTV_YN값 'N'이면 체크해서 UPDATE
	IF @P_WORK_TYPE IN ('N' , 'U') 
		BEGIN 
			DECLARE @P_EXIST_CHECK INT = 0;

			 SELECT @P_EXIST_CHECK = COUNT(1)
			   FROM [TB_DP_USER_ITEM_ACCOUNT_MAP]
			  WHERE ITEM_MST_ID = @v_ITEM_ID
				AND ACCOUNT_ID = @v_ACCOUNT_ID
				AND ACTV_YN = 'Y'
				;
			SELECT @P_EXIST_CHECK = @P_EXIST_CHECK + COUNT(1)
			  FROM (
			SELECT 1 AS CNT 
			  FROM TB_DP_USER_ITEM_MAP I 
				   INNER JOIN 
				   TB_CM_LEVEL_MGMT IL
				ON I.LV_MGMT_ID = IL.ID 
				   INNER JOIN 
				   TB_DP_USER_ACCOUNT_MAP A
				ON I.AUTH_TP_ID = A.AUTH_TP_ID
				   INNER JOIN 
				   TB_CM_LEVEL_MGMT AL
				ON A.LV_MGMT_ID = AL.ID 
			   AND I.EMP_ID = A.EMP_ID 
				   INNER JOIN 
				   TB_DPD_ITEM_HIER_CLOSURE IH
				ON CASE WHEN IL.LEAF_YN = 'Y' THEN I.ITEM_MST_ID ELSE I.ITEM_LV_ID END = IH.ANCESTER_ID
			   AND IH.LEAF_YN = 'Y'
			   AND IH.LV_TP_CD = 'I'
				   INNER JOIN 
				   TB_DPD_SALES_HIER_CLOSURE SH			
				ON CASE WHEN AL.LEAF_YN = 'Y' THEN A.ACCOUNT_ID ELSE A.SALES_LV_ID END = SH.ANCESTER_ID
			   AND SH.LEAF_YN = 'Y'
			   AND SH.LV_TP_CD = 'S'
			 WHERE I.ACTV_YN = 'Y'  
			   AND A.ACTV_YN = 'Y'
			   AND IH.DESCENDANT_ID = @v_ITEM_ID		
			   AND SH.DESCENDANT_ID = @v_ACCOUNT_ID
			   EXCEPT  
			   SELECT 1 
				 FROM TB_DP_USER_ITEM_ACCOUNT_EXCLUD
				WHERE ITEM_MST_ID = @v_ITEM_ID
				  AND ACCOUNT_ID = @v_ACCOUNT_ID
				  ) A
			   ;
			   IF(@P_EXIST_CHECK > 0)
			   BEGIN
				SET @P_ACTV_YN = 'Y'
			   END ; 

		   DECLARE @TB_VERSION TABLE  (ID CHAR(32))
		   INSERT INTO @TB_VERSION
		   SELECT M.ID 
			 FROM TB_DP_CONTROL_BOARD_VER_MST M
				  INNER JOIN 
				  TB_DP_CONTROL_BOARD_VER_DTL D 
			   ON M.ID = D.CONBD_VER_MST_ID
				  INNER JOIN
				  TB_CM_COMM_CONFIG W
			   ON D.WORK_TP_ID = W.ID 
			  AND W.CONF_CD = 'CL'
				  INNER JOIN 
				  TB_CM_COMM_CONFIG C
			   ON D.CL_STATUS_ID = C.ID 
			  AND C.CONF_CD = 'READY'

			IF ( SELECT COUNT(1)
				   FROM TB_DP_ENTRY 
				  WHERE VER_ID IN (SELECT ID FROM @TB_VERSION)
					AND ITEM_MST_ID = @v_ITEM_ID 
					AND ACCOUNT_ID = @v_ACCOUNT_ID 
				  ) > 0
				  BEGIN
						UPDATE TB_DP_ENTRY
						   SET ACTV_YN = @p_ACTV_YN
						 WHERE VER_ID IN (SELECT ID FROM @TB_VERSION)
						   AND ITEM_MST_ID = @v_ITEM_ID 
						   AND ACCOUNT_ID = @v_ACCOUNT_ID 
				  END
			ELSE 
				BEGIN
					WITH VER
					  AS (
							SELECT V.ID 
								 , E.BASE_DATE
								 , PLAN_TP_ID 
								 , AUTH_TP_ID 
							 FROM TB_DP_ENTRY E 
								  INNER JOIN 
								  @TB_VERSION V 
							   ON E.VER_ID = V.ID 
						 GROUP BY V.ID 
								, E.BASE_DATE
								, E.PLAN_TP_ID 
								 , AUTH_TP_ID 
						  )
					INSERT INTO TB_DP_ENTRY 
							( ID
							, VER_ID
							, AUTH_TP_ID
							, EMP_ID
							, ITEM_MST_ID
							, ACCOUNT_ID
						--	, SALES_LV_ID
							, BASE_DATE
							, QTY
							, AMT
							, CREATE_BY
							, CREATE_DTTM
							, PLAN_TP_ID
							, QTY_A	
							, QTY_S
							, AMT_S 
							, ACTV_YN 
							)  
					SELECT    REPLACE(NEWID(),'-','') 
							, V.ID
							, V.AUTH_TP_ID
							, @v_EMP_ID 
							, @v_ITEM_ID
							, @v_ACCOUNT_ID
							, V.BASE_DATE
							, 0
							, NULL 
							, @P_USER_ID
							, GETDATE()
							, V.PLAN_TP_ID 	 
							, 0 -- A
							, 0	-- S
							, NULL  	
							, @p_ACTV_YN
					   FROM VER V
				END 

			-- PARTWK 휴일만 있는 경우 ACTV_YN = 'N' 처리
			CREATE TABLE #CALENDAR
			(  STRT_DATE	DATE 
			 , END_DATE		DATE 
			 , BASE_DATE	DATE 
			)
			;	
			WITH VER_INFO
			AS (SELECT	 DISTINCT 
						 MIN(FROM_DATE) AS FROM_DATE 
						,MAX(TO_DATE) AS TO_DATE
						,BUKT	
				 FROM TB_DP_CONTROL_BOARD_VER_MST 
				WHERE ID IN (select id from @TB_VERSION)
				  AND PLAN_TP_ID = '4FFB97D63C36417D810450471B7D752D'
				GROUP BY BUKT
				) 
				INSERT INTO #CALENDAR (STRT_DATE, END_DATE, BASE_DATE) 
					SELECT MIN(DAT)	
						 , MAX(DAT) 
						 , MIN(DAT) 
					  FROM TB_CM_CALENDAR CAL
						   INNER JOIN
						   VER_INFO VER
						ON CAL.DAT BETWEEN VER.FROM_DATE AND VER.TO_DATE 
				  GROUP BY CASE VER.BUKT
							WHEN 'Y' THEN YYYY
							WHEN 'Q' THEN YYYY+'-'+CONVERT(CHAR(1), QTR)
							WHEN 'M' THEN YYYYMM
							WHEN 'PW' THEN MM+'-'+DP_WK
							WHEN 'W' THEN DP_WK
						  ELSE YYYYMMDD END  	
						 ;

				UPDATE TB_DP_ENTRY
				SET ACTV_YN = 'N'
				  , MODIFY_BY = 'SCM System'
				  , MODIFY_DTTM = GETDATE()
				WHERE VER_ID IN (select id from @TB_VERSION)
				AND BASE_DATE IN (
				SELECT STRT_DATE
						  FROM (SELECT STRT_DATE
									 , END_DATE
									 , PARTWK
									 , ISNULL(SUM(HOLID_YN), 0) AS SUM
									 , DIFF
								  FROM (SELECT A.*
											 , B.DAT
											 , PARTWK
											 , CASE WHEN HOLID_YN = 'Y' THEN 1 ELSE NULL END AS HOLID_YN
											 , ABS(DATEDIFF(DAY, A.END_DATE, A.STRT_DATE))+1 AS DIFF
										  FROM #CALENDAR A
										 INNER JOIN TB_CM_CALENDAR B
										    ON B.DAT BETWEEN A.STRT_DATE AND A.END_DATE) A
								 GROUP BY A.STRT_DATE, A.END_DATE, PARTWK, DIFF) A
						 WHERE SUM = DIFF)
						 AND ACTV_YN = 'Y'


		END;

	IF @P_WORK_TYPE = 'D'
	BEGIN
		DECLARE @P_EXIST_CHECK2		INT = 0;
		SELECT @P_EXIST_CHECK2 = COUNT(1)
		   FROM [TB_DP_USER_ITEM_ACCOUNT_MAP]
		  WHERE ITEM_MST_ID = @v_ITEM_ID 
		    AND ACCOUNT_ID = @v_ACCOUNT_ID
			AND ACTV_YN = 'Y'
		SELECT @P_EXIST_CHECK2 = @P_EXIST_CHECK2 + COUNT(1)
		  FROM TB_DP_USER_ITEM_MAP I 
			   INNER JOIN 
			   TB_CM_LEVEL_MGMT IL
			ON I.LV_MGMT_ID = IL.ID 
			   INNER JOIN 
			   TB_DP_USER_ACCOUNT_MAP A
			ON I.AUTH_TP_ID = A.AUTH_TP_ID
			   INNER JOIN 
			   TB_CM_LEVEL_MGMT AL
			ON A.LV_MGMT_ID = AL.ID 
		   AND I.EMP_ID = A.EMP_ID 
			   INNER JOIN 
			   TB_DPD_ITEM_HIER_CLOSURE IH
			ON CASE WHEN IL.LEAF_YN = 'Y' THEN I.ITEM_MST_ID ELSE I.ITEM_LV_ID END = IH.ANCESTER_ID
		   AND IH.LEAF_YN = 'Y'
		   AND IH.LV_TP_CD = 'I'
		       INNER JOIN 
			   TB_DPD_SALES_HIER_CLOSURE SH			
			ON CASE WHEN AL.LEAF_YN = 'Y' THEN A.ACCOUNT_ID ELSE A.SALES_LV_ID END = SH.ANCESTER_ID
		   AND SH.LEAF_YN = 'Y'
		   AND SH.LV_TP_CD = 'S'
		 WHERE I.ACTV_YN = 'Y'  
		   AND A.ACTV_YN = 'Y'
		   AND IH.DESCENDANT_ID = @v_ITEM_ID		
		   AND SH.DESCENDANT_ID = @v_ACCOUNT_ID
		   ;
		 IF @P_EXIST_CHECK2 = 0
			BEGIN
		WITH  VER
		  AS (
			   SELECT M.ID 
				 FROM TB_DP_CONTROL_BOARD_VER_MST M
					  INNER JOIN 
					  TB_DP_CONTROL_BOARD_VER_DTL D 
				   ON M.ID = D.CONBD_VER_MST_ID
					  INNER JOIN
					  TB_CM_COMM_CONFIG W
				   ON D.WORK_TP_ID = W.ID 
				  AND W.CONF_CD = 'CL'
					  INNER JOIN 
					  TB_CM_COMM_CONFIG C
				   ON D.CL_STATUS_ID = C.ID 
				  AND C.CONF_CD = 'READY'
			)
		UPDATE TB_DP_ENTRY 
		  SET ACTV_YN = 'N'
		WHERE TB_DP_ENTRY.ITEM_MST_ID  = @v_ITEM_ID 
		  AND TB_DP_ENTRY.ACCOUNT_ID   = @v_ACCOUNT_ID 
		  AND VER_ID IN ( SELECT ID FROM VER )
		  ;
		  END 
	END;


	--MERGE INTO TB_DP_DIMENSION_DATA A USING (
	--	SELECT REPLACE(NEWID(), '-', '') AS ID
	--		 , A.ITEM_MST_ID
	--		 , A.ACCOUNT_ID
	--		 , C.SALES_LV_CD AS TEAM_CD
	--		 , C.SALES_LV_NM AS TEAM_NM
	--		 , A.EMP_ID
	--		 , D.EMP_NM
	--	  FROM TB_DP_USER_ITEM_ACCOUNT_MAP A
	--	 INNER JOIN TB_DP_ACCOUNT_MST B 
	--		ON A.ACCOUNT_ID = B.ID
	--	 INNER JOIN TB_DP_SALES_LEVEL_MGMT C
	--		ON B.PARENT_SALES_LV_ID = C.ID
	--	 INNER JOIN (SELECT DISTINCT EMP_NO, EMP_NM FROM TB_DP_EMPLOYEE) D
	--		ON A.EMP_ID = D.EMP_NO
	--	 WHERE A.MANAGER_YN = 'Y')
	--	B ON (A.ITEM_MST_ID = B.ITEM_MST_ID AND A.ACCOUNT_ID = B.ACCOUNT_ID)
	--	WHEN MATCHED THEN
	--		UPDATE SET A.TEAM_CD = B.TEAM_CD, A.TEAM_NM = B.TEAM_NM,
	--				   A.EMP_ID = B.EMP_ID, A.EMP_NM = B.EMP_NM, 
	--				   A.MODIFY_DTTM = GETDATE(), A.MODIFY_BY = 'SYSTEM'
	--	WHEN NOT MATCHED THEN
	--		INSERT (ID, ITEM_MST_ID, ACCOUNT_ID, TEAM_CD, TEAM_NM, EMP_ID, EMP_NM, CREATE_DTTM, CREATE_BY) 
	--		VALUES (B.ID, B.ITEM_MST_ID, B.ACCOUNT_ID, B.TEAM_CD, B.TEAM_NM, B.EMP_ID, B.EMP_NM, GETDATE(), 'SYSTEM');

	EXEC SP_UI_DPD_MAKE_HIER_USER;	

    -----------------------------------
    -- 저장메시지
    -----------------------------------
    IF  @@TRANCOUNT > 0 COMMIT TRANSACTION
        SET @P_RT_ROLLBACK_FLAG = 'TRUE';
        SET @P_RT_MSG           = 'MSG_0001';  --저장되었습니다.
	END

    END TRY

    BEGIN CATCH
        IF (ERROR_MESSAGE() LIKE 'MSG_%')
			BEGIN
			  SET @P_ERR_MSG          = ERROR_MESSAGE()
			  SET @P_RT_ROLLBACK_FLAG = 'FALSE'
			  SET @P_RT_MSG           = @P_ERR_MSG
			END
        ELSE
		    THROW;
    END CATCH


GO
