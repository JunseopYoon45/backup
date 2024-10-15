USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1070_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1070_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1070_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 재고 Sight 상세
--                   재고 Sight 정보를 상세 Lv로 조회하는 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1070_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1070_POP_Q1  '202405','11-A0110','ALL','ko','I23779','UI_SA1070'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRAND_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID              ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

   DECLARE @V_BASE_DATE NVARCHAR(8) = @P_BASE_YYYYMM+'01' --(SELECT CONVERT(NVARCHAR(10), MAX(IF_STD_DATE), 112) FROM TB_SKC_CM_FERT_EOH_HST )
   DECLARE @V_TO_YYYYMM NVARCHAR(6) = @P_BASE_YYYYMM      --CONVERT(NVARCHAR(6), GETDATE(), 112)
   DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -6, @V_BASE_DATE), 112)

    -----------------------------------
    -- #TM_BRND
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_BRND') IS NOT NULL DROP TABLE #TM_BRND -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_BRND
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_BRAND_CD),''),'|')

    -----------------------------------
    -- #TM_GRADE
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_GRADE
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_GRADE_CD),''),'|')


    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1070_RAW_Q1
         @P_BASE_YYYYMM                   -- 기준년월
       , @P_BASE_YYYYMM                   -- 기준년월
       , @P_LANG_CD                       -- LANG_CD (ko, en)
       , @P_USER_ID                       -- USER_ID
       , 'UI_SA1070_POP'                  -- VIEW_ID
    ;

	
    ---------------------------------
    -- 조회
    ---------------------------------
        SELECT ''                                                            AS PLNT_CD
             , ''                                                            AS PLNT_NM
             , BRAND                                                         AS BRAND
             , GRADE                                                         AS GRADE
             , ITEM_CD                                                       AS ITEM_CD
             , ITEM_NM                                                       AS ITEM_NM
             , ISNULL(STCK_QTY  , 0)                                         AS STCK_QTY
             , ISNULL(STCK_AMT  , 0)                                         AS STCK_AMT
             , ISNULL(EX_ORG_AMT, 0)                                         AS EX_ORG_AMT
             , (ISNULL(STCK_AMT , 0) / ISNULL(EX_ORG_AMT  , 0)) * 365 / 12   AS STOCK_DAYS
          FROM TM_SA1070 Y WITH(NOLOCK)
         WHERE 1=1
           AND (Y.BRAND_CD  IN (SELECT VAL FROM #TM_BRND)    OR ISNULL( @P_BRAND_CD , 'ALL') = 'ALL' )
           AND (Y.GRADE_CD  IN (SELECT VAL FROM #TM_GRADE)   OR ISNULL( @P_GRADE_CD , 'ALL') = 'ALL' )

		   
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1070') IS NOT NULL DROP TABLE TM_SA1070

END

GO
