USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP2020_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP2020_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     고객 우선순위 관리 저장
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-19  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP2020_S1] (
	  @P_VER_ID				NVARCHAR(30)
	, @P_ID					NVARCHAR(32)
	, @P_STRTGY_YN			NVARCHAR(10)
	, @P_USER_ID			NVARCHAR(32)
	, @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
	)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;


---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_DP2020_S1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_DP2020_S1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ID), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(10) , @P_STRTGY_YN ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

DECLARE  
		 @P_ERR_STATUS INT = 0
        ,@P_ERR_MSG NVARCHAR(4000)=''
BEGIN TRY
	
	BEGIN
		UPDATE TB_SKC_DP_STRTGY_ACCOUNT_MST 
		   SET STRTGY_YN = @P_STRTGY_YN
			 , MODIFY_BY = @P_USER_ID
			 , MODIFY_DTTM = GETDATE()
		 WHERE ID = @P_ID
		   AND VER_ID = @P_VER_ID;

		MERGE INTO TB_SKC_DP_STRTGY_ACCOUNT_MST A USING (
			SELECT ID
				 , STRTGY_YN
				 , CASE WHEN STRTGY_YN = 'Y' THEN '1'
						WHEN STRTGY_YN = 'N' AND ANNUAL_YN = 'Y' THEN '2'
						ELSE '3' END AS PRIORT
			  FROM TB_SKC_DP_STRTGY_ACCOUNT_MST
			 WHERE VER_ID = @P_VER_ID
		) B ON (A.ID = B.ID)
		WHEN MATCHED THEN 
		UPDATE SET A.PRIORT = B.PRIORT;

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
