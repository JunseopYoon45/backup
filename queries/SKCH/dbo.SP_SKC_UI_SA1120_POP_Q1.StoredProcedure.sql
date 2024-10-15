USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1120_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1120_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_RSRC_CD               NVARCHAR(100)   = NULL    -- 라인
   , @P_PRDT_GRADE_CD         NVARCHAR(100)   = NULL    -- 생산 Grade
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1120_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 목표 품종 생산율
--                   울산공장의 생산라인별로 목표한 제품의 생산 달성률을 조회하는 상세 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1120_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1120_POP_Q1 '202405','CPR20','ALL','ko','I23779','UI_SA1120'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_GRADE_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    ---------------------------------
    -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1120_RAW_Q1
         @P_BASE_YYYYMM                   -- 기준년월
       , @P_BASE_YYYYMM                   -- 기준년월
       , @P_LANG_CD                       -- LANG_CD (ko, en)
       , @P_USER_ID                       -- USER_ID
       , @P_VIEW_ID                       -- VIEW_ID
    ;


    -----------------------------------
    -- 조회 (전체) : 목표 품종 생산율
    -----------------------------------
    BEGIN

        SELECT RSRC_CD                                   AS RSRC_CD
             , RSRC_NM                                   AS RSRC_NM
             , BRAND                                     AS BRAND
             , PRDT_GRADE_CD                             AS PRDT_GRADE_CD
             , NRML_TYPE_CD                              AS NRML_TYPE_CD
             , NRML_TYPE_NM                              AS NRML_TYPE_NM
             , SUM(PLAN_QTY) / 1000                      AS PLAN_QTY
             , SUM(ACT_QTY ) / 1000                      AS ACT_QTY
             , SUM(ACT_QTY ) / SUM(PLAN_QTY)  * 100      AS RATE
          FROM TM_SA1120 WITH(NOLOCK)
         WHERE RSRC_CD = @P_RSRC_CD
		   AND YYYYMM  = @P_BASE_YYYYMM
         GROUP BY RSRC_CD
		     , RSRC_NM
             , BRAND
             , PRDT_GRADE_CD
             , NRML_TYPE_CD
             , NRML_TYPE_NM
    END

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1120') IS NOT NULL  DROP TABLE TM_SA1120
END

GO
