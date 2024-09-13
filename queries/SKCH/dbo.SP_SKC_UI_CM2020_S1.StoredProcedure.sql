USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2020_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2020_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     플랜트 정보 수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-26  YJS            신규 생성
-- 2024-04-05  YJS			  행 추가
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2020_S1] (
	 @P_WORK_TYPE		   NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
   , @P_ID				   NVARCHAR(100) = NULL
   , @P_CORP_CD			   NVARCHAR(10)  = NULL
   , @P_CORP_NM			   NVARCHAR(100) = NULL
   , @P_PLNT_CD			   NVARCHAR(10)  = NULL
   , @P_PLNT_NM			   NVARCHAR(100) = NULL
   , @P_ACTV_YN			   NVARCHAR(10)  
   , @P_PRDT_YN			   NVARCHAR(10) 
   , @P_STCK_YN			   NVARCHAR(10) 
   , @P_USER_ID            NVARCHAR(100)
   , @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
   , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

---------- PGM LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_CM2020_S1' ORDER BY LOG_DTTM DESC
*/

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
	  , @PARM_DESC    NVARCHAR(1000) = ''	

    SET @P_PGM_NM  = 'SP_SKC_UI_CM2020_S1'
    SET @PARM_DESC =  '''' + ISNULL(CONVERT(VARCHAR(100)  , @P_WORK_TYPE), '')    			   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ID ), '')				  	   
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_NM),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLNT_CD),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLNT_NM),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ACTV_YN),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_YN),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_STCK_YN),  '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID),'')
				   + '''' 	

	EXEC SP_PGM_LOG 'DP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID	;

---------- PGM LOG END ----------

DECLARE  
		  @P_ERR_STATUS INT = 0
        , @P_ERR_MSG NVARCHAR(4000)=''

BEGIN TRY
	BEGIN
		IF @P_WORK_TYPE IN ('U')
			BEGIN
				UPDATE TB_SKC_CM_PLNT_MST 
				   SET ACTV_YN = @P_ACTV_YN
					 , PRDT_YN = @P_PRDT_YN
					 , STCK_YN = @P_STCK_YN
					 , MODIFY_BY = @P_USER_ID
					 , MODIFY_DTTM = GETDATE()
				 WHERE ID = @P_ID
			END;

		IF @P_WORK_TYPE IN ('N')
			BEGIN
				--INSERT INTO TB_SKC_CM_PLNT_MST (ID, CORP_CD, CORP_NM, PLNT_CD, PLNT_NM, PRDT_YN, DEL_YN, CREATE_BY, CREATE_DTTM)
			    INSERT INTO TB_SKC_CM_PLNT_MST (ID, CORP_CD, CORP_NM, PLNT_CD, PLNT_NM, PRDT_YN, STCK_YN, ACTV_YN, CREATE_BY, CREATE_DTTM)
					SELECT REPLACE(NEWID(), '-', '') AS ID
						 , @P_CORP_CD
						 , @P_CORP_NM
						 , @P_PLNT_CD
						 , @P_PLNT_NM
						 , @P_PRDT_YN
						 , @P_STCK_YN
						 , @P_ACTV_YN
						 , @P_USER_ID
						 , GETDATE()
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
