USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2030_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2030_Q1] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2030_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 사업계획 比 판매계획 
--                    연간 사업계획과 출하실적 & 판매계획 (RTF) 의 Gap을 비교한 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-01  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2030_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2030_Q1  'ko','I23971','UI_SA2030'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID             ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @V_FR_YYYYMM             NVARCHAR(10)   = CONVERT(NVARCHAR(4), GETDATE(), 112) + '01'    -- 기준년월 (From)
          , @V_TO_YYYYMM             NVARCHAR(10)   = CONVERT(NVARCHAR(4), GETDATE(), 112) + '12'    -- 기준년월 (To)


    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1030_RAW_Q1
         @V_FR_YYYYMM                -- 기준년월
       , @V_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , 'UI_SA1020_POP'             -- @P_VIEW_ID
    ;

    ---------------------------------
    -- 조회
    ---------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제
        SELECT M.MEASURE_CD
             , M.MEASURE_NM
             , X.ORG_CORP_CD
             , X.CORP_CD
             , X.CORP_NM
             , X.BASE_YYYYMM
             , X.SALES_YN
             , SUM(ISNULL(CASE WHEN MEASURE_CD = '01' THEN ANNUAL_QTY                              -- 사업계획
                               WHEN MEASURE_CD = '02' THEN SALES_QTY                               -- 판매실적
                               WHEN MEASURE_CD = '03' THEN SALES_QTY - ANNUAL_QTY                  -- Gap
                           END ,0))  / 1000                                                 AS QTY
          INTO #TM_QTY
          FROM TM_SA1020_POP X WITH(NOLOCK)
             , (
                  SELECT COMN_CD          AS MEASURE_CD
                       , COMN_CD_NM       AS MEASURE_NM
                       , SEQ              AS SEQ
                    FROM FN_COMN_CODE('SA1020_3','')
               ) M

         GROUP BY M.MEASURE_CD
                , M.MEASURE_NM
                , X.ORG_CORP_CD
                , X.CORP_CD
                , X.CORP_NM
                , X.BASE_YYYYMM
                , X.SALES_YN

--SELECT * FROM #TM_QTY

    -------------------------------------
    ---- 조회 (전체)
    -------------------------------------
    IF OBJECT_ID('tempdb..#TM_SUM') IS NOT NULL DROP TABLE #TM_SUM -- 임시테이블 삭제
        SELECT *
          INTO #TM_SUM
          FROM (
                  SELECT MEASURE_CD                      AS MEASURE_CD
                       , MEASURE_NM                      AS MEASURE_NM
                       , ORG_CORP_CD                     AS ORG_CORP_CD
                       , CORP_CD                         AS CORP_CD
                       , CORP_NM                         AS CORP_NM
                       , BASE_YYYYMM                     AS BASE_YYYYMM
                       , QTY                             AS QTY
                       , SALES_YN                        AS SALES_YN
                    FROM #TM_QTY
                   UNION ALL
                 -- 월별 Sum (우측)
                  SELECT MEASURE_CD                      AS MEASURE_CD
                       , MEASURE_NM                      AS MEASURE_NM
                       , ORG_CORP_CD                     AS ORG_CORP_CD
                       , CORP_CD                         AS CORP_CD
                       , CORP_NM                         AS CORP_NM
                       , 'Total'                         AS BASE_YYYYMM
                       , SUM(QTY)                        AS QTY
                       , NULL                            AS SALES_YN
                    FROM #TM_QTY
                   GROUP BY MEASURE_CD
                          , MEASURE_NM
                          , ORG_CORP_CD
                          , CORP_CD
                          , CORP_NM
               ) X


    -------------------------------------
    ---- 조회 (전체)
    -------------------------------------

        SELECT MEASURE_CD                      AS MEASURE_CD
             , MEASURE_NM                      AS MEASURE_NM
             , CORP_CD                         AS CORP_CD
             , CORP_NM                         AS CORP_NM
             , BASE_YYYYMM                     AS BASE_YYYYMM
             , QTY                             AS QTY
             , SALES_YN                        AS SALES_YN
          FROM #TM_SUM
         UNION ALL
        SELECT MEASURE_CD                      AS MEASURE_CD
             , MEASURE_NM                      AS MEASURE_NM
             , 'Sub-Total'                     AS CORP_CD
             , 'GC-Copolyester(합계)'          AS CORP_NM
             , BASE_YYYYMM                     AS BASE_YYYYMM
             , SUM(QTY)                        AS QTY
             , NULL                            AS SALES_YN
          FROM #TM_SUM
         WHERE ORG_CORP_CD = '1'  -- 2024.08.22 AJS 본사만
         GROUP BY MEASURE_CD
                , MEASURE_NM
                , BASE_YYYYMM

         UNION ALL
        SELECT MEASURE_CD                      AS MEASURE_CD
             , MEASURE_NM                      AS MEASURE_NM
             , 'Total'                         AS CORP_CD
             , 'Total'                         AS CORP_NM
             , BASE_YYYYMM                     AS BASE_YYYYMM
             , SUM(QTY)                        AS QTY
             , NULL                            AS SALES_YN
          FROM #TM_SUM
         GROUP BY MEASURE_CD
                , MEASURE_NM
                , BASE_YYYYMM
         ORDER BY CORP_NM
                , MEASURE_CD
                , BASE_YYYYMM



END

GO
