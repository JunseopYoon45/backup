USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1040_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1040_RAW_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1040_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 판매 계획 달성률 (수요 & 판매계획 상세)
--                   수요계획, 판매계획 관련 달성율 지표를 상세 Lv로 조회하는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-21  AJS            신규 생성
-- 2023-08-23  AJS            CA향, CG향은 예외처리
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1040_RAW_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_SA1040_RAW_Q1 '202407','ko','I23779',''
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

    DECLARE @P_VER_FR_YYYYMM     NVARCHAR(10) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @P_BASE_YYYYMM + '01'), 112)

    BEGIN

    -----------------------------------
    -- EXP_ACCOUNT (예외처리 ACCOUNT)
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_EXP_ACCOUNT') IS NOT NULL DROP TABLE #TM_EXP_ACCOUNT -- 임시테이블 삭제
        SELECT ATTR_01_VAL      AS ACCOUNT_CD
             , COMN_CD_NM       AS ACCOUNT_NM
             , SEQ              AS SEQ
          INTO #TM_EXP_ACCOUNT
          FROM FN_COMN_CODE('SA1040_EXP','')

        -----------------------------------
        -- 임시 테이블
        -----------------------------------

        IF OBJECT_ID('TM_SA1040') IS NOT NULL DROP TABLE TM_SA1040 -- 임시테이블 삭제

        CREATE TABLE TM_SA1040
        (
             CORP_CD              NVARCHAR(100)
           , CORP_NM              NVARCHAR(100)
           , REGION               NVARCHAR(100)
           , ACCOUNT_CD           NVARCHAR(100)
           , ACCOUNT_NM           NVARCHAR(100)
           , EMP_CD               NVARCHAR(100)
           , EMP_NM               NVARCHAR(100)
           , BRAND_CD             NVARCHAR(100)
           , BRAND                NVARCHAR(100)
           , SERIES_CD            NVARCHAR(100)
           , SERIES               NVARCHAR(100)
           , GRADE_CD             NVARCHAR(100)
           , GRADE                NVARCHAR(100)
           , PLNT_CD              NVARCHAR(100)
           , PLNT_NM              NVARCHAR(100)
           , M3_QTY               DECIMAL(18,0)
           , M2_QTY               DECIMAL(18,0)
           , M1_QTY               DECIMAL(18,0)
           , GAP_QTY              DECIMAL(18,0)
           , CHNG_RATE            DECIMAL(18,6)
           , FILL_RATE            DECIMAL(18,6)
           , DEMAND_PLAN          DECIMAL(18,0)
           , RTF_QTY              DECIMAL(18,0)
           , SALES_QTY            DECIMAL(18,0)
           , ACHIEV_RATE          DECIMAL(18,6)
           , ACRCY_RATE           DECIMAL(18,6)
           , MIN_QTY              DECIMAL(18,6)
           , MAX_QTY              DECIMAL(18,6)

        )

    END

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
          FROM DBO.FN_DP_CLOSE_VERSION( @P_VER_FR_YYYYMM, @P_BASE_YYYYMM )

PRINT  @P_VER_FR_YYYYMM
PRINT  @P_BASE_YYYYMM
    -----------------------------------
    -- DP M0 : 기준년월이 6월일때 5월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M1') IS NOT NULL DROP TABLE #TM_DP_M1 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M1
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 1)
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM


    -----------------------------------
    -- DP M1 : 기준년월이 6월일때  4월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M2') IS NOT NULL DROP TABLE #TM_DP_M2 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M2
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 2)
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM

    -----------------------------------
    -- DP M2   : 기준년월이 6월일때  3월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M3') IS NOT NULL DROP TABLE #TM_DP_M3 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M3
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 3)
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM

    -----------------------------------
    -- 조회
    -----------------------------------
