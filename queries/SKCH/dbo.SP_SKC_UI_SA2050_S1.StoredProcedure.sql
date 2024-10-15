USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2050_S1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2050_S1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 평가감 금액 현황 - 저장
--                    법인별 평가감 예상 환입 금액에 대한 목표 및 실적을 조회하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-11  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2050_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_BASE_YYYYMM                    NVARCHAR(10)                          -- 기준년월
    , @P_CORP_CD                        NVARCHAR(100)  = NULL                 -- 법인
    , @P_WR_TYPE                        NVARCHAR(100)  = NULL                 -- 평가감 구분
    , @P_WR_AMT                         DECIMAL(20,3)                         -- 평가감 금액
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2050_S1' ORDER BY LOG_KEY_SEQ DESC
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000)=''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE             ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM           ),'')    -- 기준년월
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD               ),'')    -- 법인
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_WR_TYPE               ),'')    -- 평가감 구분
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_WR_AMT                ),'')    -- 평가감 금액
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
        MERGE T3SMARTSCM_NEW.DBO.TB_SKC_SA_WR_AMT_REPORT AS TGT
             USING (
                     SELECT  @P_BASE_YYYYMM                   AS BASE_YYYYMM     -- 기준년월
                          ,  @P_CORP_CD                       AS CORP_CD         -- 법인
                          ,  @P_WR_TYPE                       AS WR_TYPE         -- 평가감 구분
                          ,  @P_WR_AMT * 100000000           AS WR_AMT          -- 평가감 금액(억원)
                   ) AS SRC
                ON (     TGT.BASE_YYYYMM       = SRC.BASE_YYYYMM
                     AND TGT.CORP_CD           = SRC.CORP_CD
                     AND TGT.WR_TYPE           = SRC.WR_TYPE
                   )


        WHEN  MATCHED THEN
           UPDATE
              SET WR_AMT             = SRC.WR_AMT
                , MODIFY_BY          = @P_USER_ID
                , MODIFY_DTTM        = GETDATE()

        WHEN NOT MATCHED THEN
          INSERT
             (
               BASE_YYYYMM          -- 기준년월
             , CORP_CD              -- 법인
             , WR_TYPE              -- 평가감 구분
             , WR_AMT               -- 평가감 금액
             , CREATE_BY
             , CREATE_DTTM
             )
          VALUES
             (
               SRC.BASE_YYYYMM      -- 기준년월
             , SRC.CORP_CD          -- 법인
             , SRC.WR_TYPE          -- 평가감 구분
             , SRC.WR_AMT           -- 평가감 금액
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
