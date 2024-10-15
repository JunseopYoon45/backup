USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2010_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2010_Q1] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2010_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 수요계획 比 출고량 (회의체)
--           판매계획과 출하실적 間 Gap을 조회하고 권역별 차이를 상세 분석하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-27  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2010_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2010_Q1   'ko','I23779',''
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

    DECLARE @P_BASE_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())

    PRINT @P_BASE_YYYYMM

    ---------------------------------
    -- 전월
    ---------------------------------
    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1040_RAW_Q1
         @P_BASE_YYYYMM                        -- 기준년월
       , @P_LANG_CD                            -- LANG_CD (ko, en)
       , @P_USER_ID                            -- USER_ID
       , @P_VIEW_ID                            -- VIEW_ID
    ;
    ---------------------------------
    -- 조회
    ---------------------------------
        SELECT BRAND_CD                                       AS BRAND_CD
             , BRAND                                          AS BRAND
             , SERIES_CD                                      AS SERIES_CD
             , SERIES                                         AS SERIES
             , GRADE_CD                                       AS GRADE_CD
             , GRADE                                          AS GRADE
             , SUM(RTF_QTY     ) / 1000                       AS RTF_QTY        -- 판매계획(RTF)
             , SUM(SALES_QTY   ) / 1000                       AS SALES_QTY      -- 출하실적
             , (SUM(SALES_QTY     ) - SUM(RTF_QTY)) / 1000    AS GAP_QTY        -- 차이
             , (SUM(SALES_QTY) / SUM(RTF_QTY     )) * 100     AS ACHIEV_RATE    -- 달성률
          FROM TM_SA1040 WITH(NOLOCK)
         WHERE ISNULL(RTF_QTY,0) + ISNULL(SALES_QTY, 0) > 0
         GROUP BY BRAND_CD
                , BRAND
                , SERIES_CD
                , SERIES
                , GRADE
                , GRADE_CD

         -- Brand Sum
         UNION ALL
        SELECT BRAND_CD                                       AS BRAND_CD
             , BRAND                                          AS BRAND
             , 'Total'                                        AS SERIES_CD
             , 'Total'                                        AS SERIES
             , ''                                             AS GRADE_CD
             , ''                                             AS GRADE
             , SUM(RTF_QTY     ) / 1000                       AS RTF_QTY        -- 판매계획(RTF)
             , SUM(SALES_QTY   ) / 1000                       AS SALES_QTY      -- 출하실적
             , (SUM(SALES_QTY  ) - SUM(RTF_QTY)) / 1000       AS GAP_QTY        -- 차이
             , (SUM(SALES_QTY) / SUM(RTF_QTY  )) * 100        AS ACHIEV_RATE    -- 달성률
          FROM TM_SA1040 WITH(NOLOCK)
         WHERE ISNULL(RTF_QTY,0) + ISNULL(SALES_QTY, 0) > 0
         GROUP BY BRAND_CD
                , BRAND

         -- 전체 Sum
         UNION ALL
        SELECT 'Total'                                        AS BRAND_CD
             , 'Total'                                        AS BRAND
             , 'Total'                                        AS SERIES_CD
             , 'Total'                                        AS SERIES
             , ''                                             AS GRADE_CD
             , ''                                             AS GRADE
             , SUM(RTF_QTY     ) / 1000                       AS RTF_QTY       -- 판매계획(RTF)
             , SUM(SALES_QTY   ) / 1000                       AS SALES_QTY     -- 출하실적
             , (SUM(SALES_QTY  ) - SUM(RTF_QTY)) / 1000       AS GAP_QTY        -- 차이
             , (SUM(SALES_QTY) / SUM(RTF_QTY  )) * 100        AS ACHIEV_RATE    -- 달성률
          FROM TM_SA1040 WITH(NOLOCK)
         WHERE ISNULL(RTF_QTY,0) + ISNULL(SALES_QTY, 0) > 0

         ORDER BY BRAND_CD
                , BRAND
                , SERIES
                , GRADE

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1040') IS NOT NULL  DROP TABLE TM_SA1040

END

GO
