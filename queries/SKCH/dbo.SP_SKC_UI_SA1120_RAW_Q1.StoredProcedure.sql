USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1120_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1120_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1120_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 목표 품종 생산율
--                   울산공장의 생산라인별로 목표한 제품의 생산 달성률을 조회
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1120_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1120_RAW_Q1 '202402','202407','ko','I23779','UI_SA1010'


*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_FR_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_TO_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

--select * from TB_FP_MAIN_VERSION
--select * from TB_FP_PLAN_VERSION

    -----------------------------------
  -- Version
    -----------------------------------
    IF OBJECT_ID('#FP_VERSION') IS NOT NULL DROP TABLE #FP_VERSION -- 임시테이블 삭제
        SELECT FR_FP_VERSION                                                       AS  FP_VERSION
             , FR_DT                                                               AS  FR_DT
             , ISNULL(X_TO_DT,  CONVERT(NVARCHAR(10), EOMONTH(Y_TO_DT), 112))      AS  TO_DT
          INTO #FP_VERSION
          FROM (  SELECT X.*
                       , CONVERT(NVARCHAR(10), DATEADD(DAY, -1, Y.FROM_DT), 112)   AS Y_TO_DT
                    FROM (
                            SELECT X.VERSION                                       AS FR_FP_VERSION
                                 , LEAD(X.VERSION) OVER(ORDER BY VERSION )         AS TO_FP_VERSION
                                 , CONVERT(NVARCHAR(10), X.FROM_DT, 112)           AS FR_DT
                                 , CONVERT(NVARCHAR(10), X.TO_DT, 112)             AS X_TO_DT
                              FROM VW_FP_PLAN_VERSION X WITH(NOLOCK)
                             WHERE X.CNFM_YN = 'Y'
                         ) X

                         LEFT JOIN VW_FP_PLAN_VERSION Y WITH(NOLOCK)
                           ON X.TO_FP_VERSION = Y.VERSION

               ) Y


    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    IF OBJECT_ID('TM_SA1120') IS NOT NULL DROP TABLE TM_SA1120 -- 임시테이블 삭제

        CREATE TABLE TM_SA1120
        (
               YYYYMM            NVARCHAR(100)
             , RSRC_CD           NVARCHAR(100)
             , RSRC_NM           NVARCHAR(100)
             , BRAND             NVARCHAR(100)
             , PRDT_GRADE_CD     NVARCHAR(100)
             , NRML_TYPE_CD      NVARCHAR(100)
             , NRML_TYPE_NM      NVARCHAR(100)
             , PLAN_QTY          DECIMAL(18,0)
             , ACT_QTY           DECIMAL(18,0)

        )

    -----------------------------------
    -- 조회
    -----------------------------------

    --IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        INSERT INTO TM_SA1120
        SELECT X.YYYYMM                        AS YYYYMM
             , X.RSRC_CD                       AS RSRC_CD
         , (SELECT TOP 1 SCM_RSRC_NM FROM TB_SKC_FP_RSRC_MST L WITH(NOLOCK) WHERE X.RSRC_CD = L.RSRC_CD) AS RSRC_NM
             , I.ATTR_07                       AS BRAND
             , I.PRDT_GRADE_NM                 AS PRDT_GRADE_CD
             , I.ATTR_14                       AS NRML_TYPE_CD
             , I.ATTR_15                       AS NRML_TYPE_NM
             , SUM(X.PLAN_QTY )                AS PLAN_QTY
             , SUM(X.ACT_QTY  )                AS ACT_QTY
          FROM (
                  -- 생산계획
                  SELECT LEFT(X.PLAN_DTE,6)    AS YYYYMM
                       , X.RSRC_CD             AS RSRC_CD
                       , X.ITEM_CD             AS ITEM_CD
                       , X.PRDT_GRADE_CD       AS PRDT_GRADE_CD
                       , X.ADJ_PLAN_QTY * 1000       AS PLAN_QTY
                       , 0                     AS ACT_QTY
                    FROM TB_SKC_FP_RS_PRDT_PLAN_CO  X WITH(NOLOCK)
                       , #FP_VERSION                V
                   WHERE X.VER_ID = V.FP_VERSION
                     AND X.PLAN_DTE BETWEEN V.FR_DT AND V.TO_DT

                     --AND X.ITEM_TYPE_CD = 'GFRT'
                     AND EXISTS (SELECT 1
                                   FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                                  WHERE SCM_USE_YN = 'Y'
                                    AND X.RSRC_CD  = Y.RSRC_CD
                                    AND Y.PLNT_CD IN ('1230', '1110')
                                )
                   UNION ALL
                   ------------------------------------
                   -- 생산실적
                   ------------------------------------
                  SELECT CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112)    AS YYYYMM
                       , X.RSRC_CD                                    AS RSRC_CD
                       , X.ITEM_CD                                    AS ITEM_CD
                       , I.PRDT_GRADE_CD                              AS PRDT_GRADE_CD
                       , 0                                            AS PLAN_QTY
                       , X.PRDT_ACT_QTY                               AS ACT_QTY
                    FROM TB_SKC_FP_ACT_PRDT  X WITH(NOLOCK)
                       , TB_CM_ITEM_MST  I WITH(NOLOCK)
                   WHERE X.ITEM_CD      = I.ITEM_CD
                     AND X.ITEM_TYPE_CD = 'GFRT'
                     AND CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                     AND EXISTS ( SELECT 1
                                    FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                                   WHERE SCM_USE_YN = 'Y'
                                     AND X.RSRC_CD  = Y.RSRC_CD
                                     AND Y.PLNT_CD IN ('1230', '1110')
                                )

                    UNION ALL
                 -- MIX 계획
                  SELECT LEFT(X.PLAN_DTE,6)                           AS YYYYMM
                       , X.RSRC_CD                                    AS RSRC_CD
                       , '999999'                                     AS ITEM_CD
                       , X.TO_PRDT_GRADE_CD                           AS PRDT_GRADE_CD
                       , X.ADJ_PLAN_QTY * 1000                              AS PLAN_QTY
                       , 0                                            AS ACT_QTY
                    FROM TB_SKC_FP_RS_PRDT_PLAN_MIX  X WITH(NOLOCK)
                       , #FP_VERSION                 V
                   WHERE X.VER_ID = V.FP_VERSION
                     AND X.PLAN_DTE BETWEEN V.FR_DT AND V.TO_DT
                     AND EXISTS ( SELECT 1
                                    FROM TB_SKC_FP_RSRC_MST  Y WITH(NOLOCK)
                                   WHERE SCM_USE_YN        = 'Y'
                                     AND X.RSRC_CD         = Y.RSRC_CD
                                     AND Y.PLNT_CD IN ('1230', '1110')
                                )
            ------------------------------------

               ) X
             , TB_CM_ITEM_MST I WITH(NOLOCK)
         WHERE X.ITEM_CD = I.ITEM_CD
           AND I.ATTR_04   IN ('11', '1B')               -- Copoly, PET (11, 1B)   2024.07.17 AJS
           AND I.ATTR_06   != '11-A0140'                 -- SKYPURA   2024.07.17 AJS
           AND I.ATTR_14    = '010'                      -- 정상품만 대상 2024.07.24
         GROUP BY X.YYYYMM
                , X.RSRC_CD
                , I.ATTR_07
                , I.ATTR_14
                , I.ATTR_15
                , I.PRDT_GRADE_NM

END

GO
