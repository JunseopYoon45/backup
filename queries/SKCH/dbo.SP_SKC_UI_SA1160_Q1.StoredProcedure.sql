USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1160_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1160_Q1] (
     @P_BASE_DATE           NVARCHAR(100)   = NULL    -- 기준일자
   , @P_LANG_CD             NVARCHAR(100)    = NULL    -- LANG_CD (ko, en)  2024.05.22 AJS
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1160_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 실시간 재고 현황
--                   GC사업부 전체 기준 보유하고 있는 총 재고량에 대한 현황 조회화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-03-22  AJS            신규 생성
-- 2023-04-16  AJS            정상/비정상 코드 변경
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1160_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1160_Q1 '20240605','ko','I23779','UI_IM1010'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_DATE   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD     ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID     ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID     ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'IM',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @V_TO_DAY NVARCHAR(10) = (SELECT CONVERT(NVARCHAR(10), MAX(BASE_DATE), 112) FROM TB_SKC_CM_FERT_STCK_HST)

    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1160','')
		  
    -----------------------------------
    -- #TM_QTY
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT *
          INTO #TM_QTY
          FROM (
                  SELECT X.CORP_CD                                                                                             AS CORP_CD
                       , (  SELECT TOP 1 CASE WHEN @P_LANG_CD = 'en' THEN CORP_NM_EN
                                              ELSE CORP_NM
                                          END
                              FROM VW_CORP_PLNT K
                             WHERE K.CORP_CD = X.CORP_CD)                                                                      AS CORP_NM
                       , CASE WHEN X.PLNT_TYPE_GRP_CD = '03' THEN '99'
                              ELSE X.PLNT_TYPE_GRP_CD
                          END                                                                                                  AS PLNT_TYPE_CD
                       , CASE WHEN @P_LANG_CD = 'en' THEN X.PLNT_TYPE_GRP_NM_EN ELSE X.PLNT_TYPE_GRP_NM END                    AS PLNT_TYPE_NM
                       , SUM(STCK_QTY)                                                                                         AS TOT_STCK_QTY
                       , SUM(CASE WHEN X.NRML_TYPE_CD    = '01' THEN STCK_QTY ELSE 0 END)                                      AS ON_SPEC_STCK_QTY
                       , SUM(CASE WHEN X.NRML_TYPE_CD    = '02' THEN STCK_QTY ELSE 0 END)                                      AS OFF_SPEC_STCK_QTY   -- unusualness  -- 비정상 재고수량
                       , ISNULL(ROUND(MAX(CASE WHEN X.PLNT_TYPE_GRP_CD != '00' THEN W.WRITE_DOWN_AMT ELSE 0 END ),0) ,0)                 AS WRITE_DOWN_AMT        --
                    FROM (
                            SELECT A.CORP_CD                                                          AS CORP_CD
                                 , A.WRHS_CD                                                          AS WRHS_CD
                                 , A.WRHS_GRP_CD                                                      AS WRHS_GRP_CD
                                 , A.WRHS_GRP_NM                                                      AS WRHS_GRP_NM
                                 , A.PLNT_TYPE_GRP_CD                                                 AS PLNT_TYPE_GRP_CD
                                 , A.PLNT_TYPE_GRP_NM                                                 AS PLNT_TYPE_GRP_NM
                                 , A.PLNT_TYPE_GRP_NM_EN                                              AS PLNT_TYPE_GRP_NM_EN
                                 , A.ITEM_CD                                                          AS ITEM_CD
                                 , B.MDM_NRML_TYPE_CD                                                 AS NRML_TYPE_CD
                                 , SUM(A.STCK_QTY) / 1000                                             AS STCK_QTY
                              FROM TB_SKC_CM_FERT_STCK_HST A WITH(NOLOCK)
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
                               AND A.BASE_DATE     = @V_TO_DAY
                               AND A.STCK_STUS_CD IN ('가용')
                               AND EXISTS (SELECT 1
                                             FROM TB_SKC_CM_PLNT_MST Z WITH(NOLOCK)
                                            WHERE A.PLNT_CD = Z.PLNT_CD
                                              AND Z.STCK_YN = 'Y'
                                           )

                          GROUP BY A.CORP_CD
                                 , A.WRHS_CD
                                 , A.WRHS_GRP_CD
                                 , A.WRHS_GRP_NM
                                 , A.PLNT_TYPE_GRP_CD
                                 , A.PLNT_TYPE_GRP_NM
                                 , A.PLNT_TYPE_GRP_NM_EN
                                 , A.ITEM_CD
                                 , B.MDM_NRML_TYPE_CD

                             UNION ALL
                            SELECT B.CORP_CD                                                                    AS CORP_CD
                                 --, B.PLNT_CD                                                                  AS PLNT_CD
                                 , NULL                                                                         AS WRHS_CD
                                 , NULL                                                                         AS WRHS_GRP_CD
                                 , NULL                                                                         AS WRHS_GRP_NM
                                 , '00'                                                                         AS PLNT_TYPE_GRP_CD
                                 , 'In-Transit'                                                                 AS PLNT_TYPE_GRP_NM
                                 , 'In-Transit'                                                                 AS PLNT_TYPE_GRP_NM_EN
                                 , A.ITEM_CD                                                                    AS ITEM_CD
                                 , '01'                                                                         AS NRML_TYPE_CD
                                 , SUM(A.KG_STCK_QTY) / 1000                                                    AS STCK_QTY
                              FROM TB_SKC_CM_TRNS_STCK A  WITH(NOLOCK)
                                 , VW_PORT_PLANT       B WITH(NOLOCK)
                             WHERE A.CNTRY_CD    = B.CNTRY_CD
                               AND A.PORT_CD     = B.POD_CD
                               AND CONVERT(NVARCHAR(10), A.ETA_DATE , 112) > @V_TO_DAY        --ETA 일이 도래하지 않은 케이스는 전부 이동 중 재고 대상
                               AND B.CORP_CD                           != 'ZZZ'
                               AND CONVERT(NVARCHAR(6), BILL_DATE,112) <= LEFT(@V_TO_DAY,6)
                               AND BILL_NO IS NOT NULL
                             GROUP BY B.CORP_CD
                                    ,  A.ITEM_CD
                         ) X

                         LEFT JOIN (
                                      SELECT BASE_YYYYMM
                                           , CORP_CD
                                           , PLNT_TYPE_CD
                                           , WRITE_DOWN_QTY
                                           , WRITE_DOWN_AMT
                                        FROM TB_SKC_CM_WRITE_DOWN_EOH_MST WITH(NOLOCK)
                                       WHERE BASE_YYYYMM = LEFT(@V_TO_DAY, 6)
                                   ) W
                                ON X.CORP_CD          = W.CORP_CD
                               AND X.PLNT_TYPE_GRP_CD = W.PLNT_TYPE_CD

                    GROUP BY  X.CORP_CD
                       , PLNT_TYPE_GRP_CD
                       , PLNT_TYPE_GRP_NM
                       , PLNT_TYPE_GRP_NM_EN

               ) A


      -----------------------------------
      -- 조회
      -----------------------------------


        SELECT *
          FROM (
                  SELECT X.CORP_CD                                 AS CORP_CD
                       , X.CORP_NM                                 AS CORP_NM
                       , X.PLNT_TYPE_CD                            AS PLNT_TYPE_CD
                       , X.PLNT_TYPE_NM                            AS PLNT_TYPE_NM
                       , Y.MEASURE_CD                              AS MEASURE_CD
                       , Y.MEASURE_NM                              AS MEASURE_NM
                       , ( CASE WHEN MEASURE_CD = '01' THEN TOT_STCK_QTY                                         -- 총재고
                                WHEN MEASURE_CD = '02' THEN ON_SPEC_STCK_QTY                                     -- 정상재고
                                WHEN MEASURE_CD = '03' THEN OFF_SPEC_STCK_QTY                                    -- 비정상재고
                                WHEN MEASURE_CD = '04' THEN WRITE_DOWN_AMT / 1000000                             -- 평가감 금액
                            END)                                   AS QTY

                    FROM #TM_QTY X WITH(NOLOCK)
                       , #TM_MEASURE Y
                   UNION ALL
                  SELECT '00'                                      AS BRAND
                       , 'Total'                                   AS CORP_NM
                       , 'Total'                                   AS PLNT_TYPE_CD
                       , 'Total'                                   AS PLNT_TYPE_NM
                       , Y.MEASURE_CD                              AS MEASURE_CD
                       , Y.MEASURE_NM                              AS MEASURE_NM
                       , ( CASE WHEN MEASURE_CD = '01' THEN SUM(TOT_STCK_QTY   )                                 -- 총재고
                                WHEN MEASURE_CD = '02' THEN SUM(ON_SPEC_STCK_QTY )                               -- 정상재고
                                WHEN MEASURE_CD = '03' THEN SUM(OFF_SPEC_STCK_QTY)                               -- 평가감 수량
                                WHEN MEASURE_CD = '04' THEN SUM(WRITE_DOWN_AMT) / 1000000                        -- 평가감 금액
                            END)                                   AS QTY
                    FROM #TM_QTY X WITH(NOLOCK)
                       , #TM_MEASURE Y
                   GROUP BY Y.MEASURE_CD
                          , Y.MEASURE_NM
                ) X
         ORDER BY CORP_CD
                , PLNT_TYPE_CD
                , MEASURE_CD

END

GO
