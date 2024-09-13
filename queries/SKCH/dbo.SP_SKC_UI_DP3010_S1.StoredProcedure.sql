USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP3010_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP3010_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     긴급요청 관리 수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-04  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP3010_S1] (
	 @P_WORK_TYPE          VARCHAR(2)                          -- 작업타입 (N:신규(등록), A:승인, C:확정, R:미반영)
   , @P_ID				   VARCHAR(32)  = NULL
   , @P_ITEM_ID			   VARCHAR(32)  = NULL
   , @P_ACCOUNT_ID		   VARCHAR(32)  = NULL
   , @P_EMP_ID			   VARCHAR(100) = NULL
   , @P_DMND_QTY		   INT			= NULL
   , @P_REQUEST_DATE_ID	   VARCHAR(10)  = NULL
   , @P_COMMENT			   VARCHAR(MAX) = NULL
   , @P_USER_ID            VARCHAR(100) 
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
	-- 사용자 권한에 따라 조회 가능여부 확인
		IF @P_WORK_TYPE IN ('N')
			BEGIN
			IF NOT EXISTS (SELECT 1 FROM TB_CM_ITEM_MST WHERE ID = @P_ITEM_ID AND ITEM_TP_ID = 'GFRT')
				BEGIN
					SET @P_ERR_MSG = 'MSG_SKC_022' 
					RAISERROR (@P_ERR_MSG,12, 1);						  
				END	

				IF NOT EXISTS (SELECT 1 FROM TB_DP_SALES_AUTH_MAP WHERE EMP_ID = @P_EMP_ID)
					INSERT INTO TB_SKC_DP_URNT_DMND_MST (ID, ITEM_MST_ID, ACCOUNT_ID, EMP_ID, URNT_DMND_QTY, REQUEST_DATE_ID, STATUS_CD, COMMENT, CREATE_BY, CREATE_DTTM)
						SELECT REPLACE(NEWID(), '-', '') AS ID
							 , @P_ITEM_ID AS ITEM_MST_ID
							 , @P_ACCOUNT_ID AS ACCOUNT_ID
							 , @P_EMP_ID AS EMP_ID
							 , @P_DMND_QTY AS URNT_DMND_QTY
							 , @P_REQUEST_DATE_ID AS REQUEST_DATE_ID
							 , 'REGISTERED' AS STATUS_CD
							 , @P_COMMENT AS COMMENT
							 , @P_USER_ID AS CREATE_BY
							 , GETDATE() AS CREATE_DTTM;
				ELSE
					BEGIN
						  SET @P_ERR_MSG = 'MSG_SKC_004' 
						  RAISERROR (@P_ERR_MSG,12, 1);
					END
			END;			 

		 IF @P_WORK_TYPE IN ('A') -- 승인
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM TB_SKC_DP_URNT_DMND_MST WHERE ID = @P_ID AND STATUS_CD = 'REGISTERED')
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_003'
						RAISERROR (@P_ERR_MSG, 12, 1);
					END
				ELSE
					IF EXISTS (SELECT 1 FROM TB_DP_SALES_AUTH_MAP 
								WHERE SALES_LV_ID IN (SELECT ID FROM TB_DP_SALES_LEVEL_MGMT WHERE SALES_LV_CD != 'ALL')
								  AND EMP_ID = @P_USER_ID)
						UPDATE TB_SKC_DP_URNT_DMND_MST
						   SET STATUS_CD = 'REVIEW', MODIFY_BY = @P_USER_ID, MODIFY_DTTM = GETDATE()
						 WHERE ID = @P_ID;
					ELSE
						BEGIN
						  SET @P_ERR_MSG = 'MSG_SKC_001' 
						  RAISERROR (@P_ERR_MSG,12, 1);
						END
				END;

		 IF @P_WORK_TYPE IN ('C') -- 확정
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM TB_SKC_DP_URNT_DMND_MST WHERE ID = @P_ID AND STATUS_CD = 'REVIEW')
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_003'
						RAISERROR (@P_ERR_MSG, 12, 1);
					END
				ELSE
					IF EXISTS (SELECT 1 FROM TB_DP_SALES_AUTH_MAP 
								WHERE SALES_LV_ID IN (SELECT ID FROM TB_DP_SALES_LEVEL_MGMT WHERE SALES_LV_CD = 'ALL')
								  AND EMP_ID = @P_USER_ID)
						UPDATE TB_SKC_DP_URNT_DMND_MST
						   SET STATUS_CD = 'CONFIRMED', MODIFY_BY = @P_USER_ID, MODIFY_DTTM = GETDATE()
						 WHERE ID = @P_ID;
					ELSE
						BEGIN
						  SET @P_ERR_MSG = 'MSG_SKC_002' 
						  RAISERROR (@P_ERR_MSG,12, 1);
						END
			END;

		 IF @P_WORK_TYPE IN ('R') -- 미반영
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM TB_SKC_DP_URNT_DMND_MST WHERE ID = @P_ID AND STATUS_CD = 'REVIEW')
					BEGIN
						SET @P_ERR_MSG = 'MSG_SKC_003'
						RAISERROR (@P_ERR_MSG, 12, 1);
					END
				ELSE
					IF EXISTS (SELECT 1 FROM TB_DP_SALES_AUTH_MAP 
								WHERE SALES_LV_ID IN (SELECT ID FROM TB_DP_SALES_LEVEL_MGMT WHERE SALES_LV_CD = 'ALL')
								  AND EMP_ID = @P_USER_ID)
						UPDATE TB_SKC_DP_URNT_DMND_MST
						   SET STATUS_CD = 'REJECTED', MODIFY_BY = @P_USER_ID, MODIFY_DTTM = GETDATE()
						 WHERE ID = @P_ID;
					ELSE
						BEGIN
						  SET @P_ERR_MSG = 'MSG_SKC_0002' 
						  RAISERROR (@P_ERR_MSG,12, 1);
						END
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
