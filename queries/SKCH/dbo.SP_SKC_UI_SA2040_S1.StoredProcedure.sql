USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2040_S1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2040_S1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 평가감 당월 예상  - 저장
--                   당월 평가감 판매계획을 고려한 예상 기말재고 수량을 조회하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-11  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2040_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_MEET_ID                        NVARCHAR(100)   = NULL                -- 회의체 ID
    , @P_BASE_DATE                      NVARCHAR(100)   = NULL                -- 기준일자   2024.08.21 KMW
    , @P_BRND_CD                        NVARCHAR(100)   = NULL                -- BRAND
    , @P_ITEM_CD                        NVARCHAR(100)   = NULL                -- ITEM_CD
    , @P_TM_MIX_PRDT_QTY                DECIMAL(20,3)                         -- 당월 Mix 생산 수량
    , @P_TM_MIX_PRDT_AMT                DECIMAL(20,3)                         -- 당월 Mix 생산 금액
    , @P_SALES_PLAN_QTY                 DECIMAL(20,3)                         -- 판매계획 수량
    , @P_SALES_PLAN_AMT                 DECIMAL(20,3)                         -- 판매계획 금액
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2040_S1' ORDER BY LOG_KEY_SEQ DESC
EXEC SP_SKC_UI_SA2040_S1 'U','W20240821145859373W257054534189W','20240821','11-A0130','5000.000','0.000','0.000','0.000','I23670','UI_SA2040'
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000)=''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE              ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MEET_ID                ),'')    -- 회의체 ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_DATE              ),'')    -- 기준 일자
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRND_CD                ),'')    -- BRAND
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_CD                ),'')    -- ITEM_CD
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TM_MIX_PRDT_QTY        ),'')    -- 당월 Mix 생산 수량
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TM_MIX_PRDT_AMT        ),'')    -- 당월 Mix 생산 금액
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_SALES_PLAN_QTY         ),'')    -- 판매계획 수량
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_SALES_PLAN_AMT         ),'')    -- 판매계획 금액
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                ),'')    -- LOGIN_ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                ),'')    -- VIEW_ID
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------

    BEGIN TRY


        IF @P_WORK_TYPE IN ('U', 'N')
        BEGIN
        -----------------------------------
        -- 저장
        -----------------------------------
              MERGE T3SMARTSCM_NEW.DBO.TB_SKC_SA_WR_SALES_PLAN AS TGT
              USING (
                       SELECT @P_MEET_ID                 AS MEET_ID             -- 회의체 ID
                            , @P_BRND_CD                 AS BRND_CD             -- BRAND
                            , @P_ITEM_CD                 AS ITEM_CD             -- ITEM
                            , @P_SALES_PLAN_QTY          AS SALES_PLAN_QTY      -- 판매계획 수량
                            , @P_SALES_PLAN_AMT          AS SALES_PLAN_AMT      -- 판매계획 금액
                            , @P_TM_MIX_PRDT_QTY         AS TM_MIX_PRDT_QTY
                            , @P_TM_MIX_PRDT_AMT         AS TM_MIX_PRDT_AMT

                    ) AS SRC
                 ON (     TGT.MEET_ID       = SRC.MEET_ID
                      AND TGT.BRND_CD       = SRC.BRND_CD
                      AND TGT.ITEM_CD       = SRC.ITEM_CD
                    )


               WHEN  MATCHED THEN
                  UPDATE
                     SET SALES_PLAN_QTY     = SRC.SALES_PLAN_QTY
                       , SALES_PLAN_AMT     = SRC.SALES_PLAN_AMT
                       , TM_MIX_PRDT_QTY    = SRC.TM_MIX_PRDT_QTY
                       , TM_MIX_PRDT_AMT    = SRC.TM_MIX_PRDT_AMT
                       , MODIFY_BY          = @P_USER_ID
                       , MODIFY_DTTM        = GETDATE()

               WHEN NOT MATCHED THEN
                  INSERT
                     (
                         MEET_ID                         -- 회의체 ID
                       , BRND_CD                         -- BRAND
                       , ITEM_CD                         -- ITEM_CD
                       , SALES_PLAN_QTY                  -- 판매계획 수량
                       , SALES_PLAN_AMT                  -- 판매계획 금액
                       , TM_MIX_PRDT_QTY
                       , TM_MIX_PRDT_AMT
                       , CREATE_BY
                       , CREATE_DTTM
                     )
                  VALUES
                     (
                         SRC.MEET_ID                     -- 회의체 ID
                       , SRC.BRND_CD                     -- BRAND
                       , SRC.ITEM_CD                     -- ITEM_CD
                       , SRC.SALES_PLAN_QTY              -- 판매계획 수량
                       , SRC.SALES_PLAN_AMT              -- 판매계획 금액
                       , SRC.TM_MIX_PRDT_QTY
                       , SRC.TM_MIX_PRDT_AMT
                       , @P_USER_ID
                       , GETDATE()
                     )

        ;
    -----------------------------------
    -- 저장
    -----------------------------------
        UPDATE TB_SA_MEET_MST
           SET MEET_DT = @P_BASE_DATE
         WHERE ID      = @P_MEET_ID

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
