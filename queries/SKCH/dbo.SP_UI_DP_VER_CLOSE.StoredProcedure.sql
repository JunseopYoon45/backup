USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_UI_DP_VER_CLOSE]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_UI_DP_VER_CLOSE] 
(
			@P_VER_CD				NVARCHAR(50) --= (sELECT TOP 1 VER_ID FROM TB_DP_CONTROL_BOARD_VER_MST ORDER BY CREATE_DTTM DESC )
		 ,  @p_CUTOFF_VER_CD		NVARCHAR(50)  = ''
		 ,  @P_USER_ID				NVARCHAR(255)
		 ,  @P_CL_LV_MGMT_ID		char(32)     -- DB16CB26720A4723A8B0E1C2AA23F848
		 ,  @P_CL_MODULE_TP			NVARCHAR(50) -- SCP_FCST
		 ,  @P_DP_CL_STATUS         NVARCHAR(50) -- CLOSE/ CUTOFF

) AS
/*************************************************************************************************
	[SP_UI_DP_VER_CLOSE]

	History ( Date / Writer / Comment)
	- 2021.01.21 / kim sohee / make annual data when closing yearly plan 
							/ change a method to get entry data ( simplify : insert into temp table)
	- 2021.01.27 / kim sohee / temp table COLLATE DATABASE_DEFAULT 
	- 2021.02.10 / kim sohee / RTS & EOS 
	- 2022.01.18 / kim sohee / ver_id desc => create_dttm desc (yearly plan type code)
	- 2022.11.11 / Kim sohee / close status check 
	- 2022.11.14 / kim sohee / add a case : version info = null 
	- 2023.01.30 / kim sohee / modify check 
	- 2023.02.16 / kim sohee / Open version delete
	- 2023.04.10 / kim sohee / rename procedure
	- 2023.04.24 / kim sohee / rts & eos, TB_CM_ITEM_MST => TB_DPD_ITEM_HIERACHY2
	- 2023.05.02 / kim sohee / amount update , version ID param add
	- 2023.05.12 / kim sohee / when CLOSE, update MODIFY_DTTM 
	- 2023.06.02 / kim sohee / add QTY_I, QTY_R, QTY_S, QTY_SR
	- 2023.06.13 / kim sohee / add demand type SCP2, SCP3 
	- 2023.06.20 / kim sohee / add P_DMND_CNT for Demand ID unique
	- 2023.08.04 / kim sohee / close type code : SO_FCST, FCST, SO, SO_FCST_NETTING 
							 / Change sales table : ENTRY, QTY_S => TB_DP_MEASURE_DATA, ACT_SALES_QTY
	- 2023.09.13 / hanguls   / code chnage : DM=>SO  SCP_SO_FCST, SCP_FCST, SCP_SO, SCP_SO_FCST_NETTING  
	- 2024.01.09 / KIM SOHEE / measure PRC1, PRC2 설정되어 있으면 AMT_P1 = PRC1 * QTY, AMT_P2 = PRC2 * QTY
	- 2024.01.19 / hanguls / demand overview save AMT=> AMT or AMT_P1	
	- 2024.01.26 / lee jungsub / REQUEST_SITE_ID add
	- 2024.01.26 / kim sohee /TB_DP_ENTRY_HISTORY add PRC1, PRC2, AMT_P1 ...
	- 2024.02.15 / kim sohee /temp table add columns PRC1, PRC2 
	- 2024.02.20 / kim sohee / actual sales null value => 0
	- 2024.03.06 / hanguls / MP deamnd overview 컬럼 정리 반영   	
	- 2024.03.07 / sungyong / transmission 호출 제거   	
	- 2024.03.07 / hanguls  / currency type remove 
	- 2024.03.12 / kim sohee /AND CASE WHEN @P_CL_MODULE_TP = 'SCP_SO_FCST_NETTING' THEN QTY-COALESCE(MS.ACT_SALES_QTY,0)  ELSE QTY END	> 0 
************************************************************************************************/
SET NOCOUNT ON
BEGIN	
	SET @P_DP_CL_STATUS = REPLACE(@P_DP_CL_STATUS, 'TAB_','')

	DECLARE --@P_CL_STATUS_CNT		INT 
		 -- versrion param
		    @P_TO_DATE				DATE
		 ,  @P_FROM_DATE			DATE 
		 ,  @P_BUKT					NVARCHAR(100)
		 ,  @P_VER_ID				CHAR(32)
		 ,  @P_PRICE_TP_ID			CHAR(32)
		 ,  @P_PLAN_TP_ID			CHAR(32)
		 -- Close Status
		 ,  @P_DMND_TP_ID			CHAR(32)
		 ,  @P_CL_STATUS_CD			NVARCHAR(10)
		 ,  @P_DMND_CNT				INT = 0
		 ,	@P_MAIL_YN      		CHAR(1)
		;	
