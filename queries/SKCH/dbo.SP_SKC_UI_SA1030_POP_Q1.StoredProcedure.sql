USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1030_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1030_POP_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_CORP_CD               NVARCHAR(100)   = NULL    -- 법인
   , @P_EMP_CD                NVARCHAR(100)   = NULL    -- 담당자
   , @P_REGION_CD             NVARCHAR(100)   = NULL    -- 권역
   , @P_ACCOUNT_FILTER        NVARCHAR(MAX)   = '[]'    -- 매출처
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1030_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 사업 계획 달성률
--                   사업계획 대비 판매실적의 달성률을 조회하는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-18  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1030_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1030_POP_Q1 '202401','202401','ALL','','ALL','[]','ALL','ALL','ko','I23670','UI_SA1010'
EXEC SP_SKC_UI_SA1030_POP_Q1 '202406', '202406','1060','', '','[]','ALL','ALL','ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_FR_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_TO_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_CORP_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_EMP_CD                ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_REGION_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(300),  @P_ACCOUNT_FILTER        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_BRAND_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_GRADE_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    -- #TM_REGION
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_REGION') IS NOT NULL DROP TABLE #TM_REGION -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_REGION
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_REGION_CD),''),'|')

    -----------------------------------
    -- #TM_BRND
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_BRAND') IS NOT NULL DROP TABLE #TM_BRAND -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_BRAND
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_BRAND_CD),''),'|')

    -----------------------------------
    -- #TM_GRADE
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_GRADE
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_GRADE_CD),''),'|')


    -----------------------------------
    -- #Account
    -----------------------------------
    DECLARE @P_STR  NVARCHAR(MAX);
    DECLARE @TMP_ACCOUNT TABLE (ACCOUNT_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ACCOUNT_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);

    SELECT @P_STR = dbo.FN_G_ACCT_FILTER_EXTENDS('CONTAINS', @P_ACCOUNT_FILTER);

    INSERT INTO @TMP_ACCOUNT
    EXECUTE sp_executesql @P_STR;
   -------------------------------

   --select * from @TMP_ACCOUNT
    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1030_RAW_Q1
         @P_FR_YYYYMM               -- 기준년월
       , @P_TO_YYYYMM               -- 기준년월
       , @P_LANG_CD                 -- LANG_CD (ko, en)
       , @P_USER_ID                 -- USER_ID
       , 'UI_SA1030_POP'                 -- VIEW_ID
    ;


    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT X.CORP_CD                                           AS CORP_CD
             , X.CORP_NM                                           AS CORP_NM
             , X.REGION                                            AS REGION
             , X.ACCOUNT_NM                                        AS ACCOUNT_NM
             , X.BRAND                                             AS BRAND
             , X.GRADE                                             AS GRADE
             , X.PLNT_CD                                           AS PLNT_CD
             , X.PLNT_NM                                           AS PLNT_NM
             , X.ANNUAL_QTY  / 1000                                AS ANNUAL_QTY
             , X.SALES_QTY   / 1000                                AS SALES_QTY
             , ISNULL(X.SALES_QTY   / X.ANNUAL_QTY * 100,0)        AS ACHIEV_RATE   -- 달성률
             , ISNULL(X.ACRCY_RATE,0)                              AS ACRCY_RATE    -- 정확도
          FROM TM_SA1030_POP X WITH(NOLOCK)
             , @TMP_ACCOUNT A
         WHERE 1=1
           AND X.ACCOUNT_CD   = A.ACCOUNT_CD
           AND X.CORP_CD      = CASE WHEN @P_CORP_CD = 'ALL' THEN X.CORP_CD ELSE @P_CORP_CD END  -- 법인
           AND (REGION    IN (SELECT VAL FROM #TM_REGION)  OR ISNULL( @P_REGION_CD, 'ALL') = 'ALL' )
           AND (BRAND_CD  IN (SELECT VAL FROM #TM_BRAND)   OR ISNULL( @P_BRAND_CD , 'ALL') = 'ALL' )
           AND (GRADE_CD  IN (SELECT VAL FROM #TM_GRADE)   OR ISNULL( @P_GRADE_CD , 'ALL') = 'ALL' )
		   AND (ISNULL(X.ANNUAL_QTY, 0) + ISNULL(X.SALES_QTY,0)) > 0
END

GO
