USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q6]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q6] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q6
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q6' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q6  'ko','I23779',''

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN
    -----------------------------------
    --  기준년월
    -----------------------------------
    DECLARE @V_TO_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일
    DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @V_TO_YYYYMM + '01'), 112)

    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1130_RAW_Q1
         @V_FR_YYYYMM                -- 기준년월
       , @V_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;

    -----------------------------------
    -- 조회 (전체)
    -----------------------------------
    BEGIN

        SELECT YYYYMM                          AS YYYYMM
             , PRDT_GBN                        AS PRDT_GBN
             , PRDT_GBN_NM                     AS PRDT_GBN_NM
             , ISNULL(ON_SPEC_QTY  , 0)        AS ON_SPEC_QTY
             , ISNULL(OFF_SPEC_QTY , 0)        AS OFF_SPEC_QTY
             , ISNULL(RATE         , 0)        AS RATE
          FROM (
                  SELECT C.YYYYMM                                                                          AS YYYYMM
                       , M.MEASURE_CD                                                                      AS PRDT_GBN
                       , M.MEASURE_NM                                                                      AS PRDT_GBN_NM
                     --, CASE WHEN PRDT_GBN = 'PLAN' THEN '계획' WHEN PRDT_GBN = 'ACT' THEN '실적' END     AS PRDT_GBN_NM
                       , SUM(TOT_QTY                ) / 1000                                               AS ON_SPEC_QTY
                       , SUM(TOT_QTY - ON_SPEC_QTY  ) / 1000                                               AS OFF_SPEC_QTY
                       , (SUM(MIX_QTY) + SUM(ERR_QTY) + SUM(FILTER_QTY)) / SUM(TOT_QTY ) * 100             AS RATE
                    FROM (  SELECT DISTINCT YYYYMM
                              FROM TB_CM_CALENDAR WITH(NOLOCK)
                             WHERE YYYYMM BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
                         ) C
                         FULL JOIN (  SELECT 'PLAN' MEASURE_CD, '계획' MEASURE_NM UNION ALL
                                      SELECT 'ACT'  MEASURE_CD, '실적' MEASURE_NM
                                   ) M
                                ON 1=1

                         OUTER APPLY (SELECT *
                                        FROM TM_SA1130 X WITH(NOLOCK)
                                       WHERE M.MEASURE_CD = X.PRDT_GBN
                                         AND C.YYYYMM     = X.YYYYMM
                                      ) X

                   GROUP BY  C.YYYYMM, M.MEASURE_CD, M.MEASURE_NM
               ) A
         ORDER BY  YYYYMM, PRDT_GBN_NM

    END

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1130') IS NOT NULL DROP TABLE TM_SA1130

END

GO
