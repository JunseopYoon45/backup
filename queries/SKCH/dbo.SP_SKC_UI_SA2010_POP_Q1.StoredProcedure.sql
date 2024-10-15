USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2010_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2010_POP_Q1] (
     @P_GRADE_CD              NVARCHAR(100)   = NULL    -- Grade         2024.08.21 AJS
   , @P_REGION_SUM_YN         NVARCHAR(100)   = NULL    -- 권역계 여부    2024.08.13 AJS
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2010_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 수요계획 比 출고량 - 지역별 Gap (Pop-up)
--           판매계획과 출하실적 間 Gap을 조회하고 권역별 차이를 상세 분석하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-27  AJS            신규 생성
-- 2023-08-09  AJS            권역 / ACCOUNT 추가
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2010_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2010_POP_Q1   'N', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_REGION_SUM_YN          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @P_BASE_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())

    ---------------------------------
    -- RAW DATA
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1040_RAW_Q1
         @P_BASE_YYYYMM             -- 기준년월
       , @P_LANG_CD                 -- LANG_CD (ko, en)
       , @P_USER_ID                 -- USER_ID
       , @P_VIEW_ID                 -- VIEW_ID
    ;
    ---------------------------------
    -- 조회
    ---------------------------------
        SELECT CORP_NM                                                       AS CORP
             , REGION                                                        AS REGION         -- 2024.08.09 AJS
             , CASE WHEN @P_REGION_SUM_YN = 'Y' THEN '' ELSE ACCOUNT_CD END  AS ACCOUNT_CD     -- 2024.08.09 AJS
             , CASE WHEN @P_REGION_SUM_YN = 'Y' THEN '' ELSE ACCOUNT_NM END  AS ACCOUNT_NM     -- 2024.08.09 AJS
             , SUM(RTF_QTY     ) / 1000                                      AS RTF_QTY        -- 판매계획(RTF)
             , SUM(SALES_QTY   ) / 1000                                      AS SALES_QTY      -- 출하실적
             , (SUM(SALES_QTY) - SUM(RTF_QTY    )) / 1000                    AS GAP_QTY        -- 차이
             , SUM(SALES_QTY   ) / SUM(RTF_QTY  )   * 100                    AS ACHIEV_RATE    -- 달성률
          FROM TM_SA1040 WITH(NOLOCK)
         WHERE GRADE_CD = @P_GRADE_CD
         GROUP BY CORP_NM
                , REGION           -- 2024.08.09 AJS
                , CASE WHEN @P_REGION_SUM_YN = 'Y' THEN '' ELSE ACCOUNT_CD END        -- 2024.08.09 AJS
                , CASE WHEN @P_REGION_SUM_YN = 'Y' THEN '' ELSE ACCOUNT_NM END        -- 2024.08.09 AJS

        HAVING ISNULL(SUM(RTF_QTY),0) + ISNULL(SUM(SALES_QTY), 0) > 0
         ORDER BY CORP_NM


    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1040') IS NOT NULL  DROP TABLE TM_SA1040


END

GO
