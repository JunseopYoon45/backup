USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1140_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1140_RAW_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1140_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 품변기회비용
--                   특정 기준년월의 품변 기회비용을 조회할 수 있는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-08  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1140_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1140_RAW_Q1 '202405','ko','I23779','UI_SA1140'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -- 기준일자가 202407일때 202404 ~ 202406
    DECLARE @V_TO_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), EOMONTH(DATEADD(MONTH, 0, @P_BASE_YYYYMM + '01')) , 112)
    DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -2, @P_BASE_YYYYMM + '01'), 112)
    --DECLARE @V_TO_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), EOMONTH(DATEADD(MONTH, -1, @P_BASE_YYYYMM + '01')) , 112)
    --DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -3, @P_BASE_YYYYMM + '01'), 112)

	
    -----------------------------------
	-- 임시 테이블
    -----------------------------------
	
    IF OBJECT_ID('TM_SA1140') IS NOT NULL DROP TABLE TM_SA1140 -- 임시테이블 삭제

	CREATE TABLE TM_SA1140 
	(
      BASE_YYYYMM		   NVARCHAR(100)
    , RSRC_CD			   NVARCHAR(100)
    , RSRC_NM			   NVARCHAR(100)
    , F_GC_CNT			   DECIMAL(18,0)
    , L_GC_CNT			   DECIMAL(18,0)
    , GAP_CNT			   DECIMAL(18,0)
    , F_GC_QTY			   DECIMAL(18,0)
    , L_GC_QTY			   DECIMAL(18,0)
    , GAP_QTY			   DECIMAL(18,0)
    , PROP_COST			   DECIMAL(18,0)
    , GC_COST			   DECIMAL(18,0)

	)

    -----------------------------------
    -- 매출원가
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_SALES_AMT') IS NOT NULL DROP TABLE #TM_SALES_AMT -- 임시테이블 삭제



        SELECT BRAND                                                                             AS BRAND
             , ON_SEPC_SALES_AMT                                                                 AS ON_SEPC_SALES_AMT
             , ON_SEPC_SALES_QTY                                                                 AS ON_SEPC_SALES_QTY
             , ON_SEPC_SALES_PRICE                                                               AS ON_SEPC_SALES_PRICE
             , MIX_SALES_AMT                                                                     AS MIX_SALES_AMT
             , MIX_SALES_QTY                                                                     AS MIX_SALES_QTY
             , MIX_SALES_PRICE                                                                   AS MIX_SALES_PRICE
             , ON_SEPC_SALES_PRICE - MIX_SALES_PRICE                                             AS GAP_SALES_PRICE             -- 판가 Gap : 정상품 판매가 ? Mix품 판매가
             , MIX_SALES_QTY / SUM_MIX_SALES_QTY                                                 AS MIX_RATE                    -- Mix품 판매 수량 비중
             , (ON_SEPC_SALES_PRICE - MIX_SALES_PRICE) * (MIX_SALES_QTY / SUM_MIX_SALES_QTY )    AS AVG_RAB_AMT                 -- 평균 감가 : Brand별 판매가 Gap x Mix품 판매 수량 비중
          INTO #TM_SALES_AMT
          FROM (
                  SELECT BRAND                                               AS BRAND
                       , ON_SEPC_SALES_AMT                                   AS ON_SEPC_SALES_AMT
                       , ON_SEPC_SALES_QTY                                   AS ON_SEPC_SALES_QTY
                       , (ON_SEPC_SALES_AMT) / (ON_SEPC_SALES_QTY )          AS ON_SEPC_SALES_PRICE -- 정상품 (010) 판매가 :  매출액 합계 ÷ 총 수량
                       , MIX_SALES_AMT                                       AS MIX_SALES_AMT
                       , MIX_SALES_QTY                                       AS MIX_SALES_QTY
                       , SUM(MIX_SALES_QTY) OVER(PARTITION BY 1)             AS SUM_MIX_SALES_QTY
                       , (MIX_SALES_AMT) / (MIX_SALES_QTY )                  AS MIX_SALES_PRICE     -- Mix품 (020) 판매가 :  매출액 합계 ÷ 총 수량

                    FROM (
                            SELECT BRAND                                                         AS BRAND
                                 , SUM(CASE WHEN MIX_YN_CD = '010' THEN SALES_AMT   ELSE 0 END)  AS ON_SEPC_SALES_AMT
                                 , SUM(CASE WHEN MIX_YN_CD = '010' THEN SALES_QTY   ELSE 0 END)  AS ON_SEPC_SALES_QTY
                                 , SUM(CASE WHEN MIX_YN_CD = '020' THEN SALES_AMT   ELSE 0 END)  AS MIX_SALES_AMT
                                 , SUM(CASE WHEN MIX_YN_CD = '020' THEN SALES_QTY   ELSE 0 END)  AS MIX_SALES_QTY
                              FROM (
                                      SELECT I.ATTR_06             AS BRAND
                                           , I.ATTR_14             AS MIX_YN_CD
                                           , I.ATTR_15             AS MIX_YN_NM
                                           , A.SALES_QTY           AS SALES_QTY
                                           , A.TOTAL_AMT           AS SALES_AMT
                                        FROM TB_SKC_DP_RPRT_PROF  A WITH(NOLOCK)
                                           , TB_CM_ITEM_MST I WITH(NOLOCK)
                                       WHERE A.ITEM_CD = I.ITEM_CD
                                         AND I.ATTR_14 IN ( '010', '020')
                                         AND A.YYYYMM BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM   -- 기준 조회년월 직전 3개월의 Brand
                                  ) X
                             GROUP BY BRAND
                         ) Y
               ) Z
         WHERE ON_SEPC_SALES_PRICE > 0  -- 정상품 & Mix품 판매가가 둘 다 있는 Brand
           AND MIX_SALES_PRICE     > 0


           --SELECT * FROM #TM_SALES_AMT
        -----------------------------------
        -- 조회 (최초)
        -----------------------------------
        IF OBJECT_ID('tempdb..#TM_FP_FIRST') IS NOT NULL DROP TABLE #TM_FP_FIRST -- 임시테이블 삭제

        BEGIN
             SELECT BASE_YYYYMM                                                                            AS BASE_YYYYMM
                  , RSRC_CD                                                                                AS RSRC_CD
                  , PLAN_DTE                                                                               AS PLAN_DTE
                  , PRDT_GRADE_CD                                                                          AS PRDT_GRADE_CD
                  , SUM(1)																				   AS GC_CNT
                  , SUM(GC_QTY)                                                                            AS GC_QTY
               INTO #TM_FP_FIRST
               FROM (
                       SELECT LEFT(PLAN_DTE, 6)                              AS BASE_YYYYMM
                            , RSRC_CD                                        AS RSRC_CD
                            , PLAN_DTE                                       AS PLAN_DTE
                            , TO_PRDT_GRADE_CD                               AS PRDT_GRADE_CD
                            --, ITEM_CD                                        AS ITEM_CD
                            , (ADJ_PLAN_QTY)                                 AS GC_QTY
                            --, LAG(RSRC_CD) OVER(PARTITION BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD ORDER BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD, X.PLAN_DTE)  AS PREV_RSRC_CD
                            --, LAG(ITEM_CD) OVER(PARTITION BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD ORDER BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD, X.PLAN_DTE)  AS PREV_ITEM_CD

                         FROM TB_SKC_FP_RS_PRDT_PLAN_MIX  X WITH(NOLOCK)
                        WHERE VER_ID =                                         
                                      (
                                             SELECT TOP 1 VERSION
                                               FROM VW_FP_PLAN_VERSION WITH(NOLOCK)
                                              WHERE INIT_CNFM_YN = 'Y'
                                                AND CONVERT(NVARCHAR(6), PLAN_DT, 112) = @P_BASE_YYYYMM
                                         )
                          AND EXISTS   (   SELECT 1
                                             FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                                            WHERE SCM_USE_YN = 'Y'
                                              AND X.RSRC_CD  = Y.RSRC_CD
											  AND Y.RSRC_CD != 'SSP20'    -- 고상은 제외
                                       )
                          AND ADJ_PLAN_QTY       > 0
                          --AND LEFT(PLAN_DTE, 6)  = @P_BASE_YYYYMM
                  ) X
              GROUP BY BASE_YYYYMM
                  , RSRC_CD
                  , PLAN_DTE
                  , PRDT_GRADE_CD
        END

        -----------------------------------
        -- 조회 (수정)
        -----------------------------------
        IF OBJECT_ID('tempdb..#TM_FP_LAST') IS NOT NULL DROP TABLE #TM_FP_LAST -- 임시테이블 삭제

        BEGIN
             SELECT BASE_YYYYMM                                                                            AS BASE_YYYYMM
                  , RSRC_CD                                                                                AS RSRC_CD
                  , PLAN_DTE                                                                               AS PLAN_DTE
                  , PRDT_GRADE_CD                                                                          AS PRDT_GRADE_CD
                  , SUM(1)																				   AS GC_CNT
                  , SUM(GC_QTY)                                                                            AS GC_QTY
               INTO #TM_FP_LAST
               FROM (
                       SELECT LEFT(PLAN_DTE, 6)                              AS BASE_YYYYMM
                            , RSRC_CD                                        AS RSRC_CD
                            , PLAN_DTE                                       AS PLAN_DTE
                            , TO_PRDT_GRADE_CD                               AS PRDT_GRADE_CD
                            --, ITEM_CD                                        AS ITEM_CD
                            , (ADJ_PLAN_QTY)                                 AS GC_QTY
                            --, LAG(RSRC_CD) OVER(PARTITION BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD ORDER BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD, X.PLAN_DTE)  AS PREV_RSRC_CD
                            --, LAG(ITEM_CD) OVER(PARTITION BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD ORDER BY X.CORP_CD, X.PLNT_CD, X.RSRC_CD, X.PLAN_DTE)  AS PREV_ITEM_CD

                         FROM TB_SKC_FP_RS_PRDT_PLAN_MIX  X WITH(NOLOCK)
                        WHERE VER_ID =                                          
                                      (
                                             SELECT MAX(VERSION)
                                               FROM VW_FP_PLAN_VERSION WITH(NOLOCK)
                                              WHERE CNFM_YN = 'Y'
                                                AND CONVERT(NVARCHAR(6), PLAN_DT, 112) = @P_BASE_YYYYMM
                                         )
                          AND EXISTS   (   SELECT 1
                                             FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                                            WHERE SCM_USE_YN = 'Y'
                                              AND X.RSRC_CD  = Y.RSRC_CD
											  AND Y.RSRC_CD != 'SSP20'    -- 고상은 제외
                                       )
                          AND ADJ_PLAN_QTY       > 0
                          --AND LEFT(PLAN_DTE, 6)  = @P_BASE_YYYYMM
                  ) X
              GROUP BY BASE_YYYYMM
                  , RSRC_CD
                  , PLAN_DTE
                  , PRDT_GRADE_CD
        END

      --SELECT * FROM #TM_FP_FIRST
      --SELECT * FROM #TM_FP_LAST

	  INSERT INTO TM_SA1140
             SELECT @P_BASE_YYYYMM                                        AS BASE_YYYYMM
                  , X.RSRC_CD                                            AS RSRC_CD
				  , (SELECT TOP 1 SCM_RSRC_NM FROM TB_SKC_FP_RSRC_MST L WHERE X.RSRC_CD = L.RSRC_CD) AS RSRC_NM
                  , SUM(X.F_GC_CNT)                                      AS F_GC_CNT
                  , SUM(X.L_GC_CNT)                                      AS L_GC_CNT
                  , SUM(X.F_GC_CNT) - SUM(X.L_GC_CNT)                    AS GAP_CNT
                  , SUM(X.F_GC_QTY)                                      AS F_GC_QTY
                  , SUM(X.L_GC_QTY)                                      AS L_GC_QTY
                  , SUM(X.F_GC_QTY) - SUM(X.L_GC_QTY)                    AS GAP_QTY
                  , MAX(ISNULL(P.AVG_RAB_AMT,0))                         AS PROP_COST   -- 비례비
                  , SUM(P.AVG_RAB_AMT) * ISNULL(SUM(X.F_GC_QTY) - SUM(X.L_GC_QTY),1)    AS GC_COST     -- 품변 기회비용 : 품변 Mix량 Gap x 판매가 Gap

               FROM (
                       SELECT BASE_YYYYMM           AS BASE_YYYYMM
                            , RSRC_CD               AS RSRC_CD
                            , GC_CNT                AS F_GC_CNT
                            , GC_QTY                AS F_GC_QTY
                            , 0                     AS L_GC_CNT
                            , 0                     AS L_GC_QTY
                         FROM #TM_FP_FIRST
                        UNION ALL
                       SELECT BASE_YYYYMM           AS BASE_YYYYMM
                            , RSRC_CD               AS RSRC_CD
                            , 0                     AS F_GC_CNT
                            , 0                     AS F_GC_QTY
                            , GC_CNT                AS L_GC_CNT
                            , GC_QTY                AS L_GC_QTY
                         FROM #TM_FP_LAST
                    ) X
                    LEFT JOIN (  SELECT SUM(AVG_RAB_AMT) AS AVG_RAB_AMT  -- 판매가 Gap
                                   FROM #TM_SALES_AMT A
                              ) P
                           ON 1=1

              WHERE 1=1
                AND EXISTS (SELECT 1
                              FROM TB_SKC_FP_RSRC_MST Y WITH(NOLOCK)
                             WHERE SCM_USE_YN = 'Y'
                               AND X.RSRC_CD  = Y.RSRC_CD
                               AND Y.PLNT_CD IN ('1230', '1110')
							   AND Y.RSRC_CD != 'SSP20'    -- 고상은 제외
                           )
              GROUP BY X.RSRC_CD--, X.BASE_YYYYMM

END

GO
