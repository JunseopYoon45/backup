USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2050_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2050_Q1] (
     @P_BASE_YYYY             NVARCHAR(100)   = NULL    -- 기준년도
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2050_Q1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 평가감 금액 현황
--                    법인별 평가감 예상 환입 금액에 대한 목표 및 실적을 조회하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-15  AJS            신규 생성
-- 2024-09-02  AJS            상해 제외
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2050_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2050_Q1   '2024', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYY            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN
    -----------------------------------
    -- 조회
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT MST.CORP_CD                     AS CORP_CD
             , MST.CORP_NM                     AS CORP_NM
             , CAL.YYYYMM                      AS YYYYMM
             , MEA.WR_TYPE                     AS WR_TYPE
             , MEA.MEASURE_CD                  AS MEASURE_CD
             , MEA.MEASURE_NM                  AS MEASURE_NM
             , WRA.WR_AMT / 100000000          AS WR_AMT
          FROM (  SELECT DISTINCT
                         CORP_CD
                       , CORP_NM
                    FROM TB_SKC_CM_PLNT_MST WITH(NOLOCK)
                   WHERE CORP_CD NOT IN ( 'Y100', 'C100')
               ) MST

               FULL
               JOIN (  SELECT DISTINCT
                              YYYYMM
                         FROM TB_CM_CALENDAR WITH(NOLOCK)
                        WHERE YYYY = @P_BASE_YYYY
                    ) CAL
                 ON 1=1

               FULL
               JOIN (  SELECT COMN_CD          AS MEASURE_CD
                            , COMN_CD_NM       AS MEASURE_NM
                            , ATTR_01_VAL      AS WR_TYPE
                            , SEQ              AS SEQ
                         FROM FN_COMN_CODE('SA2050','')
                    ) MEA
                 ON 1=1

               LEFT
               JOIN (  SELECT *
                         FROM TB_SKC_SA_WR_AMT_REPORT WITH(NOLOCK)
                        WHERE LEFT(BASE_YYYYMM, 4) = @P_BASE_YYYY
                    ) WRA
                 ON MST.CORP_CD  = WRA.CORP_CD
                AND CAL.YYYYMM   = WRA.BASE_YYYYMM
                AND MEA.WR_TYPE  = WRA.WR_TYPE

         ORDER BY MST.CORP_CD
             , MEA.SEQ
             , CAL.YYYYMM

END

GO