--SET @V_TO_DAY = '20240529'
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제


        SELECT D.ANCESTER_CD                                                        AS CORP_CD
             , D.ANCESTER_NM                                                        AS CORP_NM
             , A.ATTR_04                                                            AS REGION
             , A.ACCOUNT_CD                                                         AS ACCOUNT_CD
             , A.ACCOUNT_NM                                                         AS ACCOUNT_NM
             , U.EMP_ID                                                             AS EMP_CD
             , N.DISPLAY_NAME                                                       AS EMP_NM
             , I.ATTR_06                                                            AS BRAND_CD
             , I.ATTR_07                                                            AS BRAND
             , I.ATTR_08                                                            AS SERIES_CD
             , I.ATTR_09                                                            AS SERIES
             , I.ATTR_10                                                            AS GRADE_CD
             , I.ATTR_11                                                            AS GRADE
             , A.ATTR_05                                                            AS PLNT_CD
             , A.ATTR_06                                                            AS PLNT_NM
             , SUM(ISNULL(X.M3_QTY    , 0))                                         AS M3_QTY
             , SUM(ISNULL(X.M2_QTY    , 0))                                         AS M2_QTY
             , SUM(ISNULL(X.M1_QTY    , 0))                                         AS M1_QTY
             , SUM(ISNULL(X.RTF_QTY   , 0))                                         AS RTF_QTY
             , SUM(ISNULL(X.SALES_QTY , 0))                                         AS SALES_QTY
             , SUM(ISNULL(X.M1_QTY    ,  0))                                        AS DEMAND_PLAN
             ,  DBO.FN_G_GREATEST(SUM(ISNULL(RTF_QTY,0)), SUM(ISNULL(SALES_QTY,0))) AS MAX_QTY
             ,  DBO.FN_G_LEAST(   SUM(ISNULL(RTF_QTY,0)), SUM(ISNULL(SALES_QTY,0))) AS MIN_QTY
          INTO #TM_QTY
          FROM (
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , QTY                   AS M3_QTY
                       , 0                     AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M3
                   WHERE 1=1

                   UNION ALL
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , QTY                   AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M2

                   UNION ALL
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , 0                     AS M2_QTY
                       , QTY                   AS M1_QTY
                       , RTF_QTY               AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M1

                   UNION ALL
                   -- 판매실적
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , 0                     AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , QTY                   AS SALES_QTY
                    FROM TB_CM_ACTUAL_SALES X WITH(NOLOCK)
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM
               ) X
             , (  SELECT *
                    FROM ( -- 동일 수요계획 수립단위에 담당자가 2명 이상일 경우, 수요계획 대상 “Y”인 담당자만 반영
                            SELECT ACCOUNT_ID
                                 , ITEM_MST_ID
                                 , EMP_ID
                                 , ROW_NUMBER() OVER(PARTITION BY A.ACCOUNT_ID, A.ITEM_MST_ID
                                                         ORDER BY A.ACTV_YN DESC) AS RN
                              FROM TB_DP_USER_ITEM_ACCOUNT_MAP A  WITH(NOLOCK)
                         ) X
                   WHERE RN = 1) U
             , TB_CM_ITEM_MST              I WITH(NOLOCK)
             , TB_DP_ACCOUNT_MST           A WITH(NOLOCK)
             , TB_AD_USER                  N WITH(NOLOCK)
             , TB_DPD_SALES_HIER_CLOSURE   D WITH(NOLOCK)
         WHERE X.ACCOUNT_ID       = U.ACCOUNT_ID
           AND X.ITEM_MST_ID      = U.ITEM_MST_ID
           AND U.EMP_ID           = N.USERNAME
           AND X.ACCOUNT_ID       = A.ID
           AND A.ACCOUNT_CD       = D.DESCENDANT_CD
           AND X.ITEM_MST_ID      = I.ID
           AND D.DEPTH_NUM        = 2
           AND D.USE_YN           = 'Y'
           AND A.ACTV_YN          = 'Y'
           --AND U.ACTV_YN          = 'Y'
           AND I.ATTR_04   IN ('11', '1B')               -- Copoly, PET (11, 1B)   2024.07.17 AJS
           AND I.ATTR_06   != '11-A0140'                 -- SKYPURA   2024.07.17 AJS
           AND NOT EXISTS ( SELECT 1   -- CA향, CG향은 예외처리 2024.08.23 AJS
                              FROM #TM_EXP_ACCOUNT E
                             WHERE A.ACCOUNT_CD = E.ACCOUNT_CD
                           )
	       AND I.ATTR_14 = '010' -- 2024.10.10 S&OP 비정상 제품 실적 제외

         GROUP BY D.ANCESTER_CD
                , D.ANCESTER_NM
                , A.ATTR_04
                , A.ACCOUNT_CD
                , A.ACCOUNT_NM
                , U.EMP_ID
                , N.DISPLAY_NAME
                , I.ATTR_06
                , I.ATTR_07
                , I.ATTR_08
                , I.ATTR_09
                , I.ATTR_10
                , I.ATTR_11
                , A.ATTR_05
                , A.ATTR_06

    -----------------------------------
    -- 조회
    -----------------------------------
        BEGIN
             INSERT INTO TM_SA1040
             SELECT CORP_CD                                   AS CORP_CD
                  , CORP_NM                                   AS CORP_NM
                  , REGION                                    AS REGION
                  , ACCOUNT_CD                                AS ACCOUNT_CD
                  , ACCOUNT_NM                                AS ACCOUNT_NM
                  , EMP_CD                                    AS EMP_CD
                  , EMP_NM                                    AS EMP_NM
                  , BRAND_CD                                  AS BRAND_CD
                  , BRAND                                     AS BRAND
                  , SERIES_CD                                 AS SERIES_CD
                  , SERIES                                    AS SERIES
                  , GRADE_CD                                  AS GRADE_CD
                  , GRADE                                     AS GRADE
                  , PLNT_CD                                   AS PLNT_CD
                  , PLNT_NM                                   AS PLNT_NM
                  , M3_QTY                                    AS M3_QTY         -- M3
                  , M2_QTY                                    AS M2_QTY         -- M2
                  , M1_QTY                                    AS M1_QTY         -- M1
                  , M1_QTY - M3_QTY                           AS GAP_QTY        -- 물량 Gap
                  , (M1_QTY - M3_QTY) / M3_QTY * 100          AS CHNG_RATE      -- 변경율 : M1-M3 / M3
                  , (RTF_QTY / M1_QTY)         * 100          AS FILL_RATE      -- 충족율 : M1 / 판매계획
                  , DEMAND_PLAN                               AS DEMAND_PLAN    -- 수요 계획
                  , RTF_QTY                                   AS RTF_QTY        -- 판매계획
                  , SALES_QTY                                 AS SALES_QTY      -- 판매실적
                  , SALES_QTY / RTF_QTY        * 100          AS ACHIEV_RATE    -- 달성률
                  , (MIN_QTY / MAX_QTY)        * 100          AS ACRCY_RATE     -- 정확도
                  , MIN_QTY                                   AS MIN_QTY
                  , MAX_QTY                                   AS MAX_QTY
               FROM #TM_QTY
        END


END

GO
