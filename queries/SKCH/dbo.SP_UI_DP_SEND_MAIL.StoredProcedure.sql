USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_UI_DP_SEND_MAIL]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_UI_DP_SEND_MAIL] 
(	
    @P_VER_CD			NVARCHAR(50) --	= (SELECT TOP 1 ver_ID FROM TB_DP_CONTROL_BOARD_VER_MST ORDER BY CREATE_DTTM DESC)
  ,	@P_WORK_TP_CD   	CHAR(32)
  , @P_LV_MGMT_ID       CHAR(32) = ''	-- 승인한 권한의 레벨 
  , @P_USER_CD			NVARCHAR(100)
) AS 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
/*****************************************************************************************************************************
	[SP_UI_DP_SEND_MAIL]

	History ( Date / Writer / Comment )
	- 2024.**.** / kim sung yong / draft
	- 2024.07.23 / kim sohee /  check team approval status
		(1) 영업사원 전체 승인해야 다음 레벨 팀장에게 메일 발송
		(2) 그 외, 우리 팀 영업사원이 전체 승인한 시점에 우리 팀에 메일 발송
******************************************************************************************************************************/
	DECLARE @P_MAIL_YN 	  			CHAR(1);
	DECLARE @P_MAIL_SENDER 	  		NVARCHAR(50);
    DECLARE @P_USER_ID_TO_MAIL   	NVARCHAR(500);
	DECLARE @P_CNTRL_CREATE_ID 	  	CHAR(32);
    DECLARE @P_MAIL_TEMPLATE   	  	NVARCHAR(MAX);
    DECLARE @P_MAIL_TEMPLATE_ID   	CHAR(32);
    DECLARE @P_LANG_CD              NVARCHAR(10) = 'ko';
	DECLARE @P_LANG_PACK_CONTENT    NVARCHAR(MAX); -- CONTENT 
	DECLARE @P_LANG_PACK_HEADER     NVARCHAR(MAX); -- HEADER 
	DECLARE @P_LANG_PACK_TITLE      NVARCHAR(MAX); -- TITLE
	DECLARE @P_STRT_DATE			NVARCHAR(10);
	DECLARE @P_END_DATE				NVARCHAR(10);
	DECLARE @P_DP_STRT_DATE			NVARCHAR(10);
	DECLARE @P_DP_END_DATE			NVARCHAR(10);
	DECLARE @P_DP_PART_FROM_DATE	NVARCHAR(10);
	DECLARE @P_DP_PART_TO_DATE		NVARCHAR(10);

	CREATE TABLE #TEMP_USER_HIER
	(
	  ANCS_ROLE_ID	CHAR(32)
	, ANCS_ROLE_CD	NVARCHAR(100)  COLLATE Korean_Wansung_CI_AI
	, ANCS_ID		CHAR(32)	   COLLATE Korean_Wansung_CI_AI
	, DESC_ID		CHAR(32)	   COLLATE Korean_Wansung_CI_AI
	, DESC_CD		NVARCHAR(100)  COLLATE Korean_Wansung_CI_AI
	)

	-- TITLE --
	SELECT @P_LANG_PACK_TITLE = LANG_VALUE
	  FROM TB_AD_LANG_PACK
	 WHERE 1=1
	   AND LANG_CD = @P_LANG_CD --'ko'
	   AND LANG_KEY = 'DP_MSG_MAIL_TEMPLATE_TITLE'
	;
	-- HEADER --
	SELECT @P_LANG_PACK_HEADER = LANG_VALUE
	  FROM TB_AD_LANG_PACK
	 WHERE 1=1
	   AND LANG_CD = @P_LANG_CD --'ko'
	   AND LANG_KEY = 'DP_MSG_MAIL_TEMPLATE_HEADER'
	;   
	
	-- CONTENT --
	SELECT @P_LANG_PACK_CONTENT = REPlACE(LANG_VALUE, '#', '(' + @P_VER_CD + ')')
     FROM TB_AD_LANG_PACK
    WHERE 1=1
      AND LANG_CD = @P_LANG_CD --'ko'
      AND LANG_KEY = CASE WHEN @P_WORK_TP_CD = 'VC' THEN 'DP_MSG_MAIL_TEMPLATE_CREATE'
                          WHEN @P_WORK_TP_CD = 'CL' THEN 'DP_MSG_MAIL_TEMPLATE_CLOSE'
                          WHEN @P_WORK_TP_CD = 'DP' THEN 'DP_MSG_MAIL_TEMPLATE_APPROVE'
                          END 
     ;
	    
   SELECT @P_STRT_DATE = V_DATE
		 , @P_END_DATE = DATEADD(DAY, 7, V_DATE)
	  FROM (SELECT TOP 1 CONVERT(DATE, CREATE_DTTM, 112) AS V_DATE
			  FROM TB_DP_CONTROL_BOARD_VER_DTL
			 WHERE CONBD_VER_MST_ID = (SELECT ID FROM TB_DP_CONTROL_BOARD_VER_MST WHERE VER_ID = @P_VER_CD)) A
						 
	SELECT @P_DP_STRT_DATE = CONVERT(DATE, FROM_DATE, 112)
		 , @P_DP_END_DATE = CONVERT(DATE, TO_DATE, 112)
		 , @P_DP_PART_FROM_DATE = CONVERT(DATE, DATEADD(DAY, -1, VER_S_HORIZON_DATE), 112)
		 , @P_DP_PART_TO_DATE = CONVERT(DATE, VER_S_HORIZON_DATE, 112)
	  FROM TB_DP_CONTROL_BOARD_VER_MST 
	 WHERE VER_ID = @P_VER_CD;

	IF @P_WORK_TP_CD = 'VC'
	BEGIN
		SET @P_LANG_PACK_TITLE = 'DP 버전 생성 알림 / DP Version Creation Notification';

	    SET @P_MAIL_TEMPLATE = '<p>DP 버전 (' + @P_VER_CD + ')이 생성되었습니다.	</p>
		<p><br></p>	<p>	<b>1.	수요계획 입력 일정</b> / Demand Plan Input Period	<br>	&nbsp;&nbsp;- ' + @P_STRT_DATE + ' ~ ' + @P_END_DATE + ' 	</p>
		<p><br></p>	<p>	<b>2.	수요계획 입력 구간</b> / Demand Plan Horizon & bucket	<br>	&nbsp;&nbsp;- Horizon : ' + @P_DP_STRT_DATE + ' ~ ' + @P_DP_END_DATE + '
		<br>	&nbsp;&nbsp;- Bucket : ' + @P_DP_STRT_DATE + ' ~ ' + COALESCE(@P_DP_PART_FROM_DATE, '') + ' Weekly, ' + COALESCE(@P_DP_PART_TO_DATE, '') + ' ~ ' + COALESCE(@P_DP_END_DATE, '') + ' Monthly	</p>
		<p><br></p>	<p>	<b>3.	수요계획 입력 기준</b> / Demand Plan input criteria 	<br>	&nbsp;&nbsp;- 매출 발생 주차 기준 / Expected Billing week & Month 
		<br>	&nbsp;&nbsp;&nbsp;1) 국내 : 공장 출하 / Domestic : Retrieval from HQ Plant 
		<br>	&nbsp;&nbsp;&nbsp;2) 본사 직수출, 일본, SOI (Plant 1110) : 선적 예정일 / HQ Direct Export, JP, SOI : ETD
		<br>	&nbsp;&nbsp;&nbsp;3) 미주, 상해 : 창고 출고일 / SKCA, Shanghai Corp : Retrieval from WH
		<br>	&nbsp;&nbsp;&nbsp;4) 유럽 : 창고 출고일, 고객 납기일 / SKCG : Retrieval from WH or Deliver to Final Destination	</p>
		<p><br></p>	<p>	<b>4.	기준정보 관리</b> / Master data update 
		<br>	&nbsp;&nbsp;- 신규 제품 : MDM 제품 Master에 DP 입력 시작 2일 전까지 반영 완료 / Item : MDM Master update at least 2 days before the DP entry start date.  
		<br>	&nbsp;&nbsp;- 신규 매출처 : MDM, ERP 고객 Master에 DP 입력 시작 2일 전까지 반영 완료 / Account : MDM Master update at least 2 days before the DP entry start date. 
		<br>	&nbsp;&nbsp;- 신규 수요계획 수립 단위 및 BOD 정보 생성은 DP 입력 시작 1일 전까지 반영 완료 / Demand Planning Unit master update at least 1 days before the DP entry start date
		<br>	&nbsp;&nbsp;&nbsp;<b>* MDM 제품, 매출처 Master에 반영되어 있지 않은 수요계획 수립 단위는 당월 DP 반영 불가 </b>	</p>
		<p><br></p>	<p>	<b>5.	담당자 권한 위임</b> / Delegation of authority to person in charge 
		<br>	&nbsp;&nbsp;- 출장/휴가 등으로 인한 담당자 부재 時 S&OP팀에 DP 입력 시작일 1일 전까지 안내 
		<br>	&nbsp;&nbsp;/ When the person in charge is absent due to business trip/vacation. Please, inform the S&OP team at least 1 day before the DP entry start date. 
		<br>	&nbsp;&nbsp;- S&OP DP Planner가 DP 버전 배포 전 담당자 입력 권한 위임 완료 후 배포 예정  
		<br>	&nbsp;&nbsp;/ S&OP DP Planner is scheduled to be distributed after completing delegation of input authority to the person in charge before distributing the DP version. 
		</p>
		'
   END
   ELSE
   BEGIN
		SET @P_MAIL_TEMPLATE = @P_LANG_PACK_CONTENT;
   END
  		
   SELECT  @P_MAIL_YN = CB.MAIL_YN 
     	 ,  @P_USER_ID_TO_MAIL = CB.USER_ID_TO_MAIL
	  FROM	TB_DP_CONTROL_BOARD_VER_DTL CB 
	        INNER JOIN TB_DP_CONTROL_BOARD_VER_MST VM
	    ON  CB.CONBD_VER_MST_ID =  VM.ID AND CB.PLAN_TP_ID = VM.PLAN_TP_ID AND VM.VER_ID = @P_VER_CD
			INNER JOIN 
			(
			    SELECT B.ID AS ID, B.CONF_CD 
			      FROM TB_CM_CONFIGURATION A 
			           INNER JOIN TB_CM_COMM_CONFIG B  ON A.ID = B.CONF_ID 
				 WHERE A.MODULE_CD 		= 'DP'
				   AND B.ACTV_YN		= 'Y'
				   AND B.CONF_GRP_CD 	= 'DP_WK_TP' 
				   AND B.CONF_CD  		=  @P_WORK_TP_CD
			) CC
		ON CB.WORK_TP_ID = CC.ID 
	 WHERE  1=1	
	    AND  COALESCE(CB.LV_MGMT_ID, '') = CASE WHEN @P_WORK_TP_CD = 'DP' THEN @P_LV_MGMT_ID
			                               ELSE ''
			                               END
  	  		   
	IF @P_MAIL_YN = 'Y'
	
		BEGIN
			   SELECT  @P_MAIL_TEMPLATE_ID = REPLACE(NEWID(),'-','');
			  
			 --  SELECT @P_MAIL_SENDER = B.ATTR_01
			 --    FROM TB_CM_CONFIGURATION A 
			 --         INNER JOIN TB_CM_COMM_CONFIG B  ON A.ID = B.CONF_ID 
				--WHERE A.MODULE_CD 		= 'DP'
				--  AND B.ACTV_YN			= 'Y'
				--  AND B.CONF_GRP_CD 	= 'DP_MAIL_SENDER' 
			 --  ;

			   SELECT @P_MAIL_SENDER = ATTR_01_VAL 
			     FROM TB_AD_COMN_CODE
				 WHERE SRC_ID = (SELECT ID FROM TB_AD_COMN_GRP WHERE GRP_CD = 'DP_MAIL_SENDER');

			  -- MAIL RECIEVER USRES --
			IF @P_WORK_TP_CD = 'VC'
				   BEGIN 
					   -- MAIL FORMAT --
					  INSERT INTO TB_UT_MAIL (MAIL_ID , SENDER, title, CONTENT, CONTENT_TP, STATUS, CREATE_BY,  CREATE_DTTM) 
					  VALUES (@P_MAIL_TEMPLATE_ID, COALESCE(@P_MAIL_SENDER, 'test@test.com'), @P_LANG_PACK_TITLE, @P_MAIL_TEMPLATE, 'HTML', 0, 'DP', GETDATE())
					  ;
					    WITH AUTHTYPE AS (
							SELECT L.ID, L.LV_CD, ROW_NUMBER() OVER ( ORDER BY M.SEQ) AS RW
							FROM
							    TB_DP_CONTROL_BOARD_MST M
							INNER JOIN TB_CM_LEVEL_MGMT L ON
							    L.ID = M.LV_MGMT_ID
							WHERE
							    PLAN_TP_ID = (
							    SELECT
							        ID
							    FROM
							        TB_CM_COMM_CONFIG
							    WHERE
							        CONF_GRP_CD = 'DP_PLAN_TYPE'
							        AND CONF_CD = 'DP_PLAN_MONTHLY')
							    AND LV_MGMT_ID IS NOT NULL 
						), FIRSTLEVELUSER AS ( -- CREATE
							SELECT
							    C.DESC_CD AS USERNAME
							FROM
							    TB_DPD_USER_HIER_CLOSURE C
							INNER JOIN AUTHTYPE A ON
							    A.RW = 1
							    AND A.LV_CD = C.DESC_ROLE_CD
							    AND C.DESC_ROLE_CD = C.ANCS_ROLE_CD 
						), CREATE_USER AS (
						    SELECT VALUE AS ID FROM STRING_SPLIT(@P_USER_ID_TO_MAIL,',')
						 --   UNION -- 24.07.05 모든 마케터 메일 수신 불필요
							--SELECT
							--    ID
							--FROM
							--    FIRSTLEVELUSER FU
							--INNER JOIN TB_AD_USER U ON
							--    U.USERNAME = FU.USERNAME
							--    AND EMAIL IS NOT NULL
						)
						
					   	INSERT INTO TB_UT_MAIL_RECIEVER (MAIL_ID, SEQ, EMAIL, USER_ID, RECIEVER_TP, CREATE_BY, CREATE_DTTM) 
						SELECT @P_MAIL_TEMPLATE_ID
					   	    , ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
					   	    , AU.EMAIL
					     	, AU.USERNAME
					        , 'T'
					        , 'DP'
					        , GETDATE()
						 FROM TB_AD_USER AU
						    , CREATE_USER CU
						WHERE 1=1	
						  AND AU.ID = CU.ID
				   END
				   
			IF @P_WORK_TP_CD = 'DP'
				   BEGIN 
						DECLARE @P_AUTH_TP_CD		NVARCHAR(50) = (SELECT LV_CD FROM TB_CM_LEVEL_MGMT WHERE ID = @P_LV_MGMT_ID)
							 ,  @P_IS_ALL_APPROVAL	INT			 = 0
							 ,  @P_REGION			NVARCHAR(30) = NULL
							 ;

						WITH ANCS_USER
						AS (SELECT ANCS_ID, ANCS_ROLE_ID
							  FROM TB_DPD_USER_HIER_CLOSURE
							 WHERE CASE WHEN @P_USER_CD IS NULL THEN COALESCE(@P_USER_CD,'ALL') ELSE DESC_CD END = COALESCE(@P_USER_CD,'ALL')
							   AND DESC_ROLE_CD = @P_AUTH_TP_CD
						), USER_HIERARCHY
						AS (SELECT UH.ANCS_ROLE_ID, ANCS_ROLE_CD, ANCS_ID, DESC_ID, DESC_CD 
								 , ROW_NUMBER() OVER (PARTITION BY DESC_ID ORDER BY LV.SEQ  DESC) AS SEQ
							  FROM TB_DPD_USER_HIER_CLOSURE UH
								   INNER JOIN 
								   TB_CM_LEVEL_MGMT LV
							   ON UH.ANCS_ROLE_ID = LV.ID	
							  AND LV.ACTV_YN = 'Y'
							  AND COALESCE(LV.DEL_YN,'N') = 'N'
								   INNER JOIN 
								   TB_DP_CONTROL_BOARD_VER_DTL VD
							   ON UH.ANCS_ROLE_ID = VD.LV_MGMT_ID
								  INNER JOIN 
								  TB_DP_CONTROL_BOARD_VER_MST VM 
							   ON VD.CONBD_VER_MST_ID = VM.ID 
							  AND VM.VER_ID = @P_VER_CD 
							WHERE DESC_ROLE_CD = @P_AUTH_TP_CD		  
							  AND UH.ANCS_ROLE_CD != UH.DESC_ROLE_CD
--							  AND COALESCE(@P_USER_CD,'ALL')  = CASE WHEN @P_USER_CD IS NULL THEN COALESCE(@P_USER_CD,'ALL')  ELSE DESC_CD END
						)
						INSERT INTO #TEMP_USER_HIER 
						(  ANCS_ROLE_ID
						 , ANCS_ROLE_CD
						 , ANCS_ID		
						 , DESC_ID
						 , DESC_CD				 
						)
						SELECT UH.ANCS_ROLE_ID		AS ANCS_ROLE_ID
							 , ANCS_ROLE_CD			AS ANCS_ROLE_CD
							 , UH.ANCS_ID			AS ANCS_ID		
							 , DESC_ID				AS DESC_ID
							 , DESC_CD 				AS DESC_CD				 
						  FROM USER_HIERARCHY UH 
							   INNER JOIN
							   ANCS_USER AU	-- User info of My parents level
							ON UH.ANCS_ID = AU.ANCS_ID
						   AND UH.ANCS_ROLE_ID = AU.ANCS_ROLE_ID -- 내 매핑정보가 없는 상위 사용자가, 자신보다 상위인 사용자한테 값을 넘겨주는경우?
						 WHERE UH.SEQ = 1 
						 ;
						
						SELECT @P_REGION = SALES_LV_NM FROM TB_DP_SALES_LEVEL_MGMT WHERE ID = (SELECT SALES_LV_ID FROM TB_DP_SALES_AUTH_MAP WHERE EMP_ID = (SELECT DISTINCT ANCS_ID FROM #TEMP_USER_HIER))

						   SET @P_LANG_PACK_TITLE = 'DP 버전 승인 알림';
						   SET @P_MAIL_TEMPLATE = '<p>DP 버전 (' + @P_VER_CD + ') ' + @P_REGION + ' 수요 입력이 완료 되었습니다. </p>
												   <p><br></p>	
												   <p>수요계획 검토 및 승인 바로가기 
												   <a href="https://gscm.skchemicals.com/">GC SCM 시스템 접속</a></p>';
						WITH PRC_STA
						AS (
							SELECT OPERATOR_ID AS OPERATOR_ID
								 , [STATUS]		AS STA
								 , ROW_NUMBER() OVER (PARTITION BY OPERATOR_ID ORDER BY STATUS_DATE DESC)  AS RW 
							  FROM TB_DP_PROCESS_STATUS_LOG
							 WHERE VER_CD= @p_VER_CD
							   AND AUTH_TYPE = @P_AUTH_TP_CD
						)
							SELECT DISTINCT @P_IS_ALL_APPROVAL = 1
							  FROM #TEMP_USER_HIER UH
								   LEFT OUTER JOIN 
								   PRC_STA PS 
								ON PS.OPERATOR_ID = UH.DESC_CD
							   AND PS.RW = 1
							   AND PS.STA = 'APPROVAL'
						  GROUP BY UH.ANCS_ROLE_CD
							HAVING COUNT(PS.STA) = COUNT(UH.DESC_CD)							
							;
						IF @P_IS_ALL_APPROVAL = 1 OR @P_USER_CD IS NULL 
							BEGIN
							   -- MAIL FORMAT --
							  INSERT INTO TB_UT_MAIL (MAIL_ID , SENDER, title, CONTENT, CONTENT_TP, STATUS, CREATE_BY,  CREATE_DTTM) 
							  VALUES (@P_MAIL_TEMPLATE_ID, COALESCE(@P_MAIL_SENDER, 'test@test.com'), @P_LANG_PACK_TITLE, @P_MAIL_TEMPLATE, 'HTML', 0, 'DP', GETDATE())
							  ;
								WITH APPROVE_USER AS (
									SELECT VALUE AS ID 
									  FROM STRING_SPLIT(@P_USER_ID_TO_MAIL,',')
									 UNION
									SELECT ID 
									  FROM TB_AD_USER AU
										   INNER JOIN 
										   #TEMP_USER_HIER LU
										ON AU.ID  = LU.ANCS_ID								 
								)
					   			INSERT INTO TB_UT_MAIL_RECIEVER (MAIL_ID, SEQ, EMAIL, USER_ID, RECIEVER_TP, CREATE_BY, CREATE_DTTM) 
								SELECT @P_MAIL_TEMPLATE_ID
					   				, ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
					   				, AU.EMAIL
					     			, AU.USERNAME
									, 'T'
									, 'DP'
									, GETDATE()
								 FROM TB_AD_USER AU
									  INNER JOIN 
									  APPROVE_USER PU
								   ON AU.ID = PU.ID
								  ;
							END 


				   END
			 IF @P_WORK_TP_CD = 'CL'
			 	BEGIN 
					   -- MAIL FORMAT --
					  INSERT INTO TB_UT_MAIL (MAIL_ID , SENDER, title, CONTENT, CONTENT_TP, STATUS, CREATE_BY,  CREATE_DTTM) 
					  VALUES (@P_MAIL_TEMPLATE_ID, COALESCE(@P_MAIL_SENDER, 'test@test.com'), @P_LANG_PACK_TITLE, @P_MAIL_TEMPLATE, 'HTML', 0, 'DP', GETDATE())
					  ;
				   	   INSERT INTO TB_UT_MAIL_RECIEVER (MAIL_ID, SEQ, EMAIL, USER_ID, RECIEVER_TP, CREATE_BY, CREATE_DTTM) 
					   SELECT @P_MAIL_TEMPLATE_ID
					   	    , ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
					   	    , AU.EMAIL
					     	, AU.USERNAME
					        , 'T'
					        , 'DP'
					        , GETDATE()
						 FROM TB_AD_USER AU 
						WHERE 1=1
						  AND AU.ID = (SELECT value FROM STRING_SPLIT(@P_USER_ID_TO_MAIL,','))
			 	END


		 END

		 DROP TABLE #TEMP_USER_HIER ;
GO
