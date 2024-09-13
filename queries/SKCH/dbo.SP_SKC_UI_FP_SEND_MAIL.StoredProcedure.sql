USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP_SEND_MAIL]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_FP_SEND_MAIL
-- COPYRIGHT                  ZIONEX
-- REMARK                     생산계획 검토 요청/배포 메일 발송
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP_SEND_MAIL] (
	  @P_EMP_CD				NVARCHAR(MAX)	
	, @P_USER_ID			NVARCHAR(100)
	, @P_TITLE				NVARCHAR(MAX)  = NULL
	, @P_CONTENT			NVARCHAR(MAX)
	, @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

	DECLARE @P_MAIL_YN 	  			CHAR(1);
	DECLARE @P_MAIL_SENDER 	  		NVARCHAR(50);
	DECLARE @P_MAIL_SENDER_NM		NVARCHAR(100);
    DECLARE @P_USER_ID_TO_MAIL   	NVARCHAR(500);
	DECLARE @P_CNTRL_CREATE_ID 	  	CHAR(32);
    DECLARE @P_MAIL_TEMPLATE   	  	NVARCHAR(MAX);
    DECLARE @P_MAIL_TEMPLATE_ID   	CHAR(32);
	DECLARE @P_LANG_PACK_CONTENT    NVARCHAR(MAX); -- CONTENT 
	DECLARE @P_LANG_PACK_HEADER     NVARCHAR(MAX); -- HEADER 
	DECLARE @P_ERR_STATUS			INT = 0;
	DECLARE @P_ERR_MSG				NVARCHAR(4000)='';


BEGIN TRY
	BEGIN
	
	SELECT @P_MAIL_SENDER_NM = DISPLAY_NAME
	  FROM TB_AD_USER
	 WHERE USERNAME = @P_USER_ID;

	IF @P_TITLE IS NULL	SET @P_TITLE = @P_MAIL_SENDER_NM+'_생산 계획 검토 요청/배포 드립니다'

	SET @P_MAIL_TEMPLATE = @P_CONTENT

	SELECT @P_MAIL_TEMPLATE_ID = REPLACE(NEWID(),'-','');
			  
	SELECT @P_MAIL_SENDER = EMAIL
	  FROM TB_AD_USER
	 WHERE USERNAME = @P_USER_ID;

			  
	-- MAIL FORMAT --
	INSERT INTO TB_UT_MAIL (MAIL_ID , SENDER, title, CONTENT, CONTENT_TP, STATUS, CREATE_BY,  CREATE_DTTM) 
	VALUES (@P_MAIL_TEMPLATE_ID, COALESCE(@P_MAIL_SENDER, 'test@test.com'), @P_TITLE, @P_MAIL_TEMPLATE, 'HTML', 0, 'FP', GETDATE())

	INSERT INTO TB_UT_MAIL_RECIEVER (MAIL_ID, SEQ, EMAIL, USER_ID, RECIEVER_TP, CREATE_BY, CREATE_DTTM) 
		SELECT @P_MAIL_TEMPLATE_ID
			, ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
			, EMAIL
			, USERNAME
			, 'T'
			, 'FP'
			, GETDATE()
	     FROM TB_AD_USER
		WHERE USERNAME IN (SELECT VALUE AS ID FROM STRING_SPLIT(@P_EMP_CD,','));

    -----------------------------------
    -- 저장메시지
    -----------------------------------
    IF  @@TRANCOUNT > 0 COMMIT TRANSACTION
        SET @P_RT_ROLLBACK_FLAG = 'TRUE';
        SET @P_RT_MSG           = 'MSG_SKC_007';  --메일 발송 성공.
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
