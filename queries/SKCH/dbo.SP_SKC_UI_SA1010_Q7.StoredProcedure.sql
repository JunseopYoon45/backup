USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q7]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q7] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q7
-- COPYRIGHT       : AJS
-- REMARK          : 품변기회비용
--                   특정 기준년월의 품변 기회비용을 조회
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q7' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q7  'ko','I23779',''

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
    -- 임시 테이블
    -----------------------------------
    IF OBJECT_ID('TM_SA1017') IS NOT NULL DROP TABLE TM_SA1017 -- 임시테이블 삭제

     CREATE TABLE TM_SA1017
     (
         BASE_YYYYMM          NVARCHAR(100)
       , GC_CNT               DECIMAL(18,0)
       , GC_AMT               DECIMAL(18,0)
     )

    -----------------------------------
    --  기준년월
    -----------------------------------
    DECLARE @V_BASE_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일

    ---------------------------------
    -- RAW (당월)
    ---------------------------------
    BEGIN
        PRINT '[0]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM
    END

    ---------------------------------
    -- RAW (-1월)
    ---------------------------------
    BEGIN
        SET @V_BASE_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_BASE_YYYYMM+'01'), 112)

        PRINT '[1]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM

    END


    ---------------------------------
    -- RAW (-2월)
    ---------------------------------
    BEGIN
        SET @V_BASE_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_BASE_YYYYMM+'01'), 112)

        PRINT '[2]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM

    END

    ---------------------------------
    -- RAW (-3월)
    ---------------------------------
    BEGIN
        SET @V_BASE_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_BASE_YYYYMM+'01'), 112)

        PRINT '[3]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM

    END


    ---------------------------------
    -- RAW (-4월)
    ---------------------------------
    BEGIN
        SET @V_BASE_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_BASE_YYYYMM+'01'), 112)

        PRINT '[4]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM

    END

    ---------------------------------
    -- RAW (-5월)
    ---------------------------------
    BEGIN
        SET @V_BASE_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -1, @V_BASE_YYYYMM+'01'), 112)

        PRINT '[5]   ' + @V_BASE_YYYYMM
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
             @V_BASE_YYYYMM              -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , @P_VIEW_ID                  -- VIEW_ID
           ;

             INSERT INTO TM_SA1017
             SELECT MAX(@V_BASE_YYYYMM)                  AS BASE_YYYYMM
                  , ISNULL(SUM(L_GC_CNT), 0)             AS GC_CNT
                  , ISNULL(SUM(GC_COST ), 0)             AS GC_AMT
               FROM (  SELECT MAX(YYYYMM)                AS YYYYMM
                         FROM TB_CM_CALENDAR  WITH(NOLOCK)
                        WHERE YYYYMM = @V_BASE_YYYYMM
                    ) C

               LEFT JOIN TM_SA1140 X WITH(NOLOCK)
                 ON C.YYYYMM = X.BASE_YYYYMM
              GROUP BY  BASE_YYYYMM
              ORDER BY  BASE_YYYYMM

    END

    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT DISTINCT
               BASE_YYYYMM                               AS BASE_YYYYMM
             , GC_CNT                                    AS GC_CNT
             , GC_AMT / 1000000                          AS GC_AMT
          FROM TM_SA1017 WITH(NOLOCK)
         ORDER BY BASE_YYYYMM

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1017') IS NOT NULL DROP TABLE TM_SA1017
        --IF OBJECT_ID('TM_SA1140') IS NOT NULL DROP TABLE TM_SA1140


END

GO
