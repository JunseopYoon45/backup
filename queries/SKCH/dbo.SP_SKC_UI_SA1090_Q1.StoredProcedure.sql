USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1090_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1090_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1090_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 비정상 재고  상세
--                    비정상 재고 수량을 상세 lv로 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-20  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1090_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1090_Q1  '202407','202409','ko','I23671','UI_SA1090'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1090','')

    ---------------------------------
    -- RAW
    ---------------------------------
    BEGIN
          EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1090_RAW_Q1
               @P_FR_YYYYMM                -- 기준년월
             , @P_TO_YYYYMM                -- 기준년월
             , @P_LANG_CD                  -- LANG_CD (ko, en)
             , @P_USER_ID                  -- USER_ID
             , 'UI_SA1090'                 -- VIEW_ID
          ;
     END
    -----------------------------------
    -- 조회
    -----------------------------------

        SELECT *
          FROM (
                  SELECT X.YYYYMM                             AS YYYYMM
                       , X.BRAND                              AS BRAND
                       , Y.MEASURE_CD                         AS MEASURE_CD
                       , Y.MEASURE_NM                         AS MEASURE_NM
                       , ( CASE WHEN MEASURE_CD = '01' THEN ISNULL(TOT_STCK_QTY, 0)                                         -- 총재고
                                WHEN MEASURE_CD = '02' THEN ISNULL(ON_SPEC_STCK_QTY ,0)                                    -- 정상재고
                                WHEN MEASURE_CD = '03' THEN ISNULL(OFF_SPEC_STCK_QTY,0)                                    -- 비정상재고
                                WHEN MEASURE_CD = '04' THEN ISNULL(OFF_SPEC_STCK_QTY / TOT_STCK_QTY  * 100,0)              -- 비정상재고율
                            END)                              AS QTY

                    FROM TM_SA1090 X WITH(NOLOCK)
                       , #TM_MEASURE Y
                   UNION ALL
                  SELECT YYYYMM                               AS YYYYMM
                       , 'Sum'                                AS BRAND
                       , Y.MEASURE_CD                         AS MEASURE_CD
                       , Y.MEASURE_NM                         AS MEASURE_NM
                       , ( CASE WHEN MEASURE_CD = '01' THEN ISNULL(SUM(TOT_STCK_QTY   ), 0)                                 -- 총재고
                                WHEN MEASURE_CD = '02' THEN ISNULL(SUM(ON_SPEC_STCK_QTY ), 0)                               -- 정상재고
                                WHEN MEASURE_CD = '03' THEN ISNULL(SUM(OFF_SPEC_STCK_QTY), 0)                               -- 비정상재고
                                WHEN MEASURE_CD = '04' THEN ISNULL(SUM(OFF_SPEC_STCK_QTY) / SUM(TOT_STCK_QTY) * 100, 0)     -- 비정상재고율
                            END)                              AS QTY
                    FROM TM_SA1090 X WITH(NOLOCK)
                       , #TM_MEASURE Y
                   GROUP BY YYYYMM
                          , Y.MEASURE_CD
                          , Y.MEASURE_NM
                --          , BRAND
                ) X
         ORDER BY BRAND
             , YYYYMM
             , MEASURE_CD

			 
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1090') IS NOT NULL  DROP TABLE TM_SA1090
END

GO
