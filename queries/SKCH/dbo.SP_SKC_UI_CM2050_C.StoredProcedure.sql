USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2050_C]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2050_C
-- COPYRIGHT                  ZIONEX
-- REMARK                     BOD L/T COPY
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-25  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2050_C] (
	 @P_VER_ID			   NVARCHAR(100)
   , @P_USER_ID            NVARCHAR(100)
   , @P_VIEW_ID			   NVARCHAR(100)
   , @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
   , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DECLARE
		  @P_USER_NM NVARCHAR(100)
	    , @P_ERR_STATUS INT = 0
        , @P_ERR_MSG NVARCHAR(4000)=''

BEGIN TRY
	BEGIN

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_CM2050_C' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_CM2050_C'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_VER_ID), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID ), '')	
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID ), '')	
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------


	SET @P_USER_NM = (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = @P_USER_ID);

		MERGE INTO TB_SKC_DP_BOD_MST A USING (
			SELECT PLNT_CD
				 , SHIP_CD
				 , CY_CD
				 , POL_CD
				 , POD_CD
				 , FD_CD
				 , CY_LT
				 , SHIP_CONF_LT
				 , LAND_CONF_LT
			  FROM TB_SKC_DP_BOD_MST_HIS
			 WHERE VER_ID = @P_VER_ID
		) B ON (A.PLNT_CD = B.PLNT_CD)
		WHEN MATCHED THEN 
		UPDATE 
		   SET A.SHIP_CD = B.SHIP_CD
		     , A.CY_CD = B.CY_CD
			 , A.POL_CD = B.POL_CD
			 , A.POD_CD = B.POD_CD
			 , A.FD_CD = B.FD_CD
			 , A.CY_LT = B.CY_LT
			 , A.SHIP_CONF_LT = B.SHIP_CONF_LT
			 , A.LAND_CONF_LT = B.LAND_CONF_LT
			 , A.MODIFY_BY = @P_USER_NM
			 , A.MODIFY_DTTM = GETDATE();

		
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
