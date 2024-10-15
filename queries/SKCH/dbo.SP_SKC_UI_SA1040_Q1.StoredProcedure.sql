USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1040_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1040_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1040_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 판매 계획 달성률 / 정확도
--                   판매계획 대비 판매실적 달성률,  판매계획 정확도를 조회하는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-21  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1040_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_SA1040_Q1 '202406','ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_BASE_YYYYMM           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
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
          FROM FN_COMN_CODE('SA1040','')

    ---------------------------------
  -- RAW DATA
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1040_RAW_Q1
         @P_BASE_YYYYMM             -- 기준년월
       , @P_LANG_CD                 -- LANG_CD (ko, en)
       , @P_USER_ID                 -- USER_ID
       , @P_VIEW_ID                 -- VIEW_ID
    ;

    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT MEASURE_CD                                                    AS MEASURE_CD
             , MEASURE_NM                                                    AS MEASURE_NM
             , CORP_CD                                                       AS CORP_CD
             , CORP_NM                                                       AS CORP_NM
             , CASE WHEN MEASURE_CD = '01' THEN ISNULL(SUM(M1_QTY   ),0) / 1000                                                    -- 수요계획
                    WHEN MEASURE_CD = '02' THEN ISNULL(SUM(RTF_QTY  ),0) / 1000                                                    -- 판매계획
                    WHEN MEASURE_CD = '03' THEN ISNULL(SUM(SALES_QTY),0) / 1000                                                    -- 판매실적
                    WHEN MEASURE_CD = '04' THEN ISNULL(ISNULL(SUM(SALES_QTY),0) / ISNULL(SUM(RTF_QTY),0) * 100              ,0)    -- 달성률
                    WHEN MEASURE_CD = '05' THEN ISNULL(ISNULL(SUM(RTF_QTY * ACRCY_RATE),0)  / ISNULL(SUM(RTF_QTY  ),0),0)     -- 정확도
               END                                                           AS QTY

          FROM TM_SA1040 A WITH(NOLOCK)
             , #TM_MEASURE M
         GROUP BY CORP_CD, CORP_NM
             , MEASURE_CD
             , MEASURE_NM
         UNION ALL
        SELECT MEASURE_CD                                                    AS MEASURE_CD
             , MEASURE_NM                                                    AS MEASURE_NM
             , '9999'                                                        AS CORP_CD
             , ' Total'                                                        AS CORP_NM
             , CASE WHEN MEASURE_CD = '01' THEN ISNULL(SUM(M1_QTY   ),0) / 1000                                                    -- 수요계획
                    WHEN MEASURE_CD = '02' THEN ISNULL(SUM(RTF_QTY  ),0) / 1000                                                    -- 판매계획
                    WHEN MEASURE_CD = '03' THEN ISNULL(SUM(SALES_QTY),0) / 1000                                                    -- 판매실적
                    WHEN MEASURE_CD = '04' THEN ISNULL(ISNULL(SUM(SALES_QTY),0) / ISNULL(SUM(RTF_QTY),0) * 100              ,0)    -- 달성률
                    WHEN MEASURE_CD = '05' THEN ISNULL(ISNULL(SUM(RTF_QTY * ACRCY_RATE),0)  / ISNULL(SUM(RTF_QTY  ),0) ,0)    -- 정확도
                END                                                          AS QTY
          FROM TM_SA1040 A WITH(NOLOCK)
             , #TM_MEASURE M
         GROUP BY MEASURE_CD
             , MEASURE_NM
         ORDER BY MEASURE_CD, CORP_NM

		 
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1040') IS NOT NULL DROP TABLE TM_SA1040

END

GO
