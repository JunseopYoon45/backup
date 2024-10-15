USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1030_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1030_Q1] (
     @P_CORP_CD               NVARCHAR(100)   = NULL    -- ('ALL'/CORP_CD)
   , @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1030_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1030_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1030_Q1 '136','202407','202407','ko','I23779','UI_SA1030'
EXEC SP_SKC_UI_SA1030_Q1 'ALL','202407','202407','ko','I23779','UI_SA1030'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_CORP_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_FR_YYYYMM           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_TO_YYYYMM           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID             ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1030_RAW_Q1
         @P_FR_YYYYMM                -- 기준년월
       , @P_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;

	
    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
		  INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1030','')

    -----------------------------------
    -- 조회 (전체)
    -----------------------------------
    IF @P_CORP_CD = 'ALL'
        BEGIN

             SELECT MEASURE_CD                                                                   AS MEASURE_CD
                  , MEASURE_NM                                                                   AS MEASURE_NM
                  , CORP_CD                                                                      AS CORP_CD
                  , CORP_NM                                                                      AS CORP_NM
                  , ISNULL(CASE WHEN MEASURE_CD = '01' THEN (ANNUAL_QTY)                                   -- 사업계획
                                WHEN MEASURE_CD = '02' THEN (SALES_QTY )                                   -- 판매실적
                                WHEN MEASURE_CD = '03' THEN ACHIEV_RATE                                    -- 달성률
                                WHEN MEASURE_CD = '04' THEN ACRCY_RATE                                     -- 정확도 = (사업계획 + 그레이드단위 정확도) / 사업계획
                            END ,0)                                                              AS QTY
               FROM
                    (
                       SELECT CORP_CD                                                            AS CORP_CD
                            , CORP_NM                                                            AS CORP_NM
                            , SUM(ANNUAL_QTY) / 1000                                             AS ANNUAL_QTY
                            , SUM(SALES_QTY ) / 1000                                             AS SALES_QTY
                            , SUM(SALES_QTY ) / SUM(ANNUAL_QTY ) * 100                           AS ACHIEV_RATE
                            , SUM((ANNUAL_QTY) *  (ACRCY_RATE)) / SUM(ANNUAL_QTY)                AS ACRCY_RATE
                         FROM TM_SA1030 X WITH(NOLOCK)
                        WHERE CORP_CD IS NOT NULL
                        GROUP BY CORP_CD
                               , CORP_NM
                        UNION ALL
                       SELECT '0000'                                                             AS CORP_CD
                            , ' Total'                                                           AS CORP_NM
                            , SUM(ANNUAL_QTY) / 1000                                             AS ANNUAL_QTY
                            , SUM(SALES_QTY ) / 1000                                             AS SALES_QTY
                            , SUM(SALES_QTY ) / SUM(ANNUAL_QTY ) * 100                           AS ACHIEV_RATE
                            , SUM((ANNUAL_QTY) * (ACRCY_RATE)) / SUM(ANNUAL_QTY)                 AS ACRCY_RATE
                         FROM TM_SA1030 X WITH(NOLOCK)
                        WHERE CORP_CD IS NOT NULL
                          AND ORG_CORP_CD = '1'  -- 전체SUM 은 본사만 합계
                    ) X
                  , #TM_MEASURE Y
              ORDER BY CORP_NM
        END


    -----------------------------------
    -- 조회 (법인별)
    -----------------------------------
    IF @P_CORP_CD != 'ALL'
        BEGIN
             SELECT TOP 10
                    CORP_CD                                                     AS CORP_CD
                  , CORP_NM                                                     AS CORP_NM
                  , REGION                                                      AS REGION
                  , ACCOUNT_NM                                                  AS ACCOUNT_NM
                  , SUM(ANNUAL_QTY ) / 1000                                     AS ANNUAL_QTY
                  , SUM(SALES_QTY  ) / 1000                                     AS SALES_QTY
                  , SUM(SALES_QTY )  / SUM(ANNUAL_QTY ) * 100                   AS ACHIEV_RATE    -- 달성률
                  , SUM((ANNUAL_QTY) * (ACRCY_RATE)) / SUM(ANNUAL_QTY)          AS ACRCY_RATE     -- 정확도
               FROM TM_SA1030 WITH(NOLOCK)
              WHERE CORP_CD = @P_CORP_CD

              GROUP BY CORP_CD
                  , CORP_NM
                  , REGION
                  , ACCOUNT_NM
              ORDER BY ANNUAL_QTY DESC
                  , SALES_QTY DESC
                  , CORP_NM
                  , REGION
                  , ACCOUNT_NM
        END

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1030') IS NOT NULL DROP TABLE TM_SA1030


END

GO
