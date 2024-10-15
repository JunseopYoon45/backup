USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q5]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q5] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q5
-- COPYRIGHT       : AJS
-- REMARK          : Main (목표 품종 생산율)
--                   울산공장의 생산라인별로 목표한 제품의 생산 달성률을 조회하는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-23  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q5' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q5 'ko','I23779',''

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN
    -----------------------------------
    --  기준년월
    -----------------------------------
    DECLARE @V_TO_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일
    DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @V_TO_YYYYMM + '01'), 112)
    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1120_RAW_Q1
         @V_FR_YYYYMM                -- 기준년월
       , @V_TO_YYYYMM                -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;

    -----------------------------------
    -- 조회 (전체)
    -----------------------------------
    BEGIN

        SELECT YYYYMM                                                               AS YYYYMM
             , SUM(PLAN_QTY) / 1000                                                 AS PLAN_QTY
             , SUM(ACT_QTY ) / 1000                                                 AS ACT_QTY
             , ISNULL(ISNULL(SUM(ACT_QTY ),0) / ISNULL(SUM(PLAN_QTY),0),0)  * 100   AS RATE
          FROM TM_SA1120 WITH(NOLOCK)
         WHERE YYYYMM BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
         GROUP BY YYYYMM
         ORDER BY YYYYMM
    END

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1120') IS NOT NULL DROP TABLE TM_SA1120

END

GO
