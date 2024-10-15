USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2020_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2020_Q1] (
     @P_BASE_YYYY             NVARCHAR(100)   = NULL    -- 기준년도
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2020_Q1
-- COPYRIGHT       : AJS
-- REMARK          : Demand Plan 변동
--                   판매계획과 출하실적 間
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-17  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2020_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2020_Q1 '2024','ko','I23779','UI_SA2020'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_BASE_YYYY           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID             ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    -- 기준년월
    -----------------------------------
    DECLARE @V_FR_YYYYMM          NVARCHAR(10)   = @P_BASE_YYYY + '01'    -- 기준년월 (From)
          , @V_TO_YYYYMM          NVARCHAR(10)   = @P_BASE_YYYY + '12'    -- 기준년월 (To)
    DECLARE @V_ACT_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())
	
    PRINT '@V_FR_YYYYMM    ' + @V_FR_YYYYMM
    PRINT '@V_TO_YYYYMM    ' + @V_TO_YYYYMM
    PRINT '@V_ACT_YYYYMM   ' + @V_ACT_YYYYMM

    -----------------------------------
    -- DP Version
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_VER') IS NOT NULL DROP TABLE #TM_DP_VER -- 임시테이블 삭제
        SELECT ROW_NUM
             , DP_VERSION_CD
             , DP_VERSION_ID
             , DP_VER_YYYYMM
             , FROM_YYYYMMDD
          INTO #TM_DP_VER
          FROM DBO.FN_DP_CLOSE_VERSION( @V_FR_YYYYMM, @V_TO_YYYYMM )

    -----------------------------------
    -- 조회
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT MST.VER_CD                                AS VERSION_CD
             , MST.VER_YYYYMM                            AS VER_YYYYMM
             , MST.YYYYMM                                AS BASE_YYYYMM
       --    , SUM(Y.SALES_ACT_QTY)                      AS SALES_ACT_QTY       -- 판매실적
       --    , SUM(X.QTY)                                AS ORG_QTY             -- 판매계획
             , MAX(CASE WHEN MST.YYYYMM <= MST.VER_YYYYMM AND MST.YYYYMM <= @V_ACT_YYYYMM THEN Y.SALES_ACT_QTY
                        ELSE ISNULL(X.QTY ,0)
                    END ) / 1000                               AS QTY                 -- 기준일자 이전이면 실적 이후면 계획
             , MAX(CASE WHEN MST.YYYYMM <= MST.VER_YYYYMM AND MST.YYYYMM <= @V_ACT_YYYYMM THEN 'Y' ELSE NULL END)  AS COLOR_YN
          INTO #TM_QTY
          FROM (  SELECT C.YYYYMM
                       , V.VER_CD
                       , V.VER_YYYYMM
                    FROM TB_CM_CALENDAR C WITH(NOLOCK)
                       , (  SELECT DP_VERSION_CD         AS VER_CD
                                 , DP_VER_YYYYMM         AS VER_YYYYMM
                              FROM #TM_DP_VER
                             UNION ALL
                            SELECT 'BIZ_PLAN'            AS VER_CD
                                 , '000000'              AS VER_YYYYMM
                         ) V
                   WHERE C.YYYYMM BETWEEN  @V_FR_YYYYMM AND @V_TO_YYYYMM
               ) MST


               LEFT JOIN
                    ( -- 사업계획
                       SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                            , 'BIZ_PLAN'                                AS VER_CD
                            , SUM(ANNUAL_QTY)                           AS QTY       -- 사업계획
                         FROM TB_DP_MEASURE_DATA D WITH(NOLOCK)
                        WHERE 1=1
                          AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
                          AND EXISTS ( SELECT 1
                                         FROM TB_CM_ITEM_MST I WITH(NOLOCK)
                                        WHERE D.ITEM_MST_ID = I.ID
                                          AND I.ATTR_04    IN ('11', '1B')                               -- Copoly, PET (11, 1B)
                                          AND I.ATTR_06    != '11-A0140'                                 -- SKYPURA 제외
                                          AND I.ATTR_07 IN ('ECOZEN', 'ECOTRIA', 'SKYGREEN')             -- 계획, 실적에는 ECOZEN, ECOTRIA, SKYGREEN만 반영   2024.08.11 AJS
                                      )
                          AND EXISTS (
                                       SELECT 1
                                         FROM TB_DP_ACCOUNT_MST A
                                        WHERE A.ID         = D.ACCOUNT_ID
                                          AND A.ACTV_YN    = 'Y'
                                          AND A.ATTR_12 IS NOT NULL
                                          AND A.ATTR_01    = '1000'
                                          --AND A.ATTR_05  = '1110'
                                          AND A.ATTR_12   != '123'                 -- GC-CHDM
                                          AND A.ATTR_12   != '133'                 -- GC-유화

                                          AND A.ATTR_05   != '1130'                -- CHDM  2024.07.15 AJS
                                          AND A.ATTR_05   != '1250'                -- DMT   2024.07.15 AJS
                                     )
                        GROUP BY CONVERT(NVARCHAR(6), BASE_DATE, 112)
                        UNION ALL
                           -- 판매계획
                       SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                            , VER.VER_CD                                AS VER_CD
                            , SUM(QTY)                                  AS QTY   -- 판매 계획
                         FROM TB_DP_ENTRY MST WITH(NOLOCK)
                            , (  SELECT DP_VERSION_ID AS VER_ID
                                      , DP_VERSION_CD AS VER_CD
                                   FROM #TM_DP_VER
                              ) VER
                        WHERE MST.VER_ID  = VER.VER_ID
                          AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
                          AND EXISTS ( SELECT 1
                                         FROM TB_CM_ITEM_MST I WITH(NOLOCK)
                                        WHERE MST.ITEM_MST_ID = I.ID
                                          AND I.ATTR_04      IN ('11', '1B')               -- Copoly, PET (11, 1B)
                                          AND I.ATTR_06      != '11-A0140'                 -- SKYPURA 제외
                                          AND I.ATTR_07 IN ('ECOZEN', 'ECOTRIA', 'SKYGREEN')               -- 계획, 실적에는 ECOZEN, ECOTRIA, SKYGREEN만 반영   2024.08.11 AJS
                                      )
                          AND EXISTS (
                                       SELECT 1
                                         FROM TB_DP_ACCOUNT_MST A WITH(NOLOCK)
                                        WHERE A.ID         = MST.ACCOUNT_ID
                                          AND A.ATTR_01    = '1000'
                                          AND A.ATTR_05    = '1110'
                                          AND A.ATTR_12   != '123'                 -- GC-CHDM
                                          AND A.ATTR_12   != '133'                 -- GC-유화
                                          AND A.ACTV_YN    = 'Y'
                                          AND A.ATTR_12 IS NOT NULL

                                          AND A.ATTR_05   != '1130'                -- CHDM  2024.07.15 AJS
                                          AND A.ATTR_05   != '1250'                -- DMT   2024.07.15 AJS
                                     )
                          AND MST.ACTV_YN = 'Y'
                        GROUP BY VER.VER_CD
                               , CONVERT(NVARCHAR(6), BASE_DATE, 112)
                    ) X
                 ON MST.YYYYMM = X.BASE_YYYYMM
                AND MST.VER_CD = X.VER_CD

               LEFT JOIN
                    ( -- 판매실적
                       SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                            , SUM(QTY)                                  AS SALES_ACT_QTY
                         FROM TB_CM_ACTUAL_SALES S WITH(NOLOCK)
                        WHERE 1=1
                          AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @V_FR_YYYYMM AND @V_ACT_YYYYMM
                          AND EXISTS ( SELECT 1
                                         FROM TB_CM_ITEM_MST I WITH(NOLOCK)
                                        WHERE S.ITEM_MST_ID = I.ID
                                          AND I.ATTR_04    IN ('11', '1B')                                 -- Copoly, PET (11, 1B)
                                          AND I.ATTR_06    != '11-A0140'                                   -- SKYPURA 제외
                                          AND I.ATTR_07 IN ('ECOZEN', 'ECOTRIA', 'SKYGREEN')               -- 계획, 실적에는 ECOZEN, ECOTRIA, SKYGREEN만 반영   2024.08.11 AJS
                                      )
                          AND EXISTS (
                                       SELECT 1
                                         FROM TB_DP_ACCOUNT_MST A WITH(NOLOCK)
                                        WHERE A.ID         = S.ACCOUNT_ID
                                          AND A.ATTR_01    = '1000'
                                          AND A.ATTR_05    = '1110'
                                          AND A.ATTR_12   != '123'                 -- GC-CHDM
                                          AND A.ATTR_12   != '133'                 -- GC-유화
                                          AND A.ACTV_YN    = 'Y'
                                          AND A.ATTR_12 IS NOT NULL

                                          AND A.ATTR_05   != '1130'                -- CHDM  2024.07.15 AJS
                                          AND A.ATTR_05   != '1250'                -- DMT   2024.07.15 AJS
                                     )
                        GROUP BY CONVERT(NVARCHAR(6), BASE_DATE, 112)
                    ) Y
                 ON MST.YYYYMM = Y.BASE_YYYYMM
         WHERE 1=1

         GROUP BY MST.YYYYMM
             , MST.VER_CD
             , MST.VER_YYYYMM


    -----------------------------------
    -- 조회
    -----------------------------------

        SELECT VERSION_CD            AS VERSION_CD
             , VER_YYYYMM            AS VER_YYYYMM
             , BASE_YYYYMM           AS BASE_YYYYMM
             , QTY                   AS QTY
             , COLOR_YN              AS COLOR_YN
          FROM #TM_QTY
         UNION ALL
        SELECT VERSION_CD            AS VERSION_CD
             , VER_YYYYMM            AS VER_YYYYMM
             , 'Total'               AS BASE_YYYYMM
             , SUM(QTY)              AS QTY
             , NULL                  AS COLOR_YN
          FROM #TM_QTY
         GROUP BY VERSION_CD
                , VER_YYYYMM

         ORDER BY VERSION_CD
                , VER_YYYYMM
                , BASE_YYYYMM



END

GO
