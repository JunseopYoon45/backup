USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q1] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q1
-- COPYRIGHT       : AJS
-- REMARK          : Main (사업 계획 달성률)
--                    SCM Main 운영지표에 대해서 GC 사업부 기준 종합 숫자를 조회할 수 있는 Main 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-18  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q1 'ko','I21023','UI_SA1010'
EXEC SP_SKC_UI_SA1010_Q1 'ko','I21023','HOME'
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

--------------------------------
   DECLARE @V_TO_YYYYMM       NVARCHAR(6) = CONVERT(NVARCHAR(4), GETDATE(), 112) + '12'
   DECLARE @V_FR_YYYYMM       NVARCHAR(6) = CONVERT(NVARCHAR(4), GETDATE(), 112) + '01'
   DECLARE @V_MAX_ACT_YYYYMM  NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일


    ---------------------------------
    -- #TM_MEASURE
    ---------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD                         AS MEASURE_CD
             , COMN_CD_NM                      AS MEASURE_NM
             , SEQ                             AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1010_1','')

    ---------------------------------
    -- RAW
    ---------------------------------
    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1030_RAW_Q1
         @V_FR_YYYYMM                -- 기준년월
       , @V_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , 'UI_SA1010'                 -- VIEW_ID
    ;

    -----------------------------------
    -- 조회
    -----------------------------------

    BEGIN
        SELECT BASE_DATE                                           AS BASE_DATE
             , MEASURE_CD                                          AS MEASURE_CD
             , MEASURE_NM                                          AS MEASURE_NM
             , ( CASE WHEN MEASURE_CD = '01' THEN ISNULL(ANNUAL_QTY , 0)
                      WHEN MEASURE_CD = '02' THEN ISNULL(SALES_QTY  , 0)
                      WHEN MEASURE_CD = '03' THEN ISNULL((SALES_QTY / ANNUAL_QTY ) * 100 , 0)
                  END)                                             AS QTY
          FROM (
                  SELECT BASE_YYYYMM      AS BASE_DATE
                       , MEASURE_CD                                AS MEASURE_CD
                       , MEASURE_NM                                AS MEASURE_NM
                       , SUM(ANNUAL_QTY) / 1000                    AS ANNUAL_QTY   -- 사업계획
                       , SUM(SALES_QTY ) / 1000                    AS SALES_QTY    -- 판매실적
                    FROM TM_SA1010 X
                       , #TM_MEASURE Y
                   GROUP BY BASE_YYYYMM
                       , MEASURE_CD
                       , MEASURE_NM
               ) A

         UNION ALL
        SELECT BASE_YYYYMM                                         AS BASE_YYYYMM
             , MEASURE_CD                                          AS MEASURE_CD
             , MEASURE_NM                                          AS MEASURE_NM
             , ( CASE WHEN MEASURE_CD = '01' THEN ISNULL(ANNUAL_QTY , 0)
                      WHEN MEASURE_CD = '02' THEN ISNULL(SALES_QTY  , 0)
                      WHEN MEASURE_CD = '03' THEN ISNULL((SALES_QTY / ANNUAL_QTY ) * 100 , 0)
                  END)                                             AS QTY
          FROM (
                  SELECT 'Sum'                                     AS BASE_YYYYMM
                       , MEASURE_CD                                AS MEASURE_CD
                       , MEASURE_NM                                AS MEASURE_NM
                       , SUM(ANNUAL_QTY) / 1000                    AS ANNUAL_QTY   -- 사업계획
                       , SUM(SALES_QTY ) / 1000                    AS SALES_QTY    -- 판매실적
                    FROM TM_SA1010 X
                       , #TM_MEASURE Y
                   WHERE BASE_YYYYMM BETWEEN @V_FR_YYYYMM AND @V_MAX_ACT_YYYYMM
                   GROUP BY MEASURE_CD
                       , MEASURE_NM
               ) A
         ORDER BY 1,2,3
    END
	
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1010') IS NOT NULL DROP TABLE TM_SA1010



END
GO
