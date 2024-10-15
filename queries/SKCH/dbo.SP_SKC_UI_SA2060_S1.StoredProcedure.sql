USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2060_S1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2060_S1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 창고 Capacity 현황  - 저장
--                    울산 창고의 현 Capacity와 향후 변화 예상되는 Capacity 정보를 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-15  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2060_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_WRHS_GRP_CD                    NVARCHAR(100)   = NULL                -- 창고그룹
    , @P_WRHS_CD                        NVARCHAR(100)                         -- 창고
    , @P_CUR_CAPA                       DECIMAL(20,3)                         -- 현 CAPA
    , @P_CHG_CAPA                       DECIMAL(20,3)                         -- CAPA 변동
    , @P_REMARK                         NVARCHAR(100)                         -- 비고
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2060_S1' ORDER BY LOG_KEY_SEQ DESC
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000)=''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE             ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_WRHS_GRP_CD           ),'')    -- 법인
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_WRHS_CD               ),'')    -- 창고
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CUR_CAPA              ),'')    -- 현 CAPA
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CHG_CAPA              ),'')    -- CAPA 변동
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_REMARK                ),'')    -- 비고
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
         MERGE T3SMARTSCM_NEW.DBO.TB_SKC_SA_WRHS_CAPA AS TGT
         USING (
                  SELECT @P_WRHS_GRP_CD   AS WRHS_GRP_CD           -- 창고그룹
                       , @P_WRHS_CD       AS WRHS_CD               -- 창고
                       , @P_CUR_CAPA      AS CUR_CAPA              -- 현 CAPA
                       , @P_CHG_CAPA      AS CHG_CAPA              -- CAPA 변동
                       , @P_REMARK        AS REMARK                -- 비고
               ) AS SRC
            ON (     TGT.WRHS_GRP_CD   = SRC.WRHS_GRP_CD
                 AND TGT.WRHS_CD       = SRC.WRHS_CD
               )


          WHEN MATCHED THEN
             UPDATE
                SET CUR_CAPA           = SRC.CUR_CAPA
                  , CHG_CAPA           = SRC.CHG_CAPA
                  , REMARK             = SRC.REMARK
                  , MODIFY_BY          = @P_USER_ID
                  , MODIFY_DTTM        = GETDATE()

          WHEN NOT MATCHED THEN
             INSERT
                  (
                    WRHS_GRP_CD           -- 창고그룹
                  , WRHS_CD               -- 창고
                  , CUR_CAPA              -- 현 CAPA
                  , CHG_CAPA              -- CAPA 변동
                  , REMARK                -- 비고
                  , CREATE_BY
                  , CREATE_DTTM
                  )
             VALUES
                  (
                    SRC.WRHS_GRP_CD       -- 창고그룹
                  , SRC.WRHS_CD           -- 창고
                  , SRC.CUR_CAPA          -- 현 CAPA
                  , SRC.CHG_CAPA          -- CAPA 변동
                  , SRC.REMARK            -- 비고
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
