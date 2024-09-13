USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP1020_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP1020_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 대비 RTF 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-19  YJS            신규 생성
-- 2024-06-26  YJS			  수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP1020_Q1] (
	 @P_VER_CD			    NVARCHAR(30)
   , @P_CORP_CD             NVARCHAR(30)    = 'ALL'    -- 법인
   , @P_EMP_CD              NVARCHAR(30)    = 'ALL'    -- 담당자 CODE
   , @p_ITEM_FILTER		    NVARCHAR(MAX)   = '[]'
   , @p_ACCOUNT_FILTER      NVARCHAR(MAX)   = '[]'
   , @p_LANG_CD				NVARCHAR(10)	= 'ko'
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
BEGIN
	
---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP1020_Q1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP1020_Q1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_CD), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_EMP_CD ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ITEM_FILTER ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(MAX), @p_ACCOUNT_FILTER ), '')					   				   			  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @p_LANG_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID),  '')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

	DECLARE @P_VER_ID	NVARCHAR(32);
	DECLARE @P_FROM_DATE DATE;
	DECLARE @P_TO_DATE DATE;
	DECLARE @P_VAR_DATE DATE;
	DECLARE @P_PREV_VER_ID NVARCHAR(32);
	DECLARE @P_PREV_FROM_DATE DATE;
	DECLARE @P_PREV_TO_DATE DATE;
	DECLARE @P_TEAM_CD		NVARCHAR(30);

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

	SET @P_VER_ID = (SELECT ID FROM TB_DP_CONTROL_BOARD_VER_MST WHERE VER_ID = @P_VER_CD);
	--SET @P_VER_ID = (SELECT TOP 1 ID
	--				   FROM TB_DP_CONTROL_BOARD_VER_MST
	--				  WHERE ID IN (SELECT CONBD_VER_MST_ID 
	--								 FROM TB_DP_CONTROL_BOARD_VER_DTL 
	--							    WHERE CL_STATUS_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_STATUS' AND CONF_CD = 'CLOSE' AND ACTV_YN   = 'Y'))
	--					AND VER_TP_CD = 'M'
	--				  ORDER BY CREATE_DTTM DESC);
	--SET @P_PREV_VER_ID = (SELECT TOP 1 ID
	--					    FROM TB_DP_CONTROL_BOARD_VER_MST
	--					   WHERE ID IN (SELECT CONBD_VER_MST_ID 
	--						 			  FROM TB_DP_CONTROL_BOARD_VER_DTL 
	--					 				 WHERE CL_STATUS_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_STATUS' AND CONF_CD = 'CLOSE' AND ACTV_YN   = 'Y'))
	--						 AND ID != @P_VER_ID
	--						 AND VER_TP_CD = 'M'
	--						 AND VER_ID < @P_VER_CD
	--						 AND VER_ID != 'DP-202405-03-M'
	--						 AND COPIED_VER_ID IS NULL
	--					   ORDER BY CREATE_DTTM DESC);

	SET @P_PREV_VER_ID = (SELECT  TOP 1 C.ID
						    FROM  TB_CM_CONBD_MAIN_VER_DTL A
						   INNER  JOIN TB_CM_CONBD_MAIN_VER_MST B
						  	  ON  A.CONBD_MAIN_VER_MST_ID = B.ID
						   INNER  JOIN TB_DP_CONTROL_BOARD_VER_MST C
						  	  ON  B.DMND_VER_ID = C.VER_ID
						   WHERE  A.CONFRM_YN   = 'Y'  
						     AND  B.DMND_VER_ID < @P_VER_CD
						   ORDER  BY A.CREATE_DTTM DESC)

	SET @P_TEAM_CD = (SELECT SALES_LV_CD
						FROM TB_DP_SALES_LEVEL_MGMT
					   WHERE ID = (SELECT SALES_LV_ID 
									 FROM TB_DP_SALES_AUTH_MAP 
									WHERE EMP_ID = (SELECT ID FROM TB_AD_USER WHERE USERNAME = @P_EMP_CD)
								  )
					 );

	SELECT @P_PREV_FROM_DATE = FROM_DATE
		 , @P_PREV_TO_DATE   = DATEADD(DD, -1, DATEADD(MM, 1, FROM_DATE)) 
	  FROM TB_DP_CONTROL_BOARD_VER_MST 
	 WHERE ID = @P_PREV_VER_ID;

	SELECT @P_FROM_DATE = FROM_DATE
		 --, @P_TO_DATE   = TO_DATE 
		 , @P_VAR_DATE  = VER_S_HORIZON_DATE
	  FROM TB_DP_CONTROL_BOARD_VER_MST 
	 WHERE ID = @P_VER_ID;

	SELECT  @P_TO_DATE = TO_DT -- 2024.09.09 FP 구간의 종료지점
	  FROM  VW_FP_PLAN_VERSION A
	 WHERE  CNFM_YN = 'Y'
	   AND  PLAN_SCOPE = 'FP-COPOLY'   
	   AND  A.DMND_VER_ID = @P_VER_CD

	IF @P_CORP_CD = 'ALL' SET @P_CORP_CD = '';	

	DECLARE @TMP_EMP TABLE (EMP_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT);
	INSERT INTO @TMP_EMP
	SELECT DISTINCT DESC_ID AS EMP_ID 
	  FROM TB_DPD_USER_HIER_CLOSURE
	 WHERE ANCS_CD = @P_EMP_CD
	   AND DESC_ROLE_CD = 'MARKETER'
	 UNION ALL
	SELECT CASE WHEN @P_TEAM_CD = 'A101' THEN '175714'
				WHEN @P_TEAM_CD = 'B101' THEN '175715' END; -- A199, B199 DP 조회를 위한 수정
 

	IF OBJECT_ID('tempdb..#TM_IA') IS NOT NULL DROP TABLE #TM_IA -- 임시테이블 삭제
	SELECT DISTINCT A.ACCOUNT_ID AS ACCT_ID 
		 , TA.ACCOUNT_CD		 AS ACCT_CD
		 , A.ITEM_MST_ID		 AS ITEM_ID 
		 , TI.ITEM_CD			 AS ITEM_CD
	  INTO #TM_IA
	  FROM TB_DP_USER_ITEM_ACCOUNT_MAP A 
	 INNER JOIN @TMP_EMP B 
		ON A.EMP_ID = B.EMP_ID 
	 INNER JOIN @TMP_ITEM TI
		ON A.ITEM_MST_ID = TI.ITEM_ID
	 INNER JOIN @TMP_ACCOUNT TA
		ON A.ACCOUNT_ID = TA.ACCOUNT_ID
	 INNER JOIN TB_DP_ACCOUNT_MST D
	    ON TA.ACCOUNT_ID = D.ID
	 WHERE A.ACTV_YN = 'Y'
	   AND D.ATTR_05 LIKE CASE WHEN @P_TEAM_CD = 'A101' THEN 'A%'
						       WHEN @P_TEAM_CD = 'B101' THEN 'B%'
							   ELSE '%' END
	   ;

	--IF OBJECT_ID('tempdb..#TM_IA') IS NOT NULL DROP TABLE #TM_IA -- 임시테이블 삭제
	--	SELECT  DISTINCT A.ACCOUNT_ID AS ACCT_ID 
	--		 ,  A.ACCOUNT_CD		  AS ACCT_CD
	--		 ,  A.ITEM_MST_ID		  AS ITEM_ID 
	--		 ,  A.ITEM_CD			  AS ITEM_CD
	--	  INTO  #TM_IA
	--	  FROM  (SELECT  DISTINCT 
	--		 			 DE.ITEM_MST_ID
	--				  ,  TI.ITEM_CD
	--		 		  ,  DE.ACCOUNT_ID
	--				  ,  TA.ACCOUNT_CD
	--		 		  ,  DE.EMP_ID
	--			   FROM  TB_DP_ENTRY DE
	--			  INNER  JOIN @TMP_EMP TE
	--			     ON  DE.EMP_ID = TE.EMP_ID
	--			  INNER  JOIN @TMP_ITEM TI
	--				 ON  DE.ITEM_MST_ID = TI.ITEM_ID
	--			  INNER  JOIN @TMP_ACCOUNT TA
	--				 ON  DE.ACCOUNT_ID = TA.ACCOUNT_ID
	--			  WHERE  VER_ID  = @P_VER_ID
	--				AND  ACTV_YN = 'Y'
	--				AND  BASE_DATE = @P_FROM_DATE
	--			  UNION   
	--			 SELECT  DISTINCT 
	--		 			 DE.ITEM_MST_ID
	--				  ,  TI.ITEM_CD
	--		 		  ,  DE.ACCOUNT_ID
	--				  ,  TA.ACCOUNT_CD
	--		 		  ,  DE.EMP_ID
	--			   FROM  TB_DP_ENTRY DE
	--			  INNER  JOIN @TMP_EMP TE
	--			     ON  DE.EMP_ID = TE.EMP_ID
	--			  INNER  JOIN @TMP_ITEM TI
	--				 ON  DE.ITEM_MST_ID = TI.ITEM_ID
	--			  INNER  JOIN @TMP_ACCOUNT TA
	--				 ON  DE.ACCOUNT_ID = TA.ACCOUNT_ID
	--			  WHERE  VER_ID  = @P_PREV_VER_ID
	--				AND  ACTV_YN = 'Y'
	--				AND  BASE_DATE = @P_PREV_FROM_DATE) A 
	--	 INNER  JOIN TB_DP_ACCOUNT_MST D
	--		ON  A.ACCOUNT_ID = D.ID
	--	 WHERE  D.ATTR_05 LIKE CASE WHEN @P_TEAM_CD = 'A101' THEN 'A%'
	--								WHEN @P_TEAM_CD = 'B101' THEN 'B%'
	--								ELSE '%' END
	--	   ;

	IF OBJECT_ID('tempdb..#TM_ENTRY') IS NOT NULL DROP TABLE #TM_ENTRY
		SELECT  ITEM_MST_ID
			 ,  ACCOUNT_ID
			 ,  BASE_DATE
			 ,  QTY
			 ,  QTY_R
		  INTO  #TM_ENTRY
		  FROM  (SELECT  ITEM_MST_ID
					  ,  ACCOUNT_ID
					  ,  BASE_DATE
					  ,  QTY
					  ,  QTY_R		  
				   FROM  TB_DP_ENTRY DE WITH (INDEX(IDX_TB_DP_ENTRY_10)) 
				  INNER  JOIN #TM_IA IA
				     ON  DE.ITEM_MST_ID = IA.ITEM_ID
					AND  DE.ACCOUNT_ID  = IA.ACCT_ID
				  WHERE  VER_ID = @P_PREV_VER_ID
				    AND  BASE_DATE BETWEEN @P_PREV_FROM_DATE AND @P_PREV_TO_DATE
				    AND  ACTV_YN = 'Y'
				  UNION  ALL
				 SELECT  ITEM_MST_ID
					  ,  ACCOUNT_ID
					  ,  BASE_DATE
					  ,  QTY
					  ,  QTY_R		  
				   FROM  TB_DP_ENTRY DE WITH (INDEX(IDX_TB_DP_ENTRY_10)) 
				  INNER  JOIN #TM_IA IA
				     ON  DE.ITEM_MST_ID = IA.ITEM_ID
					AND  DE.ACCOUNT_ID  = IA.ACCT_ID
				  WHERE  VER_ID = @P_VER_ID
				    AND  BASE_DATE BETWEEN @P_FROM_DATE AND @P_TO_DATE
				    AND  ACTV_YN = 'Y') A;
				   
		    

	IF OBJECT_ID('tempdb..#TB_PLAN') IS NOT NULL DROP TABLE #TB_PLAN 
		SELECT  CORP_CD,    CORP_NM,	EMP_CD,		EMP_NM, 
			    ACCOUNT_CD, ACCOUNT_NM, REGION,		PLNT_CD, 
				PLNT_NM,    ITEM_CD,	ITEM_NM,    GRADE_NM,	
				PACK_UNIT,  DT_TYPE,    REP_DT,		REP_DT_DESC,
				YYYY,		YYYYMM,     PLAN_DT,	DAT,				
				MEASURE_CD, MEASURE_NM, 
			    CONVERT(NUMERIC(18, 0), 0) AS QTY,
			    CONVERT(NUMERIC(18, 0), 0) AS QTY_R,
			    CONVERT(NUMERIC(18, 0), 0) AS SHIP_QTY,
			    CONVERT(NUMERIC(18, 0), 0) AS QTY_GAP1
			    --CONVERT(NUMERIC(18, 0), 0) AS QTY_GAP2  -- 2024.09.03 S&OP 출하 실적은 직전 1개월만 존재하므로 메져 제거
		  INTO  #TB_PLAN
		  FROM  (
		SELECT  AM.ATTR_01 AS CORP_CD,     AM.ATTR_02 AS CORP_NM,  AU.USERNAME AS EMP_CD, DM.EMP_NM,
				AM.ATTR_03 AS ACCOUNT_CD,  AM.ACCOUNT_NM,		   AM.ATTR_04  AS REGION, 
				AM.ATTR_05 AS PLNT_CD,     AM.ATTR_06 AS PLNT_NM,
				IM.ITEM_CD,   IM.ITEM_NM,  IM.ATTR_11 AS GRADE_NM, DM.PACK_UNIT, 
				CAL.DT_TYPE,  CAL.REP_DT,  CAL.REP_DT_DESC,		   CAL.YYYY,
		        CAL.YYYYMM,   CAL.PLAN_DT, CAL.DAT,
				MES.MEASURE_CD,		  MES.MEASURE_NM			  
		  FROM  #TM_IA IA
		 INNER  JOIN TB_CM_ITEM_MST IM 
		    ON  IA.ITEM_ID = IM.ID
	     INNER  JOIN TB_DP_ACCOUNT_MST AM
			ON  IA.ACCT_ID = AM.ID
		 INNER  JOIN TB_DP_DIMENSION_DATA DM
		    ON  IA.ITEM_ID = DM.ITEM_MST_ID
		   AND  IA.ACCT_ID = DM.ACCOUNT_ID
		 INNER  JOIN TB_AD_USER AU
		    ON  DM.EMP_NM  = AU.DISPLAY_NAME
		 CROSS  APPLY (SELECT  'W'                                               AS DT_TYPE
							,  FORMAT(MAX(C.DAT),'yy-MM-dd')                     AS REP_DT
							,  CONCAT('W',SUBSTRING(C.PARTWK, 5, LEN(C.PARTWK))) AS REP_DT_DESC
  							,  C.YYYY                                            AS YYYY
							,  C.YYYYMM                                          AS YYYYMM
							,  C.PARTWK                                          AS PLAN_DT
							,  MIN(C.DAT)                                        AS DAT
					     FROM  TB_CM_CALENDAR C WITH (NOLOCK)
					    WHERE  1 = 1
						  AND  C.DAT_ID >= @P_PREV_FROM_DATE
						  AND  C.DAT_ID <  @P_VAR_DATE
					    GROUP  BY C.YYYYMM, C.PARTWK, C.YYYY
					    UNION  ALL
					   SELECT  'M'                                               AS DT_TYPE
							,  CONCAT(C.YYYY, N'년 ', RIGHT(C.YYYYMM, 2), N'월') AS REP_DT
							,  CONCAT(C.YYYY, N'년 ', RIGHT(C.YYYYMM, 2), N'월') AS REP_DT_DESC
  							,  C.YYYY                                            AS YYYY
							,  C.YYYYMM                                          AS YYYYMM
							,  C.YYYYMM                                          AS PLAN_DT
							,  MIN(C.DAT)                                        AS DAT
					     FROM  TB_CM_CALENDAR C WITH (NOLOCK)
					    WHERE  1 = 1
						  AND  C.DAT_ID >= @P_VAR_DATE
						  AND  C.DAT_ID <= @P_TO_DATE
					  GROUP BY C.MM, C.YYYYMM, C.YYYY) CAL
  	     CROSS  JOIN (SELECT CAST(COMN_CD AS INT) AS MEASURE_CD, COMN_CD_NM AS MEASURE_NM
						FROM FN_COMN_CODE ('DP1020', '')) MES
		 ) A;				

	MERGE INTO #TB_PLAN A USING (
		SELECT  MIN(DAT) AS DAT
			 ,  ITEM_CD AS ITEM_CD
			 ,  SALES_SITE_CD AS ACCOUNT_CD
			 ,  CASE WHEN SALES_GRP_CD = '136' THEN 'KR'
					 WHEN SALES_GRP_CD = '137' THEN 'AM'
					 WHEN SALES_GRP_CD = '138' THEN 'JP'
					 WHEN SALES_GRP_CD = '139' THEN 'CN'
					 WHEN SALES_GRP_CD = '140' THEN 'EU'
					 WHEN SALES_GRP_CD = '141' THEN 'AS'
					 WHEN SALES_GRP_CD = 'A11' THEN 'AM'
					 WHEN SALES_GRP_CD = 'B11' THEN 'EU'
					 WHEN SALES_GRP_CD = '123' THEN SALES_REGION_CD 
					 WHEN SALES_GRP_CD = '133' THEN SALES_REGION_CD END AS REGION
			 ,  PLNT_CD AS PLNT_CD
			 ,  SUM(TOTAL_QTY) AS SHIP_QTY
		  FROM  TB_SKC_CM_ACT_SHMT A
		 INNER  JOIN TB_CM_CALENDAR CAL
			ON  A.REAL_GI_DTTM = CAL.DAT
		 WHERE  CAL.DAT BETWEEN @P_PREV_FROM_DATE AND @P_TO_DATE
		 GROUP  BY ITEM_CD, SALES_SITE_CD, PLNT_CD,
				   CASE WHEN SALES_GRP_CD = '136' THEN 'KR'
						WHEN SALES_GRP_CD = '137' THEN 'AM'
						WHEN SALES_GRP_CD = '138' THEN 'JP'
						WHEN SALES_GRP_CD = '139' THEN 'CN'
						WHEN SALES_GRP_CD = '140' THEN 'EU'
						WHEN SALES_GRP_CD = '141' THEN 'AS'
						WHEN SALES_GRP_CD = 'A11' THEN 'AM'
						WHEN SALES_GRP_CD = 'B11' THEN 'EU'
						WHEN SALES_GRP_CD = '123' THEN SALES_REGION_CD 
						WHEN SALES_GRP_CD = '133' THEN SALES_REGION_CD END
	) B
	ON (A.DAT = B.DAT AND A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.REGION = B.REGION AND A.PLNT_CD = B.PLNT_CD)
	WHEN MATCHED THEN
	UPDATE SET A.SHIP_QTY = B.SHIP_QTY;
	
	MERGE INTO #TB_PLAN A USING (
		SELECT  IM.ITEM_CD               AS ITEM_CD
			 ,  AM.ATTR_03               AS ACCOUNT_CD
			 ,  AM.ATTR_04               AS REGION
			 ,  AM.ATTR_05               AS PLNT_CD
			 ,  BASE_DATE				 AS DAT
			 ,  QTY		                 AS QTY
			 ,  COALESCE(QTY_R, 0)	     AS QTY_R
			 ,  COALESCE(QTY_R, 0) - QTY AS QTY_GAP1
		  FROM  #TM_ENTRY DE
		 INNER  JOIN TB_CM_ITEM_MST IM
			ON  DE.ITEM_MST_ID = IM.ID	
		 INNER  JOIN TB_DP_ACCOUNT_MST AM
			ON  DE.ACCOUNT_ID = AM.ID		 
		 WHERE  DE.BASE_DATE >= @P_PREV_FROM_DATE 
		   AND  DE.BASE_DATE <  @P_PREV_TO_DATE
	) B	ON (A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.REGION = B.REGION AND A.PLNT_CD = B.PLNT_CD AND A.DAT = B.DAT)
	WHEN MATCHED THEN 
	UPDATE SET A.QTY = B.QTY, A.QTY_R = B.QTY_R, A.QTY_GAP1 = B.QTY_GAP1;

	MERGE INTO #TB_PLAN A USING (
	SELECT ITEM_CD
		 , ACCOUNT_CD
		 , REGION
		 , PLNT_CD
		 , DAT
		 , QTY
		 , QTY_R
		 , SUM(COALESCE(QTY_R, 0)) OVER(PARTITION BY ITEM_CD, ACCOUNT_CD, REGION, PLNT_CD ORDER BY DAT) - SUM(COALESCE(QTY, 0)) OVER(PARTITION BY ITEM_CD, ACCOUNT_CD, REGION, PLNT_CD ORDER BY DAT) AS QTY_GAP1
	  FROM (
		SELECT  IM.ITEM_CD               AS ITEM_CD
			 ,  AM.ATTR_03               AS ACCOUNT_CD
			 ,  AM.ATTR_04               AS REGION
			 ,  AM.ATTR_05               AS PLNT_CD
			 ,  BASE_DATE				 AS DAT
			 ,  QTY		                 AS QTY
			 ,  COALESCE(QTY_R, 0)	     AS QTY_R
		  FROM  #TM_ENTRY DE
		 INNER  JOIN TB_CM_ITEM_MST IM
			ON  DE.ITEM_MST_ID = IM.ID	
		 INNER  JOIN TB_DP_ACCOUNT_MST AM
			ON  DE.ACCOUNT_ID = AM.ID		 
		 WHERE  DE.BASE_DATE >= @P_FROM_DATE 
		   AND  DE.BASE_DATE <  @P_VAR_DATE
		 UNION  ALL
		SELECT  IM.ITEM_CD                                     AS ITEM_CD
			 ,  AM.ATTR_03                                     AS ACCOUNT_CD
			 ,  AM.ATTR_04                                     AS REGION
			 ,  AM.ATTR_05                                     AS PLNT_CD
			 ,  CAST(FORMAT(MIN(DAT),'yyyyMM') + '01' AS DATE) AS DAT
			 ,  SUM(QTY)									   AS QTY
			 ,  SUM(COALESCE(QTY_R, 0))						   AS QTY_R
		  FROM  #TM_ENTRY DE
		 INNER  JOIN TB_CM_ITEM_MST IM
			ON  DE.ITEM_MST_ID = IM.ID	
		 INNER  JOIN TB_DP_ACCOUNT_MST AM
			ON  DE.ACCOUNT_ID = AM.ID		 
		 INNER  JOIN TB_CM_CALENDAR CAL
		    ON  DE.BASE_DATE = CAL.DAT
		 WHERE  DE.BASE_DATE >= @P_VAR_DATE 
		   AND  DE.BASE_DATE <= @P_TO_DATE
		 GROUP  BY IM.ITEM_CD, AM.ATTR_03, AM.ATTR_04, AM.ATTR_05, YYYYMM) A
	) B	ON (A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.REGION = B.REGION AND A.PLNT_CD = B.PLNT_CD AND A.DAT = B.DAT)
	WHEN MATCHED THEN 
	UPDATE SET A.QTY = B.QTY, A.QTY_R = B.QTY_R, A.QTY_GAP1 = B.QTY_GAP1;	

	--UPDATE #TB_PLAN
	--   SET QTY_GAP2 = SHIP_QTY - QTY_R -- 2024.09.03 S&OP 출하 실적은 직전 1개월만 존재하므로 메져 제거

	INSERT INTO #TB_PLAN (
		CORP_CD,    CORP_NM,	EMP_CD,		 EMP_NM, 
		ACCOUNT_CD, ACCOUNT_NM, REGION,		 PLNT_CD, 
		PLNT_NM,    ITEM_CD,	ITEM_NM,     GRADE_NM,	
		PACK_UNIT,  MEASURE_CD, MEASURE_NM, 
		YYYYMM,		YYYY,
		DT_TYPE,	REP_DT,     REP_DT_DESC, PLAN_DT,
		QTY,		QTY_R,		SHIP_QTY,	 QTY_GAP1, DAT
		 )
	/*************************************************************************************
	  [주 단위 합산] 
	  01. 수요계획 
	  02. 판매계획
	  03. 출하실적
	  04. GAP(2-1)
	*************************************************************************************/
	SELECT  CORP_CD,    CORP_NM,	EMP_CD,		EMP_NM, 
			ACCOUNT_CD, ACCOUNT_NM, REGION,		PLNT_CD, 
			PLNT_NM,    ITEM_CD,	ITEM_NM,    GRADE_NM,	
			PACK_UNIT,  MEASURE_CD, MEASURE_NM 
		 ,  YYYYMM
		 ,  YYYY
		 ,  'S'                                               AS DT_TYPE
		 --,  CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 ,  CONCAT(RIGHT(YYYY, 2), '-', RIGHT(YYYYMM, 2), '-99') AS REP_DT
		 ,  N'Sum'                                            AS REP_DT_DESC		 
		 ,  '999999'                                          AS PLAN_DT	 
		 ,  SUM(ISNULL(A.QTY,0))							  AS QTY
		 ,  SUM(ISNULL(A.QTY_R,0))							  AS QTY_R
		 ,  SUM(ISNULL(A.SHIP_QTY,0))                         AS SHIP_QTY
		 --,  SUM(ISNULL(A.QTY_R,0))-SUM(ISNULL(A.QTY,0))		  AS QTY_GAP1
		 ,  SUM(SUM(ISNULL(A.QTY_R,0))) OVER (PARTITION BY A.ITEM_CD, A.ACCOUNT_CD, A.REGION, A.PLNT_CD, A.MEASURE_CD ORDER BY YYYYMM) - SUM(SUM(ISNULL(A.QTY,0))) OVER (PARTITION BY A.ITEM_CD, A.ACCOUNT_CD, A.REGION, A.PLNT_CD, A.MEASURE_CD ORDER BY YYYYMM) AS QTY_GAP1
		 ,  MIN(DAT)										  AS DAT
	  FROM  #TB_PLAN A
	 WHERE  1 = 1
	   AND  A.DT_TYPE    = 'W'
	   AND  A.MEASURE_CD IN ('01', '02', '03', '04')
	   AND  A.DAT <= @P_PREV_TO_DATE
	 GROUP  BY CORP_CD,    CORP_NM,	   EMP_CD,	EMP_NM, 
			   ACCOUNT_CD, ACCOUNT_NM, REGION,	PLNT_CD, 
			   PLNT_NM,    ITEM_CD,	   ITEM_NM,	GRADE_NM,	
			   PACK_UNIT,  YYYYMM,	   YYYY,      
			   MEASURE_CD, MEASURE_NM	
	UNION ALL 			   
	SELECT  CORP_CD,    CORP_NM,	EMP_CD,		EMP_NM, 
			ACCOUNT_CD, ACCOUNT_NM, REGION,		PLNT_CD, 
			PLNT_NM,    ITEM_CD,	ITEM_NM,    GRADE_NM,	
			PACK_UNIT,  MEASURE_CD, MEASURE_NM 
		 ,  YYYYMM
		 ,  YYYY
		 ,  'S'                                               AS DT_TYPE
		 --,  CONCAT(A.YYYY, N'년 ', RIGHT(A.YYYYMM, 2), N'월') AS REP_DT
		 ,  CONCAT(RIGHT(YYYY, 2), '-', RIGHT(YYYYMM, 2), '-99') AS REP_DT
		 ,  N'Sum'                                            AS REP_DT_DESC		 
		 ,  '999999'                                          AS PLAN_DT	 
		 ,  SUM(ISNULL(A.QTY,0))							  AS QTY
		 ,  SUM(ISNULL(A.QTY_R,0))							  AS QTY_R
		 ,  SUM(ISNULL(A.SHIP_QTY,0))                         AS SHIP_QTY
		 --,  SUM(ISNULL(A.QTY_R,0))-SUM(ISNULL(A.QTY,0))		  AS QTY_GAP1
		 ,  SUM(SUM(ISNULL(A.QTY_R,0))) OVER (PARTITION BY A.ITEM_CD, A.ACCOUNT_CD, A.REGION, A.PLNT_CD, A.MEASURE_CD ORDER BY YYYYMM) - SUM(SUM(ISNULL(A.QTY,0))) OVER (PARTITION BY A.ITEM_CD, A.ACCOUNT_CD, A.REGION, A.PLNT_CD, A.MEASURE_CD ORDER BY YYYYMM) AS QTY_GAP1
		 ,  MIN(DAT)										  AS DAT
	  FROM  #TB_PLAN A
	 WHERE  1 = 1
	   AND  A.DT_TYPE    = 'W'
	   AND  A.MEASURE_CD IN ('01', '02', '03', '04')
	   AND  A.DAT >= @P_PREV_TO_DATE
	 GROUP  BY CORP_CD,    CORP_NM,	   EMP_CD,	EMP_NM, 
			   ACCOUNT_CD, ACCOUNT_NM, REGION,	PLNT_CD, 
			   PLNT_NM,    ITEM_CD,	   ITEM_NM,	GRADE_NM,	
			   PACK_UNIT,  YYYYMM,	   YYYY,      
			   MEASURE_CD, MEASURE_NM	
	 UNION  ALL
	SELECT  CORP_CD,    CORP_NM,	EMP_CD,		EMP_NM, 
			ACCOUNT_CD, ACCOUNT_NM, REGION,		PLNT_CD, 
			PLNT_NM,    ITEM_CD,	ITEM_NM,    GRADE_NM,	
			PACK_UNIT,  MEASURE_CD, MEASURE_NM 
		 , '999999' AS YYYYMM
		 , '999999' AS YYYY
		 ,  'T'                                               AS DT_TYPE
		 ,  N'Total'										  AS REP_DT
		 ,  N'Total'                                          AS REP_DT_DESC		 
		 ,  '999999'                                          AS PLAN_DT	 
		 ,  SUM(ISNULL(A.QTY,0))							  AS QTY
		 ,  SUM(ISNULL(A.QTY_R,0))							  AS QTY_R
		 ,  SUM(ISNULL(A.SHIP_QTY,0))                         AS SHIP_QTY
		 ,  SUM(ISNULL(A.QTY_R,0))-SUM(ISNULL(A.QTY,0))		  AS QTY_GAP1
		 ,  MIN(DAT)										  AS DAT
	  FROM  #TB_PLAN A
	 WHERE  1 = 1
	   AND  A.MEASURE_CD IN ('01', '02', '03', '04')
	   AND  DAT >= @P_FROM_DATE
	 GROUP  BY CORP_CD,    CORP_NM,	   EMP_CD,	  EMP_NM, 
			   ACCOUNT_CD, ACCOUNT_NM, REGION,	  PLNT_CD, 
			   PLNT_NM,    ITEM_CD,	   ITEM_NM,	  GRADE_NM,	
			   PACK_UNIT,  MEASURE_CD, MEASURE_NM


	-- 조회
	SELECT  CORP_CD
		 ,  CORP_NM
		 ,  EMP_NM
		 ,  ACCOUNT_CD
		 ,  ACCOUNT_NM
		 ,  REGION
		 ,  ITEM_CD
		 ,  CONCAT(ITEM_CD , ' - ', ITEM_NM) AS ITEM_NM
		 ,  GRADE_NM
		 ,  PACK_UNIT
		 ,  PLNT_NM
		 ,  DT_TYPE
		 ,  REP_DT
		 ,  REP_DT_DESC
		 ,  YYYY
		 ,  YYYYMM
		 ,  PLAN_DT AS "DATE"
		 --,  CONVERT(VARCHAR(8), DAT, 112)AS "DATE" 			 
		 ,  MEASURE_CD
		 ,  MEASURE_NM AS MEASURE
		 ,  CASE WHEN MEASURE_CD = '01' THEN QTY
		 	     WHEN MEASURE_CD = '02' THEN QTY_R
		 	     WHEN MEASURE_CD = '03' THEN SHIP_QTY
		 	     WHEN MEASURE_CD = '04' THEN QTY_GAP1 END AS QTY
		 	     -- WHEN MEASURE_CD = '05' THEN QTY_GAP2 END AS QTY -- 2024.09.03 S&OP 출하 실적은 직전 1개월만 존재하므로 메져 제거
	 FROM  #TB_PLAN 
	ORDER  BY EMP_NM, ACCOUNT_CD, ITEM_CD, PLNT_NM, YYYY, YYYYMM, PLAN_DT, MEASURE_CD;

END;
GO
