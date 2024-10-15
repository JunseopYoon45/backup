USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2040_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2040_Q1] (
     @P_MEET_ID               NVARCHAR(100)   = NULL    -- 회의체 ID
   , @P_BASE_DATE             NVARCHAR(100)   = NULL    -- 기준일자   2024.08.21 AJS
   , @P_BRND_SUM_YN           NVARCHAR(100)   = NULL    -- BRND 소계  2024.09.23 AJS
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2040_Q1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 평가감 당월 예상 
--                   당월 평가감 판매계획을 고려한 예상 기말재고 수량을 조회하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-09  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2040_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2040_Q1   'dc1194b0e348479e81f67ec77077b2aa','20240811', 'N', 'ko','I23670','UI_SA2040'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_MEET_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_DATE          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRND_SUM_YN        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @V_BASE_DATE   NVARCHAR(10) = ( SELECT MAX(WR_DATE)
                                             FROM TB_SKC_CM_STCK_WRITE_DOWN_LIST  WITH(NOLOCK)
                                            WHERE WR_DATE <= @P_BASE_DATE
                                                             )
--  202407
    DECLARE @V_TM_YYYYMM NVARCHAR(6) = LEFT(@V_BASE_DATE, 6)
    DECLARE @V_LM_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_TM_YYYYMM+'01'), 112)

    DECLARE @V_FERT_DATE NVARCHAR(10) = @P_BASE_DATE 


    PRINT  '@V_LM_YYYYMM  ' + @V_LM_YYYYMM
    PRINT  '@V_TM_YYYYMM  ' + @V_TM_YYYYMM
    PRINT  '@V_FERT_DATE  ' + @V_FERT_DATE
    -----------------------------------
    -- 조회
    -----------------------------------
