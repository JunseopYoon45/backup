USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP1030_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP1030_Q2
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 수정 요청 메일 발송
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-05-20  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP1030_Q2] (
	  @P_VER_ID				NVARCHAR(50) 
	, @P_EMP_CD				NVARCHAR(MAX)	
	, @P_MANAGER_CD			NVARCHAR(6)		  
	, @P_TITLE				NVARCHAR(MAX)
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
	 WHERE USERNAME = @P_MANAGER_CD;

	IF @P_TITLE IS NULL	SET @P_TITLE = @P_MAIL_SENDER_NM+'_수요 수정 요청 드립니다_'+@P_VER_ID 

	--SET @P_MAIL_TEMPLATE = '<html><head></head><body><div style="height: 100%; background: #f5f5f5"><center><table cellspacing="0" cellpadding="0" style="border-radius: 5px;min-width: 340px;background: #fff;margin: 0 auto;margin-left: 20px;margin-right: 20px;margin-bottom: 0px;border: 1px solid #ddd;font-size: 14px;font-family: AppleSDGothic, 나눔고딕, Dotum, Baekmuk Dotum, Undotum,Latin font, sans-serif;line-height: 160%;"><tbody><tr><td style="background: #2d3a45;border-top-left-radius: 5px;border-top-right-radius: 5px;height: 32px;padding-left: 15px;"><span style="font-size: 11pt;color: #fff;float: left;text-align: left;display: inline;color: #fff;margin-left: 0;min-width: 300px;position: relative;">' + @P_LANG_PACK_HEADER + '</span></td></tr><tr><td style="word-break: break-all;border-bottom: 1px solid #cccccc;max-width: 640px;margin-bottom: 4px;padding: 20px;padding-left: 25px;padding-bottom: 4px;min-height: 354px;"><p style="margin: 6px !important; text-align: left !important">' + @P_CONTENT + '</p></td></tr></tbody></table></center></div></body></html>';
	SET @P_MAIL_TEMPLATE = @P_CONTENT

	SELECT @P_MAIL_TEMPLATE_ID = REPLACE(NEWID(),'-','');
			  
	SELECT @P_MAIL_SENDER = EMAIL
	  FROM TB_AD_USER
	 WHERE USERNAME = @P_MANAGER_CD;


	--SELECT USERNAME, EMAIL
	--  FROM TB_AD_USER
	-- WHERE USERNAME IN (SELECT VALUE AS ID FROM STRING_SPLIT(@P_EMP_CD,','));
			  
	-- MAIL FORMAT --
	INSERT INTO TB_UT_MAIL (MAIL_ID , SENDER, title, CONTENT, CONTENT_TP, STATUS, CREATE_BY,  CREATE_DTTM) 
	VALUES (@P_MAIL_TEMPLATE_ID, COALESCE(@P_MAIL_SENDER, 'test@test.com'), @P_TITLE, @P_MAIL_TEMPLATE, 'HTML', 0, 'DP', GETDATE())

	INSERT INTO TB_UT_MAIL_RECIEVER (MAIL_ID, SEQ, EMAIL, USER_ID, RECIEVER_TP, CREATE_BY, CREATE_DTTM) 
		SELECT @P_MAIL_TEMPLATE_ID
			, ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
			, EMAIL
			, USERNAME
			, 'T'
			, 'DP'
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
