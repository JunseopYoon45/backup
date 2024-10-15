USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1140_S1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1140_S1
-- COPYRIGHT       : AJS
-- REMARK          : CHDM 라인 운영 제약 (저장)
--                   1) CHDM Line별 일별 비가동 구분, 최소 가동율, 생산량 변동 금지일 관리
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-18  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1140_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
	, @P_BASE_YYYYMM                    NVARCHAR(100)   = NULL                -- 기준년월
    , @P_RSRC_CD                        NVARCHAR(100)   = NULL                -- 라인
    , @P_STCK_COST                      DECIMAL(20,3)                         -- 재고비용
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1140_S1' ORDER BY LOG_KEY_SEQ DESC
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000)=''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE             ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
	               + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM           ),'')    -- 기준년월
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD               ),'')    -- 라인
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_STCK_COST             ),'')    -- 재고비용
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID               ),'')    -- LOGIN_ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID               ),'')    -- VIEW_ID
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------

    BEGIN TRY
	

        IF @P_WORK_TYPE IN ('U', 'N') 
        BEGIN
    -----------------------------------
    -- 저장
    -----------------------------------
             MERGE T3SMARTSCM_NEW.DBO.TB_SKC_SA_GC_COST AS TGT
             USING (
                     SELECT @P_BASE_YYYYMM      AS BASE_YYYYMM    	 
                          , @P_RSRC_CD          AS RSRC_CD           
                          , @P_STCK_COST        AS STCK_COST      
                   ) AS SRC
                ON (     TGT.BASE_YYYYMM       = SRC.BASE_YYYYMM
				     AND TGT.RSRC_CD       = SRC.RSRC_CD
                   )

				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET STCK_COST  	 = SRC.STCK_COST  
					  , MODIFY_BY          = @P_USER_ID
					  , MODIFY_DTTM      	 = GETDATE() 

             WHEN NOT MATCHED THEN
					INSERT 
					(
						  BASE_YYYYMM    	  -- CORP     
						, RSRC_CD             -- PLANT    
						, STCK_COST           -- 기준일자  
						, CREATE_BY
						, CREATE_DTTM
					)
					VALUES(
						  SRC.BASE_YYYYMM   
						, SRC.RSRC_CD       
						, SRC.STCK_COST   
						, @P_USER_ID		  
						, GETDATE() 
					)

        ;
        


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
