USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_PGM_LOG]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************
Title : SP_PGM_LOG
최초 작성자 : Zionex
최초 생성일 : 2024.02.02
 
설명 
 - 프로그램 LOG
 - 서버 변수처럼 SP에서도 사용자들이 넘긴 변수를 파악할 수 있는 SP
 
History (수정일자 / 수정자 / 수정내용)
- 2024.02.02 / Zionex / 최초 작성
- 2024.07.15 / Zionex / 설명 수정
 
*****************************************************************************/
CREATE PROCEDURE [dbo].[SP_PGM_LOG] (
 	@P_MDL_CD                                  	NVARCHAR(30)
, 	@P_PGM_NM                                  	NVARCHAR(100)
, 	@P_ERR_LINE_NO                             	NVARCHAR(100)
, 	@P_ERR_DESC                                	NVARCHAR(1000)
, 	@P_PARM_DESC                               	NVARCHAR(1000)
, 	@P_USER_ID                                 	NVARCHAR(30)
) 
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE
   @R_RESULT_PROC  NVARCHAR(100)

BEGIN TRY
	BEGIN TRANSACTION

	INSERT INTO [dbo].[TB_PGM_LOG]
			   ([MDL_CD]
			   ,[PGM_NM]
			   ,[ERR_LINE_NO]
			   ,[ERR_DESC]
			   ,[PARM_DESC]
			   ,[USER_ID]
			   ,[LOG_DTTM])
		 VALUES
			   (@P_MDL_CD
			   ,@P_PGM_NM
			   ,@P_ERR_LINE_NO
			   ,@P_ERR_DESC
			   ,@P_PARM_DESC
			   ,@P_USER_ID
			   ,CONVERT(VARCHAR(10),GETDATE(),111) + SPACE(1) + CONVERT(VARCHAR(8),GETDATE(),108)
			   )
	  
   IF @@TRANCOUNT > 0 COMMIT
   /* 로그 오류 <종료> */

END TRY
   
BEGIN CATCH

   IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
   SET @R_RESULT_PROC = 'PROC_ERROR'
        
END CATCH;
GO
