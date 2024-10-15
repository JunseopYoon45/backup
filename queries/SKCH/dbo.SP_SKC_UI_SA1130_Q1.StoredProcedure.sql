USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1130_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1130_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1130_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 비정상 제품 발생률
--                   라인별로 발생한 비정상 제품에 대한 수준을 측정하는 지표
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-02  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1130_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1130_Q1 '202405','202407','ko','I23779','UI_SA1130'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM                 ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM                 ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -------------------------------------
    ---- 임시 테이블 (계획)
    -------------------------------------
    IF OBJECT_ID('tempdb..#TM_FP_VERSION') IS NOT NULL DROP TABLE #TM_FP_VERSION -- 임시테이블 삭제

        SELECT CONVERT(NVARCHAR(6), PLAN_DT, 112)   AS PLAN_YYYYMM
             , MAX(VERSION)                         AS VER_ID
          INTO #TM_FP_VERSION
          FROM VW_FP_PLAN_VERSION WITH(NOLOCK)
         WHERE CNFM_YN       = 'Y'
           AND PLAN_SCOPE    = 'FP-COPOLY'
           AND CONVERT(NVARCHAR(6), PLAN_DT, 112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
         GROUP BY  CONVERT(NVARCHAR(6), PLAN_DT, 112)

    -------------------------------------
    ---- 임시 테이블 (품변횟수)
    -------------------------------------
    IF OBJECT_ID('tempdb..#TM_GC_CNT') IS NOT NULL DROP TABLE #TM_GC_CNT -- 임시테이블 삭제

        SELECT *
          INTO #TM_GC_CNT
          FROM (
                  SELECT PLAN_YYYYMM                AS PLAN_YYYYMM
                       , RSRC_CD                    AS RSRC_CD
                       , 'PLAN'                     AS PRDT_GBN
                       , COUNT(1)                   AS GC_CNT
                    FROM TB_SKC_FP_RS_PRDT_PLAN_MIX M
                       , #TM_FP_VERSION V
                   WHERE M.VER_ID = V.VER_ID
                     AND CONVERT(NVARCHAR(6), PLAN_DTE, 112)   = V.PLAN_YYYYMM
                     --AND CONVERT(NVARCHAR(6), PLAN_DTE, 112)   BETWEEN  @P_FR_YYYYMM AND @P_TO_YYYYMM
                   GROUP BY PLAN_YYYYMM, RSRC_CD

                   UNION ALL

                  SELECT X.ACT_YYYYMM                              AS ACT_YYYYMM
                       , X.RSRC_CD                                 AS RSRC_CD
                       , 'ACT'                                     AS PRDT_GBN
                       , MAX(PRDT_DATE_CNT) - SUM(DAY_CNT)         AS CNT  -- (생산일수 - 연속생산건수)
                    FROM (
                            SELECT  X.RSRC_CD                      AS RSRC_CD
                                 , ACT_YYYYMM                      AS ACT_YYYYMM
                                 , COUNT(PRDT_ACT_DATE)            AS PRDT_DATE_CNT
                              FROM (
							          -- 생산 실적중 라인별 생산 일자 COUNT
                                      SELECT X.RSRC_CD                                 AS RSRC_CD
                                           , CONVERT(NVARCHAR(6), PRDT_ACT_DATE,112)   AS ACT_YYYYMM
                                           , X.PRDT_ACT_DATE                           AS PRDT_ACT_DATE
                                        FROM TB_SKC_FP_ACT_PRDT X  WITH(NOLOCK)
                                           , TB_CM_ITEM_MST     I
                                       WHERE X.ITEM_CD     = I.ITEM_CD
                                         AND ITEM_TYPE_CD  = 'GFRT'
                                         AND I.ATTR_14     = '020'
                                         AND CONVERT(NVARCHAR(6), PRDT_ACT_DATE,112) BETWEEN  @P_FR_YYYYMM AND @P_TO_YYYYMM
                                       GROUP BY X.RSRC_CD , X.PRDT_ACT_DATE, CONVERT(NVARCHAR(6), PRDT_ACT_DATE,112)
                                   ) X

                             GROUP BY X.RSRC_CD , ACT_YYYYMM
                         ) X

                         LEFT JOIN (  -- 라인별 연속일자 COUNT (연속만 체크하므로 1일 차이 아닐경우 0)
                                      SELECT RSRC_CD                                                                         AS RSRC_CD
                                           , ACT_YYYYMM                                                                      AS ACT_YYYYMM
                                           , CASE WHEN DATEDIFF(DAY, LD_PRDT_ACT_DATE, PRDT_ACT_DATE) = 1 THEN 1 ELSE 0 END  AS DAY_CNT
                                        FROM (
                                                SELECT RSRC_CD                                                               AS RSRC_CD
                                                     , CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112)                             AS ACT_YYYYMM
                                                     , PRDT_ACT_DATE                                                         AS PRDT_ACT_DATE
                                                     , LAG(PRDT_ACT_DATE) OVER(PARTITION BY RSRC_CD, CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112) ORDER BY PRDT_ACT_DATE)  AS LD_PRDT_ACT_DATE

                                                  FROM TB_SKC_FP_ACT_PRDT X  WITH(NOLOCK)
                                                     , TB_CM_ITEM_MST     I
                                                 WHERE X.ITEM_CD     = I.ITEM_CD
                                                   AND ITEM_TYPE_CD  = 'GFRT'
                                                   AND I.ATTR_14     = '020'
                                                   AND CONVERT(NVARCHAR(6), PRDT_ACT_DATE,112) BETWEEN  @P_FR_YYYYMM AND @P_TO_YYYYMM
                                             ) X
                                   ) Y
                           ON X.RSRC_CD = Y.RSRC_CD
                          AND X.ACT_YYYYMM = Y.ACT_YYYYMM

                   GROUP BY X.RSRC_CD, X.ACT_YYYYMM
          ) Y

    ---------------------------------
  -- RAW (비정상품 발생율)
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1130_RAW_Q1
         @P_FR_YYYYMM                -- 기준년월
       , @P_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;


    -----------------------------------
    -- 조회 (전체)
    -----------------------------------
  BEGIN

        SELECT A.RSRC_CD                                                                              AS RSRC_CD
             , A.RSRC_NM                                                                              AS RSRC_NM
             , A.YYYYMM                                                                               AS YYYYMM
             , A.PRDT_GBN                                                                             AS PRDT_GBN
             , CASE WHEN A.PRDT_GBN = 'PLAN' THEN '계획' WHEN A.PRDT_GBN = 'ACT' THEN '실적' END      AS PRDT_GBN_NM
             , (SUM(ON_SPEC_QTY) ) / 1000                                                             AS ON_SPEC_QTY
             , (SUM(MIX_QTY) + SUM(FILTER_QTY) + SUM(ERR_QTY) + SUM(WIDE_QTY  )) / 1000               AS OFF_SPEC_QTY
             , (SUM(MIX_QTY) + SUM(ERR_QTY) + SUM(FILTER_QTY))  / SUM(TOT_QTY ) * 100                 AS RATE
             , MAX(B.GC_CNT) AS GC_CNT
          FROM TM_SA1130 A WITH(NOLOCK)

               LEFT JOIN #TM_GC_CNT B
                      ON A.PRDT_GBN = B.PRDT_GBN
                     AND A.YYYYMM   = B.PLAN_YYYYMM
                     AND A.RSRC_CD  = B.RSRC_CD

         GROUP BY A.RSRC_CD
                , A.RSRC_NM
                , A.YYYYMM
                , A.PRDT_GBN
         ORDER BY A.RSRC_CD, A.YYYYMM, PRDT_GBN_NM

    END

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1130') IS NOT NULL  DROP TABLE TM_SA1130


END
GO
