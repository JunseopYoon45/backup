USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1070_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1070_Q1] (
     @P_ITEM_LVL               NVARCHAR(100)   = NULL    -- ('BRAND'/'GRADE')
   , @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1070_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 재고 Sight 상세
--                   HQ에서 보유한 재고에 대한 Brand, Grade Lv의 재고일수 조회 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1070_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1070_Q1  'BRAND','202404','202406', 'ko','I23779',''
EXEC SP_SKC_UI_SA1070_Q1  'GRADE','202402','202404', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_LVL        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    ---------------------------------
    -- RAW
    ---------------------------------
  IF @P_ITEM_LVL = 'BRAND'
  BEGIN
    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1070_RAW_Q1
         @P_FR_YYYYMM                -- 기준년월
       , @P_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;
  END


    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT YYYYMM                                                     AS YYYYMM
             , CASE WHEN @P_ITEM_LVL = 'BRAND' THEN BRAND
                    WHEN @P_ITEM_LVL = 'GRADE' THEN GRADE
                    ELSE NULL
                END                                                       AS ITEM
             , SUM(STCK_QTY   )                                     AS STCK_QTY
             , (SUM(ISNULL(STCK_AMT , 0)) / SUM(ISNULL(EX_ORG_AMT  , 0))) * 365 / 12     AS STOCK_DAYS
          FROM TM_SA1070 WITH(NOLOCK)
         WHERE 1=1
           AND 'Y' = CASE WHEN @P_ITEM_LVL = 'GRADE' AND GRADE IN ('K2012','S2008','J2003','PN N1','PN N2','SF700') THEN 'Y'
                          WHEN @P_ITEM_LVL = 'BRAND' THEN 'Y'
                          ELSE 'N'
                      END
         GROUP BY YYYYMM
                , CASE WHEN @P_ITEM_LVL = 'BRAND' THEN BRAND
                       WHEN @P_ITEM_LVL = 'GRADE' THEN GRADE
                       ELSE NULL
                   END
         ORDER BY ITEM
                , YYYYMM

				
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1070') IS NOT NULL AND @P_ITEM_LVL = 'GRADE' DROP TABLE TM_SA1070

END

GO
