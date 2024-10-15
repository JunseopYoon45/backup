USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1130_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1130_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1130_RAW_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1130_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1130_RAW_Q1 '202405','202407','ko','I23779','UI_SA1130'

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

    -----------------------------------
    -- Version
    -----------------------------------
    IF OBJECT_ID('#FP_VERSION') IS NOT NULL DROP TABLE #FP_VERSION -- 임시테이블 삭제
        SELECT FR_FP_VERSION                                                       AS  FP_VERSION
             , FR_DT                                                               AS  FR_DT
             , ISNULL(Y_TO_DT,  CONVERT(NVARCHAR(10), EOMONTH(@P_TO_YYYYMM+'01'), 112))      AS  TO_DT
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
                               AND CONVERT(NVARCHAR(6), X.FROM_DT, 112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                         ) X

                         LEFT JOIN VW_FP_PLAN_VERSION Y WITH(NOLOCK)
                                ON X.TO_FP_VERSION = Y.VERSION
                               AND Y.CNFM_YN       = 'Y'
                               AND CONVERT(NVARCHAR(6), Y.FROM_DT, 112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM

               ) Y

    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    IF OBJECT_ID('TM_SA1130') IS NOT NULL DROP TABLE TM_SA1130 -- 임시테이블 삭제

    CREATE TABLE TM_SA1130
    (
         YYYYMM               NVARCHAR(100)
       , RSRC_CD              NVARCHAR(100)
       , RSRC_NM              NVARCHAR(100)
       , BRAND                NVARCHAR(100)
       , PRDT_GRADE_CD        NVARCHAR(100)
       , PRDT_GRADE_NM        NVARCHAR(100)
       , PRDT_GBN             NVARCHAR(100)
       , TOT_QTY              DECIMAL(18,0)
       , ON_SPEC_QTY          DECIMAL(18,0)
       , MIX_QTY              DECIMAL(18,0)
       , ERR_QTY              DECIMAL(18,0)
       , FILTER_QTY           DECIMAL(18,0)
       , WIDE_QTY             DECIMAL(18,0)
       , MEF_RATE             DECIMAL(18,6)
       , MEFW_RATE            DECIMAL(18,6)

    )

    -----------------------------------
    -- 조회
    -----------------------------------

    --IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

     INSERT INTO TM_SA1130

        SELECT YYYYMM                                                   AS YYYYMM
             , RSRC_CD                                                  AS RSRC_CD
             , (SELECT TOP 1 SCM_RSRC_NM FROM TB_SKC_FP_RSRC_MST L WHERE A.RSRC_CD = L.RSRC_CD) AS RSRC_NM
             , BRAND                                                    AS BRAND
             , PRDT_GRADE_CD                                            AS PRDT_GRADE_CD
             , PRDT_GRADE_NM                                            AS PRDT_GRADE_NM
             , PRDT_GBN                                                 AS PRDT_GBN
             , TOT_QTY                                                  AS TOT_QTY
             , ON_SPEC_QTY                                              AS ON_SPEC_QTY
             , MIX_QTY                                                  AS MIX_QTY
             , ERR_QTY                                                  AS ERR_QTY
             , FILTER_QTY                                               AS FILTER_QTY
             , WIDE_QTY                                                 AS WIDE_QTY
             , (MIX_QTY + ERR_QTY + FILTER_QTY) / TOT_QTY               AS MEF_RATE
             , (MIX_QTY + ERR_QTY + FILTER_QTY + WIDE_QTY) / TOT_QTY    AS MEFW_RATE
          FROM (
                  SELECT X.YYYYMM                                                    AS YYYYMM
                       , X.RSRC_CD                                                   AS RSRC_CD
                       , I.ATTR_07                                                   AS BRAND
                       , X.PRDT_GRADE_CD                                             AS PRDT_GRADE_CD
                       , I.PRDT_GRADE_NM                                             AS PRDT_GRADE_NM
                       , X.PRDT_GBN                                                  AS PRDT_GBN
                       , SUM(X.QTY )                                                 AS TOT_QTY
                       , CASE WHEN PRDT_GBN = 'PLAN' THEN ISNULL(SUM(M.MIX_QTY),0)
                              ELSE SUM(CASE WHEN I.ATTR_14 = '020' THEN X.QTY   ELSE 0 END )
                          END                                                        AS MIX_QTY
                       , SUM(CASE WHEN I.ATTR_14 = '010' THEN X.QTY   ELSE 0 END )   AS ON_SPEC_QTY
                       , SUM(CASE WHEN I.ATTR_14 = '040' THEN X.QTY   ELSE 0 END )   AS ERR_QTY
                       , SUM(CASE WHEN I.ATTR_14 = '030' THEN X.QTY   ELSE 0 END )   AS FILTER_QTY
                       , SUM(CASE WHEN I.ATTR_14 = '050' THEN X.QTY   ELSE 0 END )   AS WIDE_QTY

                    FROM (
                            -- 생산계획
                            SELECT 'PLAN'                                       AS PRDT_GBN
                                 , LEFT(X.PLAN_DTE,6)                           AS YYYYMM
                                 , X.RSRC_CD                                    AS RSRC_CD
                                 , X.ITEM_CD                                    AS ITEM_CD
                                 , X.PRDT_GRADE_CD                              AS PRDT_GRADE_CD
                                 , X.ADJ_PLAN_QTY * 1000                        AS QTY
                              FROM TB_SKC_FP_RS_PRDT_PLAN_CO  X WITH(NOLOCK)
                                 , #FP_VERSION                V
                             WHERE X.VER_ID = V.FP_VERSION
                               AND X.PLAN_DTE BETWEEN V.FR_DT AND V.TO_DT
                               AND LEFT(X.PLAN_DTE,6) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                               AND X.PLAN_DTE BETWEEN V.FR_DT AND V.TO_DT

                             UNION ALL
                            -- 생산실적
                            SELECT 'ACT'                                        AS PRDT_GBN
                                 , CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112)    AS YYYYMM
                                 , X.RSRC_CD                                    AS RSRC_CD
                                 , X.ITEM_CD                                    AS ITEM_CD
                                 , I.PRDT_GRADE_CD                              AS PRDT_GRADE_CD
                                 , X.PRDT_ACT_QTY                               AS QTY
                              FROM TB_SKC_FP_ACT_PRDT  X WITH(NOLOCK)
                                 , TB_CM_ITEM_MST  I
                             WHERE X.ITEM_CD      = I.ITEM_CD
                               AND X.ITEM_TYPE_CD = 'GFRT'
                             --AND ISNULL(I.ATTR_14,'') != ''
                               AND CONVERT(NVARCHAR(6), X.PRDT_ACT_DATE,112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM

                         ) X
                           LEFT JOIN
                              (  SELECT LEFT(M.PLAN_DTE,6) YYYYMM
							          , FR_PRDT_GRADE_CD      AS FR_PRDT_GRADE_CD
                                      , (PLAN_QTY)         AS MIX_QTY
                                   FROM TB_SKC_FP_RS_PRDT_PLAN_MIX M
                                      , ( SELECT CONVERT(NVARCHAR(6), PLAN_DT, 112)   AS PLAN_YYYYMM
                                               , MAX(VERSION)                         AS VER_ID
                                            FROM VW_FP_PLAN_VERSION WITH(NOLOCK)
                                           WHERE CNFM_YN       = 'Y'
                                             --AND PLAN_SCOPE    = 'FP-COPOLY'
                                             AND CONVERT(NVARCHAR(6), PLAN_DT, 112) BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
											GROUP BY CONVERT(NVARCHAR(6), PLAN_DT, 112)
									    ) V
                                  WHERE M.VER_ID = V.VER_ID
                                    --AND LEFT(M.PLAN_DTE,6) = X.YYYYMM
                              ) M
                                    ON X.PRDT_GRADE_CD = M.FR_PRDT_GRADE_CD
									AND X.YYYYMM = M.YYYYMM
                       , TB_CM_ITEM_MST I WITH(NOLOCK)
                   WHERE X.ITEM_CD = I.ITEM_CD
                     AND EXISTS ( SELECT 1
                                    FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                                   WHERE SCM_USE_YN  = 'Y'
                                     AND X.RSRC_CD   = Y.RSRC_CD
                                     AND Y.PLNT_CD IN ('1230', '1110')
                                 )
                     AND I.ATTR_04   IN ('11', '1B')               -- Copoly, PET (11, 1B)   2024.07.17 AJS
                     AND I.ATTR_06   != '11-A0140'                 -- SKYPURA   2024.07.17 AJS
                   --AND ISNULL(I.ATTR_14,'') != ''
                   GROUP BY X.YYYYMM
                       , X.RSRC_CD
                       , I.ATTR_07
                       , X.PRDT_GRADE_CD
                       , I.PRDT_GRADE_NM
                       , X.PRDT_GBN
               ) A

END

GO
