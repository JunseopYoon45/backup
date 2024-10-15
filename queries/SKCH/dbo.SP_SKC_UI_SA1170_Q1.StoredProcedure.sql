USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1170_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1170_Q1] (
     @P_FROM_YYYYMM         NVARCHAR(100)   = NULL    -- 기준일자
   , @P_TO_YYYYMM           NVARCHAR(100)   = NULL    -- 기준일자
   , @P_LANG_CD             NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)  2024.05.22 AJS
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1170_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 해외법인 재고현황
--                   해외법인별 재고 및 평가감 재고 6개월 Trend를 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-09-19  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1170_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1170_Q1 '202404','202409','ko','I23671','UI_SA1170'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FROM_YYYYMM ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD     ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID     ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID     ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'IM',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------

BEGIN

   DECLARE @P_FROM_YYYYMMDD NVARCHAR(10) =  @P_FROM_YYYYMM + '01'
   DECLARE @V_TO_YYYYMMDD   NVARCHAR(10) =   (SELECT CONVERT(NVARCHAR(8),EOMONTH(@P_TO_YYYYMM+'01'), 112))



   PRINT @V_TO_YYYYMMDD

    IF OBJECT_ID('tempdb..#TM_BASE_YYYYMM') IS NOT NULL DROP TABLE #TM_BASE_YYYYMM -- 임시테이블 삭제

        SELECT MAX(CONVERT(NVARCHAR(8), IF_STD_DATE, 112))  AS YYYYMM
          INTO #TM_BASE_YYYYMM
          FROM TB_SKC_CM_FERT_EOH_HST
		 WHERE CONVERT(NVARCHAR(6), IF_STD_DATE, 112) BETWEEN @P_FROM_YYYYMM AND @P_TO_YYYYMM GROUP BY CONVERT(NVARCHAR(6), IF_STD_DATE, 112)

    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1170','')



    -----------------------------------
    -- 조회
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT *
          INTO #TM_QTY
          FROM (
                  SELECT YYYYMM
                       , X.CORP_CD                                                                                             AS CORP_CD
                       , (  SELECT TOP 1 CASE WHEN @P_LANG_CD = 'en' THEN CORP_NM_EN
                                              ELSE CORP_NM
                                          END
                              FROM VW_CORP_PLNT K
                             WHERE K.CORP_CD = X.CORP_CD)                                                                      AS CORP_NM
                       , CASE WHEN X.PLNT_TYPE_GRP_CD = '03' THEN '99'
                              ELSE X.PLNT_TYPE_GRP_CD
                          END                                                                                                  AS PLNT_TYPE_CD
                       , PLNT_TYPE_GRP_NM                                                                                      AS PLNT_TYPE_GRP_NM
                       , SUM(STCK_QTY)                                                                                         AS TOT_STCK_QTY
                       , ISNULL(ROUND(MAX(CASE WHEN X.PLNT_TYPE_GRP_CD != '00' THEN W.WRITE_DOWN_QTY ELSE 0 END ),0) ,0)       AS WRITE_DOWN_QTY
                    FROM (
                            SELECT CONVERT(NVARCHAR(6), A.IF_STD_DATE, 112)                           AS YYYYMM
                                 , A.CORP_CD                                                          AS CORP_CD
                                 , '90'                                                               AS PLNT_TYPE_GRP_CD
                                 , N'창고'                                                            AS PLNT_TYPE_GRP_NM
                                 , SUM(A.STCK_QTY) / 1000                                             AS STCK_QTY
                              FROM TB_SKC_CM_FERT_EOH_HST A WITH(NOLOCK)
                                 , (  SELECT A.ITEM_CD
                                           , B.MDM_NRML_TYPE_CD
                                        FROM TB_CM_ITEM_MST A  WITH(NOLOCK)
                                           , (  SELECT COD.COMN_CD                AS COMN_CD
                                                     , COD.ATTR_01_VAL            AS MDM_NRML_TYPE_CD
                                                  FROM TB_AD_COMN_CODE COD  WITH(NOLOCK)
                                                 WHERE COD.SRC_ID = (SELECT MAX(ID) FROM dbo.TB_AD_COMN_GRP  WITH(NOLOCK) WHERE GRP_CD = 'NRML_TYPE_MDM')
                                             ) B
                                       WHERE A.ATTR_14     = B.COMN_CD                                -- NRML_TYPE_CD
                                         AND A.ATTR_04    IN ( '11', '1B')                            -- ITEM_GRP_CD : 제품그룹코드 (COPOLYESTER)
                                         AND A.ITEM_TP_ID != 'GHLB'

                                   ) B

                             WHERE A.ITEM_CD       = B.ITEM_CD
                               AND CONVERT(NVARCHAR(8), A.IF_STD_DATE, 112)    IN (SELECT YYYYMM FROM #TM_BASE_YYYYMM)
                               AND A.CORP_CD != '1000'
                               AND A.STCK_STUS_CD IN ('가용')
                               AND EXISTS (SELECT 1
                                             FROM TB_SKC_CM_PLNT_MST Z WITH(NOLOCK)
                                            WHERE A.PLNT_CD = Z.PLNT_CD
                                              AND Z.STCK_YN = 'Y'
                                           )

                          GROUP BY A.CORP_CD
                                 , CONVERT(NVARCHAR(6), A.IF_STD_DATE, 112)
                                 , A.WRHS_CD
                                 , A.ITEM_CD
                                 , B.MDM_NRML_TYPE_CD

                             UNION ALL
                            SELECT BASE_YYYYMM   AS YYYYMM
                                 , CORP_CD                                                                 AS CORP_CD
                                 , '00'                                                                    AS PLNT_TYPE_GRP_CD
                                 , 'In-Transit'                                                            AS PLNT_TYPE_GRP_NM
                                 , SUM(A.STCK_QTY) / 1000                                                  AS STCK_QTY
                              FROM TB_SKC_CM_TRNS_STCK_EOH A  WITH(NOLOCK)
                             WHERE BASE_YYYYMM BETWEEN @P_FROM_YYYYMM AND @P_TO_YYYYMM
                             GROUP BY CORP_CD
                                    , A.BASE_YYYYMM
                         ) X

                         LEFT JOIN (
                                      SELECT BASE_YYYYMM
                                           , CORP_CD
                                           , PLNT_TYPE_CD
                                           , WRITE_DOWN_QTY
                                        FROM TB_SKC_CM_WRITE_DOWN_EOH_MST WITH(NOLOCK)
                                       WHERE BASE_YYYYMM BETWEEN @P_FROM_YYYYMM AND @P_TO_YYYYMM
                                   ) W
                                ON X.CORP_CD          = W.CORP_CD
                               AND X.PLNT_TYPE_GRP_CD = W.PLNT_TYPE_CD
							   AND X.YYYYMM			  = W.BASE_YYYYMM

                   GROUP BY X.YYYYMM
                          , X.CORP_CD
                          , PLNT_TYPE_GRP_CD
                          , PLNT_TYPE_GRP_NM

               ) A


      -----------------------------------
      -- 조회
      -----------------------------------
        SELECT CORP_CD                              AS CORP_CD
             , CORP_NM                              AS CORP_NM
             , YYYYMM                               AS YYYYMM
             , Y.MEASURE_CD                         AS MEASURE_CD
             , Y.MEASURE_NM                         AS MEASURE_NM
             , SUM ( CASE WHEN MEASURE_CD = '01' AND PLNT_TYPE_CD = '90' THEN TOT_STCK_QTY             -- 총재고
                          WHEN MEASURE_CD = '02' AND PLNT_TYPE_CD = '00' THEN TOT_STCK_QTY             -- 정상재고
                          WHEN MEASURE_CD = '03' THEN WRITE_DOWN_QTY                                   -- 평가감 수량
                      END)                              AS QTY
          FROM #TM_QTY X
         , #TM_MEASURE Y
         GROUP BY CORP_CD
                , CORP_NM
                , YYYYMM
                , Y.MEASURE_CD
                , Y.MEASURE_NM
         ORDER BY 1,2,3,4,5
END

GO
