USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2050_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2050_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     BOD 관리 수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-01  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2050_S1] (
	 @P_WORK_TYPE          NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
   , @P_ID				   NVARCHAR(100) 
   , @P_SHIP			   NVARCHAR(100) = NULL
   , @P_ARR_PORT		   NVARCHAR(100) = NULL
   , @P_DLVR_LOC		   NVARCHAR(100) = NULL
   , @P_CY_LT			   INT			 = NULL
   , @P_SHIP_CONF_LT	   INT			 = NULL
   , @P_LAND_CONF_LT	   INT			 = NULL
   , @P_USER_ID            NVARCHAR(100)
   , @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
   , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DECLARE  
		  @P_SHIP_CD VARCHAR(10)
		, @P_POD_CD VARCHAR(10)
		, @P_FD_CD	VARCHAR(10)
		, @P_ERR_STATUS INT = 0
        , @P_ERR_MSG NVARCHAR(4000)=''

BEGIN TRY
	BEGIN
		IF @P_WORK_TYPE IN ('U')

			SELECT @P_SHIP_CD = COMN_CD 
			  FROM TB_AD_COMN_CODE 
			 WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')
			   AND COMN_CD_NM = @P_SHIP;

			SELECT @P_POD_CD = COMN_CD 
			  FROM TB_AD_COMN_CODE 
			 WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')
			   AND COMN_CD_NM = @P_ARR_PORT;

			SELECT @P_FD_CD = COMN_CD 
			  FROM TB_AD_COMN_CODE 
			 WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'FD')
			   AND COMN_CD_NM = @P_DLVR_LOC;

			BEGIN
				UPDATE TB_SKC_DP_BOD_MST
				   SET POD_CD		= @P_POD_CD
					 , SHIP_CD	    = @P_SHIP_CD
					 , FD_CD		= @P_FD_CD
					 , CY_LT	    = @P_CY_LT
					 , SHIP_CONF_LT = @P_SHIP_CONF_LT
					 , LAND_CONF_LT = @P_LAND_CONF_LT
					 , MODIFY_BY    = (SELECT DISPLAY_NAME FROM TB_AD_USER WHERE USERNAME = @P_USER_ID)
					 , MODIFY_DTTM  = GETDATE()
				 WHERE ID = @P_ID
			END;

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
