USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2050_R]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2050_R
-- COPYRIGHT                  ZIONEX
-- REMARK                     BOD L/T 원복
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-06-26  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2050_R] (
	 @P_USER_ID            NVARCHAR(100)
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

	SET @P_USER_NM = (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = @P_USER_ID);

	BEGIN
		--IF EXISTS (SELECT 1 FROM TB_DP_SALES_AUTH_MAP WHERE SALES_LV_ID = (SELECT ID FROM TB_DP_SALES_LEVEL_MGMT WHERE SALES_LV_CD = 'ALL') AND EMP_ID = @P_USER_ID)
		IF EXISTS (SELECT 1 
					 FROM TB_AD_AUTHORITY A 
					INNER JOIN TB_AD_USER B
					   ON A.USER_ID = B.ID
					WHERE AUTHORITY = 'ADMIN' 
					  AND DISPLAY_NAME = @P_USER_NM)
			BEGIN
				MERGE INTO TB_SKC_DP_BOD_MST A USING (
					SELECT A.ID
						 , ROUND(B.SEA_LEAD_TIME, 0) AS SHIP_CONF_LT
						 , ROUND(B.LAND_LEAD_TIME, 0) AS LAND_CONF_LT
					  FROM TB_SKC_DP_BOD_MST A
					  LEFT JOIN (SELECT DISTINCT POL_CD, POD_CD, PLNT_CD, SEA_LEAD_TIME, LAND_LEAD_TIME FROM TB_SKC_BOD_MST) B
						ON A.POL_CD = B.POL_CD
					   AND A.POD_CD = B.POD_CD
					   AND A.PLNT_CD = B.PLNT_CD
				) B ON (A.ID = B.ID)
				WHEN MATCHED THEN 
				UPDATE 
				   SET A.SHIP_CONF_LT = B.SHIP_CONF_LT, A.LAND_CONF_LT = B.LAND_CONF_LT, A.MODIFY_BY = @P_USER_NM, A.MODIFY_DTTM = GETDATE();
			END
		ELSE
			BEGIN
				SET @P_ERR_MSG = 'MSG_SKC_018' 
				RAISERROR (@P_ERR_MSG,12, 1);	
			END
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