/*************************************************************************************************
	-- Get Version Info
*************************************************************************************************/
	IF @P_VER_CD IS NULL 
	BEGIN 
		SELECT TOP 1
			   @P_TO_DATE		= TO_DATE
			  ,@P_FROM_DATE		= FROM_DATE 
			  ,@P_PRICE_TP_ID	= PRICE_TP_ID
			  ,@P_PLAN_TP_ID	= PLAN_TP_ID	
			  ,@P_VER_ID		= ID 
			  ,@P_VER_CD         = VER_ID 
		  FROM TB_DP_CONTROL_BOARD_VER_MST 
		 ORDER BY CREATE_DTTM DESC 
		;		
	END
	ELSE 
	BEGIN
		SELECT @P_TO_DATE			= TO_DATE
			  ,@P_FROM_DATE			= FROM_DATE 
			  ,@P_PRICE_TP_ID		= PRICE_TP_ID
			  ,@P_PLAN_TP_ID		= PLAN_TP_ID	
			  ,@P_VER_ID			= ID 
		  FROM TB_DP_CONTROL_BOARD_VER_MST 
		 WHERE VER_ID = @P_VER_CD		  
		;
	END 
	;
	IF @P_CL_LV_MGMT_ID IS NULL 
	BEGIN
		SELECT @P_CL_LV_MGMT_ID = CL_LV_MGMT_ID 
		  FROM TB_DP_CONTROL_BOARD_VER_DTL
		 WHERE CONBD_VER_MST_ID = @P_VER_ID 
		   AND WORK_TP_ID IN (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_WK_TP' AND CONF_CD = 'CL')
	END 
/*************************************************************************************************
	-- Close Status check
*************************************************************************************************/
	SELECT @P_CL_STATUS_CD = C2.CONF_CD 
	 FROM TB_DP_CONTROL_BOARD_VER_DTL D
		 INNER JOIN  
		  TB_CM_COMM_CONFIG C1
	   ON D.WORK_TP_ID = C1.ID 
	  AND C1.CONF_CD = 'CL' 
	      INNER JOIN 
		  TB_CM_COMM_CONFIG C2
	   ON C2.ID = D.CL_STATUS_ID
	WHERE CONBD_VER_MST_ID = @P_VER_ID
	;
/*********************************************************************************************************
	-- Check Use of Price config 
*********************************************************************************************************/
	DECLARE @P_USE_PRICE CHAR(1) = 'N';
IF EXISTS (
	SELECT CONF_CD 
	  FROM TB_CM_COMM_CONFIG 
	WHERE CONF_GRP_CD = 'DP_MS_VAL_TP' 
	   AND ACTV_YN = 'Y' 	
	   AND CONF_CD LIKE 'PRC%'
	   )
BEGIN
	SET @P_USE_PRICE = 'Y' ;
END
/*********************************************************************************************************
	-- Calculate amount of DP Entry
*********************************************************************************************************/
IF (@P_CL_STATUS_CD != 'CLOSE')
	BEGIN
		IF (@P_USE_PRICE = 'N')
		BEGIN
			WITH UNIT_PRICE
			AS (
			SELECT   ITEM_MST_ID
				   , ACCOUNT_ID
				   , BASE_DATE																												AS STRT_DATE 
				   , ISNULL(DATEADD(DAY,-1,LEAD(BASE_DATE) OVER (PARTITION BY ITEM_MST_ID, ACCOUNT_ID ORDER BY  BASE_DATE )),@P_TO_DATE)	AS END_DATE  
				   , UTPIC
			  FROM TB_DP_UNIT_PRICE UP
			--	   INNER JOIN
			--	   IA	-- 가격에서 매핑돼있는 데이터만 가져오기
			--	ON UP.ITEM_MST_ID = IA.ITEM_ID
			--   AND UP.ACCOUNT_ID = IA.ACCT_ID	   
			 WHERE BASE_DATE <= @P_TO_DATE 
			   AND PRICE_TP_ID = @P_PRICE_TP_ID
			)	
				UPDATE TB_DP_ENTRY
				   SET AMT = QTY * UP.UTPIC		-- 왜 AMT 하나만 있지??
				     , AMT_1 = QTY_1 * UP.UTPIC	 -- 추가해줌
				     , AMT_2 = QTY_2 * UP.UTPIC	 
				     , AMT_3 = QTY_3 * UP.UTPIC	 
				  FROM UNIT_PRICE UP
				  WHERE TB_DP_ENTRY.ITEM_MST_ID = UP.ITEM_MST_ID  
				   AND TB_DP_ENTRY.ACCOUNT_ID = UP.ACCOUNT_ID
				   AND TB_DP_ENTRY.BASE_DATE BETWEEN UP.STRT_DATE  AND UP.END_DATE 
				   AND VER_ID = @P_VER_ID 
				  ;
		 END
		 ELSE 
		 BEGIN
				UPDATE TB_DP_ENTRY
				   SET AMT_P1 = QTY * PRC1 
					  ,AMT_P2 = QTY * PRC2
					  ,AMT_1_P1 = QTY_1 * PRC1 
					  ,AMT_1_P2 = QTY_1 * PRC2
					  ,AMT_2_P1 = QTY_2 * PRC1 
					  ,AMT_2_P2 = QTY_2 * PRC2
					  ,AMT_3_P1 = QTY_3 * PRC1 
					  ,AMT_3_P2 = QTY_3 * PRC2
					  ,AMT_S_P1 = QTY_S * PRC1 
					  ,AMT_S_P2 = QTY_S * PRC2 
				  WHERE VER_ID = @P_VER_ID 
				  ;
		 END 
		 ;


	/********************************************************************************************************
		-- Get Entry Data
	*********************************************************************************************************/	   		   
		CREATE TABLE #TMP_RT	
		(  ITEM_MST_ID	CHAR(32)		COLLATE DATABASE_DEFAULT
		 , ACCOUNT_ID	CHAR(32)		COLLATE DATABASE_DEFAULT
		 , BASE_DATE	DATE			 
		 , EMP_ID		CHAR(32)		COLLATE DATABASE_DEFAULT
		 , QTY			DECIMAL(20,3)	 
		 , AMT			DECIMAL(20,3)	 
		 , QTY_1		DECIMAL(20,3)	 
		 , AMT_1		DECIMAL(20,3)	 
		 , QTY_2		DECIMAL(20,3)	 
		 , AMT_2		DECIMAL(20,3)	 
		 , QTY_3		DECIMAL(20,3)	 
		 , AMT_3		DECIMAL(20,3)	 
		 , QTY_I		DECIMAL(20,3)
		 , QTY_R		DECIMAL(20,3)
		 , AMT_R 		DECIMAL(20,3)
		 , QTY_S		DECIMAL(20,3)
		 , AMT_S		DECIMAL(20,3)
		 , QTY_SR		DECIMAL(20,3)
		 , AMT_SR		DECIMAL(20,3)
		 , AMT_P1		DECIMAL(20,3)
		 , PRC1		    DECIMAL(20,3)
		 , PRC2			DECIMAL(20,3) 
		 , AMT_1_P1 	DECIMAL(20,3) 
		 , AMT_2_P1 	DECIMAL(20,3) 
		 , AMT_3_P1 	DECIMAL(20,3) 
		 , AMT_A_P1 	DECIMAL(20,3) 
		 , AMT_S_P1 	DECIMAL(20,3) 
		 , AMT_R_P1 	DECIMAL(20,3) 
		 , AMT_SR_P1	DECIMAL(20,3) 
		 , AMT_P2   	DECIMAL(20,3) 
		 , AMT_1_P2 	DECIMAL(20,3) 
		 , AMT_2_P2 	DECIMAL(20,3) 
		 , AMT_3_P2 	DECIMAL(20,3) 
		 , AMT_A_P2 	DECIMAL(20,3) 
		 , AMT_S_P2 	DECIMAL(20,3) 
		 , AMT_R_P2 	DECIMAL(20,3) 
		 , AMT_SR_P2	DECIMAL(20,3) 
		 , PRIORT		INT
		);
		INSERT INTO #TMP_RT
		(  ITEM_MST_ID	
		 , ACCOUNT_ID	
		 , BASE_DATE	
		 , EMP_ID 
		 , QTY			
		 , AMT			
		 , QTY_1		
		 , AMT_1		
		 , QTY_2		
		 , AMT_2		
		 , QTY_3		
		 , AMT_3	
		 , QTY_I	
		 , QTY_R	
		 , AMT_R 	
		 , QTY_S	
		 , AMT_S	
		 , QTY_SR	
		 , AMT_SR
		 , AMT_P1
		 , PRC1		
		 , PRC2		
		 , AMT_1_P1 	
		 , AMT_2_P1 	
		 , AMT_3_P1 	
		 , AMT_A_P1 	
		 , AMT_S_P1 	
		 , AMT_R_P1 	
		 , AMT_SR_P1	
		 , AMT_P2   	
		 , AMT_1_P2 	
		 , AMT_2_P2 	
		 , AMT_3_P2 	
		 , AMT_A_P2 	
		 , AMT_S_P2 	
		 , AMT_R_P2 	
		 , AMT_SR_P2	
		 , PRIORT
		)
		SELECT ITEM_MST_ID	
			 , ACCOUNT_ID	
			 , BASE_DATE	
			 , EMP_ID 
			 , QTY			
			 , AMT			
			 , QTY_1		
			 , AMT_1		
			 , QTY_2		
			 , AMT_2		
			 , QTY_3		
			 , AMT_3	
			 , QTY_I	
			 , QTY_R	
			 , AMT_R 	
			 , QTY_S	
			 , AMT_S	
			 , QTY_SR	
			 , AMT_SR	
			 , AMT_P1
			 , PRC1		
			 , PRC2		
			 , AMT_1_P1 	
			 , AMT_2_P1 	
			 , AMT_3_P1 	
			 , AMT_A_P1 	
			 , AMT_S_P1 	
			 , AMT_R_P1 	
			 , AMT_SR_P1	
			 , AMT_P2   	
			 , AMT_1_P2 	
			 , AMT_2_P2 	
			 , AMT_3_P2 	
			 , AMT_A_P2 	
			 , AMT_S_P2 	
			 , AMT_R_P2 	
			 , AMT_SR_P2	
			 , PRIORT
		 FROM TB_DP_ENTRY 	
		WHERE VER_ID =  @P_VER_ID  
		  AND AUTH_TP_ID = @P_CL_LV_MGMT_ID
		  AND ACTV_YN = 'Y'
	/*********************************************************************************************************
		-- Close : Transfer a result for Demand Overview or Forecast of Sales RP
	*********************************************************************************************************/
	IF (@P_CL_MODULE_TP NOT IN ('SO', 'NN'))
		BEGIN -- DELETE DEMAND_OVERVIEW
			DELETE FROM TB_CM_DEMAND_OVERVIEW
			 WHERE T3SERIES_VER_ID = @P_VER_CD
		END 
--	IF (@P_CL_MODULE_TP IN ('SCP_SO_FCST', 'SCP_SO_FCST_NETTING', 'SCP_SO', 'SCP_FCST')) 
--		BEGIN
--			EXEC [SP_UI_DP_DMND_TRANSMISSION]
--			  @P_VER_CD
--			 ,@p_CUTOFF_VER_CD
--			 ,@P_USER_ID	
--			 ,@P_CL_LV_MGMT_ID
--			 ,@P_CL_MODULE_TP
--			 ,'#TMP_RT'
--			 ;
--		END 
	IF (@P_CL_MODULE_TP IN ('SCP_SO', 'SCP_FCST', 'SCP_SO_FCST_NETTING'))
	      BEGIN
	   -- GET DMND_TP_ID
			SELECT @P_DMND_TP_ID = B.ID 
			  FROM TB_AD_COMN_GRP A
				  ,TB_AD_COMN_CODE B
			 WHERE 1=1
			   AND A.ID = B.SRC_ID
			   AND A.GRP_CD = 'DEMAND_TYPE'
			   AND COMN_CD_NM = 'Actual S/O'
			   ;
			  
			-- INSERT DEMAND_OVERVIEW 
			INSERT INTO TB_CM_DEMAND_OVERVIEW
					   (   ID
						 , MODULE_VAL
						 , T3SERIES_VER_ID
						 , DMND_ID
						 , DMND_TP_ID
						 , DMND_CLASS_ID
						 , ITEM_MST_ID
	--					 , URGENT_ORDER_TP_ID
						 , DMND_QTY
						 , UOM_ID
						 , DUE_DATE
						 , REQUEST_SITE_ID
						 , ACCOUNT_ID
						 , SALES_UNIT_PRIC
	--					 , MARGIN
						 , CURCY_CD_ID
	--					 , PRDUCT_DELIVY_DATE
	--					 , ASSIGN_SITE_CNT
	--					 , ASSIGN_RES_CNT
						 , DELIVY_PLAN_POLICY_CD_ID
						 , MAT_CONST_CD_ID
						 , EFFICY
						 , PARTIAL_PLAN_YN
						 , COST_OPTIMIZ_YN
	--					 , PST
						 , DUE_DATE_FNC
						 , ACTV_YN
						 , CREATE_BY
						 , CREATE_DTTM
	--					 , MODIFY_BY
	--					 , MODIFY_DTTM
	--					 , DESCRIP
	--					 , FORECAST_ID
	--					 , FORECAST_QTY
	--					 , HEURISTIC_YN
	--					 , STRATEGY_METHD_ID
	--					 , DISPLAY_COLOR
						 , PRIORT
						)
					SELECT REPLACE(NEWID(),'-','')													ID
						 , 'DP'																		MODULE_VAL
			--			 , NULL																		YYYYMMDD
			--			 , NULL																		MAIN_VER
			--			 , NULL																		REVISION_VER
						 , @P_VER_CD																T3SERIES_VER_ID
						 , 'DMND_'
						 + REPLICATE('0', 15-LEN(CONVERT(NVARCHAR(15), ROW_NUMBER() OVER (ORDER BY DE.ITEM_MST_ID))))
						 + CONVERT(NVARCHAR(15), ROW_NUMBER() OVER (ORDER BY DE.ITEM_MST_ID))		DMND_ID
						 , @P_DMND_TP_ID					   									    DMND_TP
						 , (SELECT B.ID 
							  FROM TB_AD_COMN_GRP A
								  ,TB_AD_COMN_CODE B
							 WHERE 1=1
							   AND A.ID = B.SRC_ID
							   AND A.GRP_CD = 'DEMAND_CLASS'
							   AND COMN_CD = 'NEW')													DMND_CLASS_ID
						 , DE.ITEM_MST_ID
			--			 , NULL																		URGENT_ORDER_TP_ID
						 , QTY_S																    DMND_QTY
						 , UM.ID																    UOM_ID
						 , BASE_DATE																DUE_DATE
						 , COALESCE(B1.LOC_DTL_ID, B2.LOC_DTL_ID, B3.LOC_DTL_ID)                    REQUEST_SITE_ID
						 , DE.ACCOUNT_ID
						 , CASE WHEN QTY = 0 THEN 0 ELSE COALESCE(AMT, AMT_P1)/QTY	END				SALES_UNIT_PRIC
			--			 , MARGIN
						 , AC.CURCY_CD_ID															CURCY_CD_ID
			--			 , BOD_LEADTIME
			--			 , TIME_UOM_ID
			--			 , PRDUCT_DELIVY_DATE
			--			 , ASSIGN_SITE_CNT
			--			 , ASSIGN_RES_CNT
						 , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'CM_BASE_ORD_DELIV_POLICY'
							   AND DEFAT_VAL = 'Y'			 
						   )																		DELIVY_PLAN_POLICY_CD_ID
						 , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'MP_ORD_CAPA_MAT_COST'
							   AND DEFAT_VAL = 'Y')													MAT_CONST_CD_ID
						 , (SELECT CONF_CD  FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'MP_BASE_EFFCIENCY')								EFFICY
						 , (SELECT CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'MP_ORD_PARTIAL_PLN')								PARTIAL_PLAN_YN
						 , (SELECT (CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end) FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'CM_ORD_ROUT_COST_OPT')							COST_OPTIMIZ_YN
			--			 , PST
						 , ( SELECT CASE B.UOM_CD
										 WHEN 'DAY'   THEN DATEADD(DD, CAST(A.CATAGY_VAL AS NUMERIC), BASE_DATE)   
										 WHEN 'WEEK'  THEN DATEADD(WK, CAST(A.CATAGY_VAL AS NUMERIC), BASE_DATE)    
										 WHEN 'MONTH' THEN DATEADD(MM, CAST(A.CATAGY_VAL AS NUMERIC), BASE_DATE)   
										 WHEN 'YEAR'  THEN DATEADD(YY, CAST(A.CATAGY_VAL AS NUMERIC), BASE_DATE)    
									END			 
							  FROM TB_CM_BASE_ORDER A
								   INNER JOIN
								   TB_CM_UOM B
								ON A.CATAGY_CD = 'BASE_ORDER_DUE_DATE_FENCE'
							   AND A.UOM_ID = B.ID AND  A.ACTV_YN = 'Y' )						    DUE_DATE_FNC
			--			 , DELIVY_DATE
			--			 , DAYS_LATE
			--			 , PLAN_QTY
			--			 , LATE_QTY
			--			 , DELIVY_QTY
			--			 , ON_TIME_QTY
			--			 , SHRT_QTY
						 , CASE WHEN @P_DMND_TP_ID IS NULL THEN 'N' ELSE 'Y' END					ACTV_YN
						 , @P_USER_ID																CREATE_BY
						 , GETDATE()																CREATE_DTTM
			--			 , NULL																		MODIFY_BY
			--			 , NULL																		MODIFY_DTTM
			--			 , DESCRIP
			--			 , NETTING_QTY
			--			 , FORECAST_ID
			--			 , FORECAST_QTY
			--			 , SRC_DMND_ID
			--			 , DMND_LOCAT_ID
			--			 , HEURISTIC_YN
			--			 , STRATEGY_METHD_ID
			--			 , DISPLAY_COLOR
						 , DE.PRIORT
					  FROM #TMP_RT  DE
						   INNER JOIN
						   TB_DPD_ITEM_HIERACHY2 IT 
						ON DE.ITEM_MST_ID = IT.ITEM_ID 
                        AND IT.LV_TP_CD = 'I'
                        AND IT.USE_YN = 'Y'
					   AND DE.BASE_DATE BETWEEN COALESCE(IT.RTS,@P_FROM_DATE) AND COALESCE(IT.EOS, @P_TO_DATE) 
						   INNER JOIN 
						   TB_CM_UOM UM
						ON IT.UOM = UM.UOM_CD 
					   AND UM.ACTV_YN = 'Y' 
	--				   AND CASE  WHEN IT.RTS IS NULL AND IT.EOS IS NULL			THEN  1
	--							 WHEN IT.EOS IS NULL AND DE.BASE_DATE >= IT.RTS THEN  1
	--							 WHEN IT.RTS IS NULL AND DE.BASE_DATE <= IT.EOS THEN  1
	--							 WHEN DE.BASE_DATE BETWEEN IT.RTS AND IT.EOS	THEN  1
	--							 ELSE 0  
	--					   END = 1 
						   INNER JOIN
						   TB_DP_ACCOUNT_MST AC
						ON AC.id = DE.ACCOUNT_ID
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B1
										 WHERE AC.ATTR_01 = B1.CORP_CD
										   AND B1.LOC_TP_NM = 'CDC'
										   AND B1.OUTSRC_YN = 'N'
										   AND AC.ATTR_04 = 'KR'
										   AND (AC.ATTR_05 NOT LIKE 'A%' AND AC.ATTR_05 NOT LIKE 'B%')
										   AND ISNULL(B1.CUST_SHPP_YN, 'N') = 'Y' ) B1
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B2
										 WHERE CORP_CD = '1000'
										   AND B2.LOC_TP_NM = 'RDC'
										   AND AC.ATTR_05 IN ('A199', 'B199')
										   AND (AC.ATTR_05 LIKE 'A%' OR AC.ATTR_05 LIKE 'B%')
										   AND ISNULL(B2.CUST_SHPP_YN, 'N') = 'Y') B2
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B2
										 WHERE CASE WHEN AC.ATTR_05 = '1230' THEN '1110'
										  		    WHEN AC.ATTR_05 = '1250' THEN '1110'
										  		    WHEN AC.ATTR_05 = '1130' THEN '1110'
										  		    ELSE AC.ATTR_05 END = B2.PLNT_CD
 										   AND B2.LOC_TP_NM = 'RDC'
										   AND AC.ATTR_05 NOT IN ('A199', 'B199')
										   AND ISNULL(B2.CUST_SHPP_YN, 'N') = 'Y') B3
						 --  LEFT OUTER JOIN
						 --  (
						 --  SELECT B.LOCAT_ID, A.ITEM_MST_ID, A.ACCOUNT_ID
						 --    FROM TB_CM_DMND_SHPP_MAP_MST A
						 --         INNER JOIN
						 --         TB_CM_LOC_MGMT B
						 --ON B.ID = A.LOCAT_MGMT_ID
						 --  ) DSM
       --                 ON DSM.ITEM_MST_ID = DE.ITEM_MST_ID
       --                AND DSM.ACCOUNT_ID = DE.ACCOUNT_ID
					 WHERE QTY_S > 0
					 ;
					 
				  SELECT @P_DMND_CNT = COUNT(1)
				     FROM #TMP_RT
					 ;
		   END
	IF (@P_CL_MODULE_TP IN ('SCP_FCST', 'SCP_SO_FCST_NETTING')) 
		   BEGIN
		  	-- GET DMND_TP_ID
			SELECT @P_DMND_TP_ID = B.ID 
			  FROM TB_AD_COMN_GRP A
				  ,TB_AD_COMN_CODE B
			 WHERE 1=1
			   AND A.ID = B.SRC_ID
			   AND A.GRP_CD = 'DEMAND_TYPE'
			   AND COMN_CD_NM = 'Forecast'
			   ;
			-- INSERT DEMAND_OVERVIEW 
			WITH CAL
			  AS (
					SELECT MIN(DAT) AS STRT_DATE 
						 , MAX(DAT) AS END_DATE 
					 FROM TB_CM_CALENDAR
					 WHERE DAT BETWEEN @P_FROM_DATE AND @P_TO_DATE
				 GROUP BY CASE @P_BUKT 
	 						WHEN 'M' THEN YYYYMM
	 						WHEN 'PW' THEN MM+DP_WK
	 						WHEN 'W' THEN DP_WK
	 						ELSE YYYYMMDD
	 					  END 
			  ), MEASRUE
			  AS (
					SELECT ITEM_MST_ID, ACCOUNT_ID, C.STRT_DATE AS BASE_DATE, SUM(ACT_SALES_QTY) AS ACT_SALES_QTY, SUM(ACT_SALES_AMT) AS ACT_SALES_AMT 
					  FROM TB_DP_MEASURE_DATA M
						   INNER JOIN 
						   CAL C
						ON M.BASE_DATE BETWEEN C.STRT_DATE AND C.END_DATE			
				  GROUP BY ITEM_MST_ID, ACCOUNT_ID, C.STRT_DATE
			  )
			INSERT INTO TB_CM_DEMAND_OVERVIEW
					   (   ID
						 , MODULE_VAL
						 , T3SERIES_VER_ID
						 , DMND_ID
						 , DMND_TP_ID
						 , DMND_CLASS_ID
						 , ITEM_MST_ID
	--					 , URGENT_ORDER_TP_ID
						 , DMND_QTY
						 , UOM_ID
						 , DUE_DATE
						 , REQUEST_SITE_ID
						 , ACCOUNT_ID
						 , SALES_UNIT_PRIC
	--					 , MARGIN
						 , CURCY_CD_ID
	--					 , PRDUCT_DELIVY_DATE
	--					 , ASSIGN_SITE_CNT
	--					 , ASSIGN_RES_CNT
						 , DELIVY_PLAN_POLICY_CD_ID
						 , MAT_CONST_CD_ID
						 , EFFICY
						 , PARTIAL_PLAN_YN
						 , COST_OPTIMIZ_YN
	--					 , PST
						 , DUE_DATE_FNC
						 , ACTV_YN
						 , CREATE_BY
						 , CREATE_DTTM
	--					 , MODIFY_BY
	--					 , MODIFY_DTTM
	--					 , DESCRIP
	--					 , FORECAST_ID
	--					 , FORECAST_QTY
	--					 , HEURISTIC_YN
	--					 , STRATEGY_METHD_ID
	--					 , DISPLAY_COLOR
						 , PRIORT
						)
					SELECT REPLACE(NEWID(),'-','')													ID
						 , 'DP'																		MODULE_VAL
						 , @P_VER_CD																T3SERIES_VER_ID
						 , 'DMND_'
						 + REPLICATE('0', 15-LEN(CONVERT(NVARCHAR(15), @P_DMND_CNT+ROW_NUMBER() OVER (ORDER BY DE.ITEM_MST_ID))))
						 + CONVERT(NVARCHAR(15), @P_DMND_CNT+ROW_NUMBER() OVER (ORDER BY DE.ITEM_MST_ID))				DMND_ID
						 , @P_DMND_TP_ID					   									    DMND_TP_ID
						 , (SELECT B.ID 
							  FROM TB_AD_COMN_GRP A
								  ,TB_AD_COMN_CODE B
							 WHERE 1=1
							   AND A.ID = B.SRC_ID
							   AND A.GRP_CD = 'DEMAND_CLASS'
							   AND COMN_CD = 'NEW')													DMND_CLASS_ID
						 , DE.ITEM_MST_ID
			--			 , NULL																		URGENT_ORDER_TP_ID
						 , CASE WHEN @P_CL_MODULE_TP = 'SCP_SO_FCST_NETTING' THEN QTY-COALESCE(MS.ACT_SALES_QTY,0)  ELSE QTY END		DMND_QTY

						 , UM.ID																    UOM_ID
						 , DE.BASE_DATE																DUE_DATE
						 , COALESCE(B1.LOC_DTL_ID, B2.LOC_DTL_ID, B3.LOC_DTL_ID)                    REQUEST_SITE_ID
						 , DE.ACCOUNT_ID
						 , CASE WHEN QTY = 0 THEN 0 ELSE COALESCE(AMT, AMT_P1)/QTY	END				SALES_UNIT_PRIC
			--			 , MARGIN
						 , AC.CURCY_CD_ID															CURCY_CD_ID
			--			 , BOD_LEADTIME
			--			 , TIME_UOM_ID
			--			 , PRDUCT_DELIVY_DATE
			--			 , ASSIGN_SITE_CNT
			--			 , ASSIGN_RES_CNT
						 , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'CM_BASE_ORD_DELIV_POLICY'
							   AND DEFAT_VAL = 'Y'			 
						   )																		DELIVY_PLAN_POLICY_CD_ID
						 , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'MP_ORD_CAPA_MAT_COST'
							   AND DEFAT_VAL = 'Y')													MAT_CONST_CD_ID
						 , (SELECT CONF_CD  FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'MP_BASE_EFFCIENCY')								EFFICY
						 , (SELECT CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'MP_ORD_PARTIAL_PLN')								PARTIAL_PLAN_YN
						 , (SELECT (CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end) FROM TB_CM_COMM_CONFIG
							 WHERE CONF_GRP_CD = 'CM_ORD_ROUT_COST_OPT')							COST_OPTIMIZ_YN
			--			 , PST
						 , ( SELECT CASE B.UOM_CD
										 WHEN 'DAY'   THEN DATEADD(DD, CAST(A.CATAGY_VAL AS NUMERIC), DE.BASE_DATE)   
										 WHEN 'WEEK'  THEN DATEADD(WK, CAST(A.CATAGY_VAL AS NUMERIC), DE.BASE_DATE)    
										 WHEN 'MONTH' THEN DATEADD(MM, CAST(A.CATAGY_VAL AS NUMERIC), DE.BASE_DATE)   
										 WHEN 'YEAR'  THEN DATEADD(YY, CAST(A.CATAGY_VAL AS NUMERIC), DE.BASE_DATE)    
									END			 
							  FROM TB_CM_BASE_ORDER A
								   INNER JOIN
								   TB_CM_UOM B
								ON A.CATAGY_CD = 'BASE_ORDER_DUE_DATE_FENCE'
							   AND A.UOM_ID = B.ID AND  A.ACTV_YN = 'Y' )						    DUE_DATE_FNC
			--			 , DELIVY_DATE
			--			 , DAYS_LATE
			--			 , PLAN_QTY
			--			 , LATE_QTY
			--			 , DELIVY_QTY
			--			 , ON_TIME_QTY
			--			 , SHRT_QTY
						 , CASE WHEN @P_DMND_TP_ID IS NULL THEN 'N' ELSE 'Y' END					ACTV_YN
						 , @P_USER_ID																CREATE_BY
						 , GETDATE()																CREATE_DTTM
			--			 , NULL																		MODIFY_BY
			--			 , NULL																		MODIFY_DTTM
			--			 , DESCRIP
			--			 , NETTING_QTY
			--			 , FORECAST_ID
			--			 , FORECAST_QTY
			--			 , SRC_DMND_ID
			--			 , DMND_LOCAT_ID
			--			 , HEURISTIC_YN
			--			 , STRATEGY_METHD_ID
			--			 , DISPLAY_COLOR
						 --, DENSE_RANK() OVER (PARTITION BY DE.BASE_DATE ORDER BY CAST(ISNULL(DE.PRIORT, 3) AS NVARCHAR(10)) + CAST(ISNULL(SAM.PRIORT, 3) AS NVARCHAR(10)) + CAST(ISNULL(SIM.PRIORT, 3) AS NVARCHAR(10)), QTY DESC) AS PRIORT
						 , CAST(ISNULL(DE.PRIORT, 3) AS NVARCHAR(10)) + CAST(ISNULL(SAM.PRIORT, 3) AS NVARCHAR(10)) + CAST(ISNULL(SIM.PRIORT, 3) AS NVARCHAR(10)) AS PRIORT
					  FROM #TMP_RT  DE
						   INNER JOIN
						   TB_DPD_ITEM_HIERACHY2 IT 
						ON DE.ITEM_MST_ID = IT.ITEM_ID 
                        AND IT.LV_TP_CD = 'I'
                        AND IT.USE_YN = 'Y'
					   AND DE.BASE_DATE BETWEEN COALESCE(IT.RTS,@P_FROM_DATE) AND COALESCE(IT.EOS, @P_TO_DATE) 
						   INNER JOIN 
						   TB_CM_UOM UM
						ON IT.UOM = UM.UOM_CD 
					   AND UM.ACTV_YN = 'Y' 
	--				   AND CASE  WHEN IT.RTS IS NULL AND IT.EOS IS NULL			THEN  1
	--							 WHEN IT.EOS IS NULL AND DE.BASE_DATE >= IT.RTS THEN  1
	--							 WHEN IT.RTS IS NULL AND DE.BASE_DATE <= IT.EOS THEN  1
	--							 WHEN DE.BASE_DATE BETWEEN IT.RTS AND IT.EOS	THEN  1
	--							 ELSE 0  
	--					   END = 1 
						   INNER JOIN
						   TB_DP_ACCOUNT_MST AC
						ON AC.id = DE.ACCOUNT_ID
						   LEFT JOIN -- 전략 제품
						   (SELECT DISTINCT ITEM_MST_ID, PRIORT 
						      FROM TB_SKC_DP_STRTGY_ITEM_MST 
							 WHERE VER_ID = @P_VER_CD) SIM
						ON DE.ITEM_MST_ID = SIM.ITEM_MST_ID
						   LEFT JOIN -- 전략 고객
						   (SELECT DISTINCT ACCOUNT_CD, REGION, PRIORT
						      FROM TB_SKC_DP_STRTGY_ACCOUNT_MST 
							 WHERE VER_ID = @P_VER_CD) SAM
						ON AC.ATTR_03 = SAM.ACCOUNT_CD
					   AND AC.ATTR_04 = SAM.REGION
						   LEFT OUTER JOIN 
						   MEASRUE MS
						ON DE.ITEM_MST_ID = MS.ITEM_MST_ID
					   AND DE.ACCOUNT_ID = MS.ACCOUNT_ID
					   AND DE.BASE_DATE = MS.BASE_DATE 
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B1
										 WHERE AC.ATTR_01 = B1.CORP_CD
										   AND B1.LOC_TP_NM = 'CDC'
										   AND B1.OUTSRC_YN = 'N'
										   AND AC.ATTR_04 = 'KR'
										   AND (AC.ATTR_05 NOT LIKE 'A%' AND AC.ATTR_05 NOT LIKE 'B%')
										   AND ISNULL(B1.CUST_SHPP_YN, 'N') = 'Y' ) B1
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B2
										 WHERE CORP_CD = '1000'
										   AND B2.LOC_TP_NM = 'RDC'
										   AND AC.ATTR_05 IN ('A199', 'B199')
										   AND (AC.ATTR_05 LIKE 'A%' OR AC.ATTR_05 LIKE 'B%')
										   AND ISNULL(B2.CUST_SHPP_YN, 'N') = 'Y') B2
						   OUTER APPLY (SELECT LOC_DTL_ID
										  FROM VW_LOCAT_DTS_INFO B2
										 WHERE CASE WHEN AC.ATTR_05 = '1230' THEN '1110'
										  		    WHEN AC.ATTR_05 = '1250' THEN '1110'
										  		    WHEN AC.ATTR_05 = '1130' THEN '1110'
										  		    ELSE AC.ATTR_05 END = B2.PLNT_CD
 										   AND B2.LOC_TP_NM = 'RDC'
										   AND AC.ATTR_05 NOT IN ('A199', 'B199')
										   AND ISNULL(B2.CUST_SHPP_YN, 'N') = 'Y') B3
						   --LEFT OUTER JOIN
						   --(
						   --SELECT B.LOCAT_ID, A.ITEM_MST_ID, A.ACCOUNT_ID
						   --  FROM TB_CM_DMND_SHPP_MAP_MST A
						   --       INNER JOIN
						   --       TB_CM_LOC_MGMT B
						   --    ON B.ID = A.LOCAT_MGMT_ID
						   --) DSM
         --               ON DSM.ITEM_MST_ID = DE.ITEM_MST_ID
         --              AND DSM.ACCOUNT_ID = DE.ACCOUNT_ID
					 WHERE 1=1
					   AND CASE WHEN @P_CL_MODULE_TP = 'SCP_SO_FCST_NETTING' THEN QTY-COALESCE(MS.ACT_SALES_QTY,0)  ELSE QTY END	> 0 
	--				   AND AUTH_TP_ID = @P_CL_LV_MGMT_ID
					   ;	
		  END

	/*************************************************************************************************
		--  Make Entry History or Cutoff
	*************************************************************************************************/		
	IF (@P_DP_CL_STATUS = 'CLOSE')
		BEGIN
				MERGE INTO TB_DP_ENTRY_HISTORY TGT
				USING (
				SELECT ITEM_MST_ID
					 , ACCOUNT_ID
					 , BASE_DATE
					 , EMP_ID
					 , QTY
					 , AMT
					 , QTY_1
					 , AMT_1
					 , QTY_2
					 , AMT_2
					 , QTY_3
					 , AMT_3
					 , QTY_I	
					 , QTY_R	
					 , AMT_R 	
					 , QTY_S	
					 , AMT_S	
					 , QTY_SR	
					 , AMT_SR
					 , PRC1 
					 , PRC2 
					 , AMT_P1   
					 , AMT_1_P1 
					 , AMT_2_P1 
					 , AMT_3_P1 
					 , AMT_A_P1 
					 , AMT_S_P1 
					 , AMT_R_P1 
					 , AMT_SR_P1
					 , AMT_P2   
					 , AMT_1_P2 
					 , AMT_2_P2 
					 , AMT_3_P2 
					 , AMT_A_P2 
					 , AMT_S_P2 
					 , AMT_R_P2 
					 , AMT_SR_P2
				 FROM #TMP_RT
					) SRC
				 ON TGT.ITEM_MST_ID = SRC.ITEM_MST_ID
				AND TGT.ACCOUNT_ID  = SRC.ACCOUNT_ID
				AND TGT.BASE_DATE   = SRC.BASE_DATE
				AND TGT.PLAN_TP_ID  = @P_PLAN_TP_ID
				WHEN MATCHED THEN
					UPDATE SET TGT.QTY   = SRC.QTY 
							 , TGT.AMT   = SRC.AMT 
							 , TGT.QTY_1 = SRC.QTY_1
							 , TGT.QTY_2 = SRC.QTY_2
							 , TGT.QTY_3 = SRC.QTY_3
							 , TGT.AMT_1 = SRC.AMT_1
							 , TGT.AMT_2 = SRC.AMT_2
							 , TGT.AMT_3 = SRC.AMT_3
							 , TGT.QTY_I = SRC.QTY_I	
							 , TGT.QTY_R = SRC.QTY_R	
							 , TGT.AMT_R = SRC.AMT_R 	
							 , TGT.QTY_S = SRC.QTY_S	
							 , TGT.AMT_S = SRC.AMT_S	
							 , TGT.QTY_SR = SRC.QTY_SR	
							 , TGT.AMT_SR = SRC.AMT_SR
							 , TGT.PRC1 = SRC.PRC1 
							 , TGT.PRC2 = SRC.PRC2 
							 , TGT.AMT_P1	 = SRC.AMT_P1   
							 , TGT.AMT_1_P1  = SRC.AMT_1_P1 
							 , TGT.AMT_2_P1  = SRC.AMT_2_P1 
							 , TGT.AMT_3_P1  = SRC.AMT_3_P1 
							 , TGT.AMT_A_P1  = SRC.AMT_A_P1 
							 , TGT.AMT_S_P1  = SRC.AMT_S_P1 
							 , TGT.AMT_R_P1  = SRC.AMT_R_P1 
							 , TGT.AMT_SR_P1 = SRC.AMT_SR_P1
							 , TGT.AMT_P2    = SRC.AMT_P2   
							 , TGT.AMT_1_P2  = SRC.AMT_1_P2 
							 , TGT.AMT_2_P2  = SRC.AMT_2_P2 
							 , TGT.AMT_3_P2  = SRC.AMT_3_P2 
							 , TGT.AMT_A_P2  = SRC.AMT_A_P2 
							 , TGT.AMT_S_P2  = SRC.AMT_S_P2 
							 , TGT.AMT_R_P2  = SRC.AMT_R_P2 
							 , TGT.AMT_SR_P2 = SRC.AMT_SR_P2
							 , TGT.MODIFY_BY = @P_USER_ID
							 , TGT.MODIFY_DTTM = GETDATE()
				WHEN NOT MATCHED THEN 
					INSERT 
					(  ID 
					 , ITEM_MST_ID
					 , ACCOUNT_ID
					 , BASE_DATE
					 , EMP_ID
					 , QTY
					 , AMT
					 , CREATE_BY
					 , CREATE_DTTM
					 , QTY_1
					 , AMT_1
					 , QTY_2
					 , AMT_2
					 , QTY_3
					 , AMT_3
					 , QTY_I	
					 , QTY_R	
					 , AMT_R 	
					 , QTY_S	
					 , AMT_S	
					 , QTY_SR	
					 , AMT_SR
					 , PLAN_TP_ID 			
					 , PRC1
					 , PRC2 
					 , AMT_P1   
					 , AMT_1_P1 
					 , AMT_2_P1 
					 , AMT_3_P1 
					 , AMT_A_P1 
					 , AMT_S_P1 
					 , AMT_R_P1 
					 , AMT_SR_P1
					 , AMT_P2   
					 , AMT_1_P2 
					 , AMT_2_P2 
					 , AMT_3_P2 
					 , AMT_A_P2 
					 , AMT_S_P2 
					 , AMT_R_P2 
					 , AMT_SR_P2
					) VALUES (
					   REPLACE(NEWID(),'-','')
					 , SRC.ITEM_MST_ID
					 , SRC.ACCOUNT_ID
					 , SRC.BASE_DATE
					 , SRC.EMP_ID
					 , SRC.QTY
					 , SRC.AMT
					 , @p_USER_ID
					 , GETDATE()
					 , SRC.QTY_1
					 , SRC.AMT_1
					 , SRC.QTY_2
					 , SRC.AMT_2
					 , SRC.QTY_3
					 , SRC.AMT_3
					 , SRC.QTY_I	
					 , SRC.QTY_R	
					 , SRC.AMT_R 	
					 , SRC.QTY_S	
					 , SRC.AMT_S	
					 , SRC.QTY_SR	
					 , SRC.AMT_SR
					 , @P_PLAN_TP_ID 
					 , SRC.PRC1 
					 , SRC.PRC2 
					 , SRC.AMT_P1   
					 , SRC.AMT_1_P1 
					 , SRC.AMT_2_P1 
					 , SRC.AMT_3_P1 
					 , SRC.AMT_A_P1 
					 , SRC.AMT_S_P1 
					 , SRC.AMT_R_P1 
					 , SRC.AMT_SR_P1
					 , SRC.AMT_P2   
					 , SRC.AMT_1_P2 
					 , SRC.AMT_2_P2 
					 , SRC.AMT_3_P2 
					 , SRC.AMT_A_P2 
					 , SRC.AMT_S_P2 
					 , SRC.AMT_R_P2 
					 , SRC.AMT_SR_P2
					)
					;
				/**********************************************************************************************************************************
					-- When Yealy Plan	
				**********************************************************************************************************************************/
				IF EXISTS (SELECT ATTR_01 FROM TB_CM_COMM_CONFIG WHERE ID = @P_PLAN_TP_ID AND ATTR_01 = 'Y' AND ACTV_YN = 'Y') 
				AND EXISTS (SELECT COLUMN_NAME
							  FROM INFORMATION_SCHEMA.COLUMNS
							 WHERE TABLE_NAME = 'TB_DP_MEASURE_DATA'
					  		   AND COLUMN_NAME LIKE 'ANNUAL%'
						   )
					BEGIN
						DECLARE @P_Y_BUKT_CD    NVARCHAR(100)
							  , @P_Y_STRT_DATE   DATE
							  , @P_Y_MID_DATE    DATE
							  , @P_Y_END_DATE    DATE
							  , @P_M_PLAN_TP_ID  CHAR(32)
							  , @P_M_BUKT_CD     NVARCHAR(100)
							  , @P_M_STRT_DATE   DATE
							  , @P_M_MID_DATE    DATE
							  , @P_M_END_DATE    DATE
							  ;
						SELECT @P_Y_BUKT_CD  = BUKT 
							  ,@P_Y_STRT_DATE = FROM_DATE
							  ,@P_Y_MID_DATE  = VER_S_HORIZON_DATE
							  ,@P_Y_END_DATE  = TO_DATE 
						  FROM TB_DP_CONTROL_BOARD_VER_MST M
						 WHERE M.ID = @P_VER_ID 
						;
						SELECT @P_M_PLAN_TP_ID = ID
						 FROM TB_CM_COMM_CONFIG
						WHERE CONF_GRP_CD = 'DP_PLAN_TYPE'
						  AND ATTR_01 = 'M'
						  AND ACTV_YN = 'Y'
						  AND USE_YN = 'Y'
						  ;
						SELECT TOP 1 @P_M_BUKT_CD  = BUKT 
									,@P_M_STRT_DATE = FROM_DATE
									,@P_M_MID_DATE  = VER_S_HORIZON_DATE
									,@P_M_END_DATE  = TO_DATE 
						  FROM TB_DP_CONTROL_BOARD_VER_MST 
						 WHERE PLAN_TP_ID = @P_M_PLAN_TP_ID 
						ORDER BY VER_ID DESC 
						;
						/**********************************************************************************************************************************
						-- Get Yealy Plan Result Data	
						**********************************************************************************************************************************/
						WITH Y_CAL
						 AS (
					 		SELECT MIN(DAT)  AS STRT_DATE
					 			 , MAX(DAT)  AS END_DATE
					 			 , COUNT(DAT) AS DATE_CNT
					 		  FROM TB_CM_CALENDAR
					 		 WHERE DAT BETWEEN @P_Y_STRT_DATE AND @P_Y_END_DATE
					 		GROUP BY YYYY
					 			   , CASE WHEN @P_Y_BUKT_CD IN ('M', 'PW')	THEN MM ELSE 1 END
					 			   , CASE WHEN @P_Y_BUKT_CD IN ('PW', 'W') THEN DP_WK ELSE 1 END
					 		), M_CAL
						 AS (
					 		SELECT MIN(DAT)  AS STRT_DATE
					 			 , MAX(DAT)  AS END_DATE
					 			 , COUNT(DAT) AS DATE_CNT
					 		  FROM TB_CM_CALENDAR
					 		 WHERE DAT BETWEEN @P_M_STRT_DATE AND @P_M_END_DATE
					 		GROUP BY YYYY
					 			   , CASE WHEN @P_M_BUKT_CD IN ('M', 'PW')	THEN MM ELSE 1 END
					 			   , CASE WHEN @P_M_BUKT_CD IN ('PW', 'W') THEN DP_WK ELSE 1 END
					 		)
							MERGE INTO TB_DP_MEASURE_DATA TGT
							 USING (
									SELECT YR.ITEM_MST_ID
										 , YR.ACCOUNT_ID
										 , MC.STRT_DATE AS BASE_DATE 
										 , YR.QTY	/ YC.DATE_CNT * MC.DATE_CNT	AS QTY
										 , YR.AMT	/ YC.DATE_CNT * MC.DATE_CNT	AS AMT
									  FROM Y_CAL  YC
										   INNER JOIN
										   #TMP_RT  YR
										ON YR.BASE_DATE = YC.STRT_DATE --BETWEEN YC.STRT_DATE AND YC.END_DATE
										   INNER JOIN
										   M_CAL MC
										ON MC.STRT_DATE BETWEEN YC.STRT_DATE AND YC.END_DATE
										   INNER JOIN 
										   TB_DP_ACCOUNT_MST AM -- 24.07.18 본사 사업계획 제외
										ON YR.ACCOUNT_ID = AM.ID
									 WHERE AM.ATTR_01 != '1000'
								--	ORDER BY YR.ITEM_MST_ID, YR.ACCOUNT_ID, YR.BASE_DATE
								) SRC
							ON TGT.ITEM_MST_ID = SRC.ITEM_MST_ID
						   AND TGT.ACCOUNT_ID = SRC.ACCOUNT_ID
						   AND TGT.BASE_DATE = SRC.BASE_DATE
						   WHEN MATCHED THEN
						   UPDATE SET ANNUAL_QTY = SRC.QTY
									 ,ANNUAL_AMT = SRC.AMT 
									 ,MODIFY_BY = @P_USER_ID
									 ,MODIFY_DTTM = GETDATE()
						   WHEN NOT MATCHED THEN 
						   INSERT 
						   ( ID
							,ITEM_MST_ID
							,ACCOUNT_ID   
							,BASE_DATE
							,ANNUAL_QTY
							,ANNUAL_AMT
							,CREATE_BY 
							,CREATE_DTTM
						   ) VALUES
						   ( REPLACE(NEWID(),'-','')
							,SRC.ITEM_MST_ID
							,SRC.ACCOUNT_ID
							,SRC.BASE_DATE
							,SRC.QTY
							,SRC.AMT
							,@P_USER_ID
							,GETDATE()   
						   )
							;
					END

			END	 
	IF (@P_DP_CL_STATUS = 'CUTOFF' AND @P_CL_MODULE_TP IN ('ALL', 'SCP', 'SCP2'))
		BEGIN
				DELETE
				  FROM TB_DP_ENTRY_CUTOFF 
				 WHERE CUTOFF_VER_CD = @p_CUTOFF_VER_CD 		
				 ;
				 INSERT INTO TB_DP_ENTRY_CUTOFF  
							(ID
							,PLAN_TP_ID
							, VER_ID
							, CUTOFF_VER_CD
							, AUTH_TP_ID
							, ITEM_MST_ID
							, ACCOUNT_ID
							, EMP_ID
							, BASE_DATE
							, QTY
							, QTY_1
							, QTY_2
							, QTY_3
							, AMT
							, AMT_1
							, AMT_2
							, AMT_3
							, CREATE_BY
							, CREATE_DTTM
							)
					select   REPLACE(NEWID(),'-','')
						   , @P_PLAN_TP_ID
						   , @P_VER_ID
						   , @p_CUTOFF_VER_CD as CUTOFF_VER_CD
						   , @P_CL_LV_MGMT_ID
						   , ITEM_MST_ID
						   , ACCOUNT_ID
						   , EMP_ID
						   , BASE_DATE
						   , QTY
						   , QTY_1
						   , QTY_2
						   , QTY_3
						   , AMT
						   , AMT_1
						   , AMT_2
						   , AMT_3
						   , @p_USER_ID as  CREATE_BY
						   , GETDATE()
					from #TMP_RT 
			END

	/*********************************************************************************************************
		-- Demand Overview Ship Date
	*********************************************************************************************************/
		UPDATE A
		SET A.SHMT_DATE = B.SHMT_DATE
		FROM TB_CM_DEMAND_OVERVIEW A
		,(
		SELECT
		D.T3SERIES_VER_ID
		, D.DUE_DATE
		, DATEADD(DAY, -B.LT, D.DUE_DATE) AS SHMT_DATE
		, D.DMND_ID
		FROM TB_CM_DEMAND_OVERVIEW D
		, VW_LOCAT_BOD_LT B
		WHERE 1=1
		AND D.REQUEST_SITE_ID = B.LOC_DTL_ID
		AND D.T3SERIES_VER_ID = @P_VER_CD
		) B
		WHERE 1=1
		AND A.T3SERIES_VER_ID = B.T3SERIES_VER_ID
		AND A.DMND_ID = B.DMND_ID

	/*********************************************************************************************************
		-- Change A Close Status of DP Version
	*********************************************************************************************************/
		UPDATE TB_DP_CONTROL_BOARD_VER_DTL
		  SET CL_STATUS_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_STATUS' AND CONF_CD = @P_DP_CL_STATUS) 
		     , CL_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_TP' AND CONF_CD = @P_CL_MODULE_TP)
			 , CL_LV_MGMT_ID = @P_CL_LV_MGMT_ID
			 , MODIFY_BY = @P_USER_ID
			 , MODIFY_DTTM = GETDATE() 
		 WHERE WORK_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_WK_TP' AND CONF_CD = 'CL') -- @P_WK_TP_ID 
		   AND CONBD_VER_MST_ID = @P_VER_ID 
	IF(@P_DP_CL_STATUS = 'CLOSE')
	BEGIN
		UPDATE TB_DP_CONTROL_BOARD_VER_MST 
		  SET MODIFY_DTTM = GETDATE() 
		 WHERE ID = @P_VER_ID 
		 ;
			/************************************************************************************************************
				-- Remove un-close version: when close
			************************************************************************************************************/
			--DECLARE @TMP_VER_MST TABLE ( ID CHAR(32))
			--INSERT @TMP_VER_MST (ID)
			--SELECT CONBD_VER_MST_ID
			--  FROM TB_DP_CONTROL_BOARD_VER_DTL 
			-- WHERE WORK_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_WK_TP' AND CONF_CD = 'CL')
			--   AND CL_STATUS_ID != (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_CL_STATUS' AND CONF_CD = 'CLOSE')
			--   AND PLAN_TP_ID = @P_PLAN_TP_ID
			--   ;
			--DELETE 
			--  FROM TB_DP_CONTROL_BOARD_VER_DTL 
			-- WHERE CONBD_VER_MST_ID IN (SELECT ID FROM @TMP_VER_MST)
			-- ;
			--DELETE 
			--  FROM TB_DP_CONTROL_BOARD_VER_MST 
			-- WHERE ID IN (SELECT ID FROM @TMP_VER_MST)
			--;
			--DELETE
			--  FROM TB_DP_CONTROL_BOARD_VER_INIT
			-- WHERE CONBD_VER_DTL_ID NOT IN (SELECT ID FROM TB_DP_CONTROL_BOARD_VER_DTL)
			-- ;
			-- DELETE 
			--   FROM TB_DP_ENTRY
			--  WHERE VER_ID IN (SELECT ID FROM @TMP_VER_MST)
			-- ;			
	   
			SELECT @P_MAIL_YN = CD.MAIL_YN 
			     --, @P_VER_CD  = 
			  FROM TB_DP_CONTROL_BOARD_VER_DTL CD
		        , (
				    SELECT B.ID AS ID, B.CONF_CD 
				      FROM TB_CM_CONFIGURATION A 
				           INNER JOIN TB_CM_COMM_CONFIG B  ON A.ID = B.CONF_ID 
					 WHERE A.MODULE_CD 		= 'DP'
					   AND B.ACTV_YN		= 'Y'
					   AND B.CONF_GRP_CD 	= 'DP_WK_TP' 
					   AND B.CONF_CD  		=  'CL'
					) CC
		    WHERE 1=1
		      AND CD.WORK_TP_ID = CC.ID 
		      AND CD.CONBD_VER_MST_ID = @P_VER_ID;
		     
		    IF @P_MAIL_YN = 'Y'
		    BEGIN
			    EXEC SP_UI_DP_SEND_MAIL @P_VER_CD, 'CL', NULL, NULL;
		    END

	END;
END
;


/*************************************************************** Refer ***************************************************************
		   SELECT 	   REQUEST_SITE_ID
		   			 , SALES_UNIT_PRIC
					 , DE.AMT / DE.QTY
					 , T3SERIES_VER_ID
					 , QTY 
					 , DMND_QTY
					 , DO.DESCRIP
 
			 , MARGIN
			 , BOD_LEADTIME
			 , TIME_UOM_ID
			 , PRDUCT_DELIVY_DATE
			 , ASSIGN_SITE_CNT
			 , ASSIGN_RES_CNT
			 , PST
			 , DUE_dATE
			 , DE.BASE_DATE 
			 , DELIVY_DATE
			 , DAYS_LATE
			 , PLAN_QTY
			 , LATE_QTY
			 , DELIVY_QTY
			 , ON_TIME_QTY
			 , SHRT_QTY
			 , PST
			 , DELIVY_DATE
			 , DAYS_LATE
			 , PLAN_QTY
			 , LATE_QTY
			 , DELIVY_QTY
			 , ON_TIME_QTY
			 , SHRT_QTY
			 , NETTING_QTY
			 , FORECAST_ID
			 , FORECAST_QTY
			 , SRC_DMND_ID
			 , DMND_LOCAT_ID
			 , HEURISTIC_YN
			 , STRATEGY_METHD_ID
			 , DISPLAY_COLOR			 
		     FROM TB_CM_DEMAND_OVERVIEW DO
				  INNER JOIN
				  TB_AD_COMN_CODE CC
			   ON DO.DMND_TP_ID = CC.ID  	
				  INNER JOIN 
				  (SELECT  CB.VER_ID, DE.BASE_DATE, DE.AMT, DE.ITEM_MST_ID, DE.ACCOUNT_ID, QTY 
				     FROM TB_DP_CONTROL_BOARD_VER_MST CB
						  INNER JOIN
						  TB_DP_CONTROL_BOARD_VER_DTL CD
					   ON CB.ID = CD.CONBD_VER_MST_ID
					  AND CB.PLAN_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_PLAN_TYPE' AND ATTR_01 = 'M')				  
					  AND VER_ID = 'DPM-20200320-004-00'
						  INNER JOIN
						  TB_DP_ENTRY DE
					   ON CB.ID = DE.VER_ID 
					  AND CD.CL_LV_MGMT_ID = DE.AUTH_TP_ID 							   
				  ) DE
 			   ON DO.T3SERIES_VER_ID = DE.VER_ID 	 
			  AND DO.ITEM_MST_ID = DE.ITEM_MST_ID
			  AND DO.ACCOUNT_ID =  DE.ACCOUNT_ID
			  AND DO.DUE_DATE = DE.BASe_DATE 
*******************************************************************************************************************************/			
END
GO