--SET @V_FERT_DATE = '20240819'
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT @P_MEET_ID                                                                                  AS MEET_ID             -- 회의 목록 ID
             , Y.NRML_TYPE_NM                                                                              AS NRML_TYPE_NM        -- 정상/비정상
             , Y.BRND_CD                                                                                   AS BRND_CD             -- Brand
             , Y.BRND_NM                                                                                   AS BRND_NM             -- Brand
             , IIF(@P_BRND_SUM_YN = 'Y', '', Y.GRADE_CD )                                                  AS GRADE_CD
             , IIF(@P_BRND_SUM_YN = 'Y', '', Y.GRADE_NM )                                                  AS GRADE_NM
             , IIF(@P_BRND_SUM_YN = 'Y', '', Y.ITEM_CD  )                                                  AS ITEM_CD
             , IIF(@P_BRND_SUM_YN = 'Y', '', Y.ITEM_NM  )                                                  AS ITEM_NM
             , ISNULL(W.LM_WR_STCK_QTY  , 0)                                                               AS LM_WR_STCK_QTY      -- 전월 평가감 수량
             , ISNULL(W.LM_WR_STCK_AMT  , 0)                                                               AS LM_WR_STCK_AMT      -- 전월 평가감 금액
             , ISNULL(W.TM_WR_STCK_QTY  , 0)                                                               AS TM_WR_STCK_QTY      -- 당월 평가감 수량
             , ISNULL(W.TM_WR_STCK_AMT  , 0)                                                               AS TM_WR_STCK_AMT      -- 당월 평가감 금액
             , ISNULL(X.STCK_QTY        , 0)                                                               AS TM_STCK_QTY         -- 당월 재고 수량
             , ISNULL(X.STCK_PRICE      , 0)                                                               AS TM_STCK_AMT         -- 당월 재고 금액
             , ISNULL(SALES_PLAN_QTY    , 0)                                                               AS SALES_PLAN_QTY      -- 판매 계획 수량
             , ISNULL(SALES_PLAN_AMT    , 0)                                                               AS SALES_PLAN_AMT      -- 판매 계획 금액
             , ISNULL(TM_MIX_PRDT_QTY   , 0)                                                               AS TM_MIX_PRDT_QTY     -- 당월 Mix 생산 수량
             , ISNULL(TM_MIX_PRDT_AMT   , 0)                                                               AS TM_MIX_PRDT_AMT     -- 당월 Mix 생산 금액
             , ((ISNULL(TM_WR_STCK_QTY  , 0) + ISNULL(TM_MIX_PRDT_QTY, 0)) - ISNULL(SALES_PLAN_QTY , 0))   AS EOH_WR_STCK_QTY     -- 기말 평가감 수량
             , ((ISNULL(TM_WR_STCK_AMT  , 0) + ISNULL(TM_MIX_PRDT_AMT, 0)) - ISNULL(SALES_PLAN_AMT , 0))   AS EOH_WR_STCK_AMT     -- 기말 평가감 금액
             , ISNULL(LM_WR_STCK_QTY    , 0)
             - (((ISNULL(TM_WR_STCK_QTY , 0) + ISNULL(TM_MIX_PRDT_QTY, 0)) - ISNULL(SALES_PLAN_QTY,0)))    AS EOH_LY_VS_QTY       -- 기말 전월대비 평가감 수량
             , ISNULL(LM_WR_STCK_AMT    , 0)
             - (((ISNULL(TM_WR_STCK_AMT , 0) + ISNULL(TM_MIX_PRDT_AMT, 0)) - ISNULL(SALES_PLAN_AMT,0)))    AS EOH_LY_VS_AMT       -- 기말 전월대비 평가감 금액
          INTO #TM_QTY
          FROM (
                  SELECT A.CORP_CD                                                                         AS CORP_CD
                       , A.PLNT_CD                                                                         AS PLNT_CD
                       , A.WRHS_CD                                                                         AS WRHS_CD
                       , A.ITEM_CD                                                                         AS ITEM_CD
                       , SUM(A.STCK_QTY) / 1000                                                            AS STCK_QTY
                       , SUM(A.STCK_PRICE) / 1000000                                                       AS STCK_PRICE  -- 2024.04.02 AJS
                    FROM TB_SKC_CM_FERT_STCK_HST        A WITH(NOLOCK)

                         LEFT JOIN TB_SKC_CM_PLNT_MST   B WITH(NOLOCK)
                                ON A.PLNT_CD = B.PLNT_CD

                   WHERE A.BASE_DATE        = @V_FERT_DATE
                     AND A.CORP_CD          = '1000'
                     AND A.STCK_STUS_CD     = '가용'
                     AND EXISTS (SELECT 1
                                   FROM TB_SKC_CM_PLNT_MST Z WITH(NOLOCK)
                                  WHERE A.PLNT_CD = Z.PLNT_CD
                                    AND Z.STCK_YN = 'Y'
                                )
                   GROUP BY A.CORP_CD
                          , A.PLNT_CD
                          , A.WRHS_CD
                          , A.ITEM_CD
					UNION ALL
					SELECT 'MIX' AS CORP_CD
						 , 'MIX' AS PLNT_CD
						 , 'MIX' AS WRHS_CD
						 , 'MIX' AS ITEM_CD
						 , 0 AS STCK_QTY
						 , 0 AS STCK_PRICE  
               ) X

               LEFT JOIN dbo.TB_SKC_CM_PLNT_MST AS J WITH (NOLOCK) ON J.PLNT_CD = X.PLNT_CD

               LEFT JOIN (
                            SELECT WDM.PLNT_CD                                                                    AS PLNT_CD
                                 , WDM.WRHS_CD                                                                    AS WRHS_CD
                                 , ITEM_CD                                                                        AS ITEM_CD
                                 , SUM(CASE WHEN WR_DATE = @V_LM_YYYYMM AND WDM.STCK_TYPE  = '평가감 수량' THEN WDM.TOTAL  ELSE 0 END ) / 1000        AS LM_WR_STCK_QTY
                                 , SUM(CASE WHEN WR_DATE = @V_TM_YYYYMM AND WDM.STCK_TYPE  = '평가감 수량' THEN WDM.TOTAL  ELSE 0 END ) / 1000        AS TM_WR_STCK_QTY
                                 , SUM(CASE WHEN WR_DATE = @V_LM_YYYYMM AND WDM.STCK_TYPE  = '평가감 금액' THEN WDM.TOTAL  ELSE 0 END ) / 1000000     AS LM_WR_STCK_AMT
                                 , SUM(CASE WHEN WR_DATE = @V_TM_YYYYMM AND WDM.STCK_TYPE  = '평가감 금액' THEN WDM.TOTAL  ELSE 0 END ) / 1000000     AS TM_WR_STCK_AMT
                              FROM TB_SKC_CM_STCK_WRITE_DOWN_LIST WDM WITH(NOLOCK)
                             WHERE 1=1
                               AND WDM.STCK_TYPE IN ('평가감 수량', '평가감 금액')
                               AND WDM.WR_DATE       IN (@V_LM_YYYYMM, @V_TM_YYYYMM)
                             GROUP BY WDM.PLNT_CD
                                    , WDM.WRHS_CD
                                    , ITEM_CD
                         ) W
                      ON X.ITEM_CD      = W.ITEM_CD
                     AND X.PLNT_CD      = W.PLNT_CD
                     AND W.WRHS_CD      = X.WRHS_CD

               INNER MERGE JOIN
                    (  SELECT A.ITEM_CD                                                                             AS ITEM_CD
                            , CASE WHEN @P_LANG_CD = 'en' THEN A.ITEM_NM_EN ELSE ITEM_NM END                        AS ITEM_NM
                            , CASE WHEN @P_LANG_CD = 'en' THEN B.MDM_NRML_TYPE_NM_EN ELSE B.MDM_NRML_TYPE_NM END    AS NRML_TYPE_NM
                            , A.ATTR_04                                                                             AS ITEM_GRP_CD
                            , A.ATTR_06                                                                             AS BRND_CD
                            , A.ATTR_08                                                                             AS SERIES_CD
                            , A.ATTR_10                                                                             AS GRADE_CD
                            , A.ATTR_07                                                                             AS BRND_NM
                            , A.ATTR_09                                                                             AS SERIES_NM
                            , A.ATTR_11                                                                             AS GRADE_NM
                         FROM TB_CM_ITEM_MST A WITH(NOLOCK)
                            , (  SELECT COD.COMN_CD           AS COMN_CD
                                      , COD.ATTR_01_VAL       AS MDM_NRML_TYPE_CD
                                      , COD.ATTR_02_VAL       AS MDM_NRML_TYPE_NM
                                      , COD.ATTR_03_VAL       AS MDM_NRML_TYPE_NM_EN
                                   FROM TB_AD_COMN_CODE COD WITH(NOLOCK)
                                  WHERE COD.SRC_ID = (SELECT MAX(ID) FROM dbo.TB_AD_COMN_GRP WITH(NOLOCK) WHERE GRP_CD = 'NRML_TYPE_MDM')
                              ) B
                        WHERE A.ATTR_14  = B.COMN_CD              -- NRML_TYPE_CD
                          AND A.ATTR_04 IN ( '11', '1B')          -- ITEM_GRP_CD :제품그룹코드 (COPOLYESTER)
                          UNION ALL
						  SELECT 'MIX'    AS ITEM_CD
							   , ''    AS ITEM_NM
							   , '비정상'    AS NRML_TYPE_NM
							   , 'MIX'    AS ITEM_GRP_CD
							   , 'MIX'    AS BRND_CD
							   , 'MIX'    AS SERIES_CD
							   , 'MIX'    AS GRADE_CD
							   , 'MIX'    AS BRND_NM
							   , ''    AS SERIES_NM
							   , ''    AS GRADE_NM
                    ) Y
                 ON X.ITEM_CD   = Y.ITEM_CD

               LEFT JOIN TB_SKC_SA_WR_SALES_PLAN M  WITH(NOLOCK)
                 ON M.BRND_CD   = Y.BRND_CD
                AND M.ITEM_CD   = Y.ITEM_CD
                AND  M.MEET_ID   = @P_MEET_ID
         WHERE 1=1



    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT MEET_ID                              AS MEET_ID                 -- 회의 목록 ID
             , NRML_TYPE_NM                         AS NRML_TYPE_NM            -- 정상/비정상
             , BRND_CD                              AS BRND_CD                 -- Brand
             , BRND_NM                              AS BRND_NM                 -- Brand
             , GRADE_CD                             AS GRADE_CD
             , GRADE_NM                             AS GRADE_NM
             , ITEM_CD                              AS ITEM_CD
             , ITEM_NM                              AS ITEM_NM
             , SUM(LM_WR_STCK_QTY  )                AS LM_WR_STCK_QTY          -- 전월 평가감 수량
             , SUM(LM_WR_STCK_AMT  )                AS LM_WR_STCK_AMT          -- 전월 평가감 금액
             , SUM(TM_WR_STCK_QTY  )                AS TM_WR_STCK_QTY          -- 당월 평가감 수량
             , SUM(TM_WR_STCK_AMT  )                AS TM_WR_STCK_AMT          -- 당월 평가감 금액
             , SUM(TM_STCK_QTY     )                AS TM_STCK_QTY             -- 당월 재고 수량
             , SUM(TM_STCK_AMT     )                AS TM_STCK_AMT             -- 당월 재고 금액
             , MAX(SALES_PLAN_QTY  )                AS SALES_PLAN_QTY          -- 판매 계획 수량
             , MAX(SALES_PLAN_AMT  )                AS SALES_PLAN_AMT          -- 판매 계획 금액
             , MAX(TM_MIX_PRDT_QTY )                AS TM_MIX_PRDT_QTY         -- 당월 Mix 생산 수량
             , MAX(TM_MIX_PRDT_AMT )                AS TM_MIX_PRDT_AMT         -- 당월 Mix 생산 금액
             , SUM(EOH_WR_STCK_QTY )                AS EOH_WR_STCK_QTY         -- 기말 평가감 수량
             , SUM(EOH_WR_STCK_AMT )                AS EOH_WR_STCK_AMT         -- 기말 평가감 금액
             , SUM(EOH_LY_VS_QTY   )                AS EOH_LY_VS_QTY           -- 기말 전월대비 평가감 수량
             , SUM(EOH_LY_VS_AMT   )                AS EOH_LY_VS_AMT           -- 기말 전월대비 평가감 금액
          FROM #TM_QTY
         GROUP BY MEET_ID
             , NRML_TYPE_NM
             , BRND_CD
             , BRND_NM
             , GRADE_CD
             , GRADE_NM
             , ITEM_CD
             , ITEM_NM

         ORDER BY NRML_TYPE_NM
                , BRND_CD
             , GRADE_CD
             , ITEM_CD

END
GO
