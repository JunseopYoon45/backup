USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1080_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1080_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1080_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 평가감 재고
--                   HQ, 법인별 평가감 재고 3개월 Trend를 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-20  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1080_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1080_Q1  '202404','202406', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    ---------------------------------
    -- RAW
    ---------------------------------
    BEGIN
          EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1080_RAW_Q1
               @P_FR_YYYYMM                -- 기준년월
             , @P_TO_YYYYMM                -- 기준년월
             , @P_LANG_CD                  -- LANG_CD (ko, en)
             , @P_USER_ID                  -- USER_ID
             , 'UI_SA1080'                 -- VIEW_ID
          ;
     END

    -----------------------------------
    -- 조회
    -----------------------------------

        SELECT WR_DATE              AS WR_DATE
             , CORP_NM              AS CORP_NM
             , STCK_TYPE_CD         AS STCK_TYPE_CD
             , STCK_TYPE            AS STCK_TYPE
             , QTY                  AS QTY
          FROM TM_SA1080 X WITH(NOLOCK)
         ORDER BY WR_DATE
                , CORP_NM
                , STCK_TYPE_CD


				
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1080') IS NOT NULL  DROP TABLE TM_SA1080

END

GO
