USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2010_D1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2010_D1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요계획 단위 관리 삭제
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-29  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2010_D1] (
	 @P_ID				   NVARCHAR(100)
   , @P_USER_ID            NVARCHAR(100)
   , @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
   , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DECLARE  
		  @P_ERR_STATUS INT = 0
        , @P_ERR_MSG NVARCHAR(4000)=''

BEGIN TRY
	BEGIN
		DELETE FROM TB_DP_USER_ITEM_ACCOUNT_MAP
		 WHERE ID = @P_ID;
		 
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
