USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1030_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1030_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1030_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 사업 계획 달성률
--                   사업계획 대비 판매실적의 달성률을 조회하는 상세 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1030_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1030_RAW_Q1 '202401','202412','ko','I23671','UI_SA1010'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_FR_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_TO_YYYYMM             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN
    -----------------------------------
    --  기준년월
    -----------------------------------
    DECLARE @V_ACT_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일
	SET @V_ACT_YYYYMM = (SELECT CASE WHEN CONVERT(NUMERIC,@P_TO_YYYYMM) - CONVERT(NUMERIC,@V_ACT_YYYYMM) < 0 THEN @P_TO_YYYYMM ELSE @V_ACT_YYYYMM END )

	PRINT @V_ACT_YYYYMM

    -----------------------------------
    -- 사업 계획 달성률 임시 테이블 (HOME)
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1010'
    BEGIN
    	
        --EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_HOME_S1
        --     @P_USER_ID                  -- USER_ID
        --   , 'UI_SA1010'                 -- VIEW_ID
        --;


        IF OBJECT_ID('TM_SA1010') IS NOT NULL DROP TABLE TM_SA1010 -- 임시테이블 삭제

        CREATE TABLE TM_SA1010
        (
               BASE_YYYYMM         NVARCHAR(100)
             , ANNUAL_QTY          DECIMAL(18,0)       -- 사업계획
             , SALES_QTY           DECIMAL(18,0)       -- 판매실적
             --, LOGIN_ID            NVARCHAR(50) 
        )
    END

    -----------------------------------
    -- 사업 계획 달성률 임시 테이블
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1030'
    BEGIN

        IF OBJECT_ID('TM_SA1030') IS NOT NULL DROP TABLE TM_SA1030 -- 임시테이블 삭제

         CREATE TABLE TM_SA1030
         (
               BASE_YYYYMM         NVARCHAR(100)
             , ORG_CORP_CD         NVARCHAR(100)
             , CORP_CD             NVARCHAR(100)
             , CORP_NM             NVARCHAR(100)
             , REGION              NVARCHAR(100)
             , ACCOUNT_CD          NVARCHAR(100)
             , ACCOUNT_NM          NVARCHAR(100)
             , EMP_ID              NVARCHAR(100)
             , EMP_NM              NVARCHAR(100)
             , BRAND_CD            NVARCHAR(100)
             , BRAND               NVARCHAR(100)
             , SERIES_CD           NVARCHAR(100)
             , SERIES              NVARCHAR(100)
             , GRADE_CD            NVARCHAR(100)
             , GRADE               NVARCHAR(100)
             , PLNT_CD             NVARCHAR(100)
             , PLNT_NM             NVARCHAR(100)
             , ANNUAL_QTY          DECIMAL(18,0)       -- 사업계획
             , RTF_QTY             DECIMAL(18,0)       -- 판매계획
             , SALES_QTY           DECIMAL(18,0)       -- 판매실적
             , MIN_QTY             DECIMAL(18,6)       -- Min
             , MAX_QTY             DECIMAL(18,6)       -- Max
             , ACRCY_RATE          DECIMAL(18,6)       -- 정확도

         )
    END

    -----------------------------------
    -- 사업 계획 달성률 POP 임시 테이블
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1030_POP'
    BEGIN

        IF OBJECT_ID('TM_SA1030_POP') IS NOT NULL DROP TABLE TM_SA1030_POP -- 임시테이블 삭제

        CREATE TABLE TM_SA1030_POP
        (
               ORG_CORP_CD         NVARCHAR(100)
             , CORP_CD             NVARCHAR(100)
             , CORP_NM             NVARCHAR(100)
             , REGION              NVARCHAR(100)
             , ACCOUNT_CD          NVARCHAR(100)
             , ACCOUNT_NM          NVARCHAR(100)
             , BRAND_CD            NVARCHAR(100)
             , BRAND               NVARCHAR(100)
             , GRADE_CD            NVARCHAR(100)
             , GRADE               NVARCHAR(100)
             , PLNT_CD             NVARCHAR(100)
             , PLNT_NM             NVARCHAR(100)
             , ANNUAL_QTY          DECIMAL(18,0)       -- 사업계획
             , RTF_QTY             DECIMAL(18,0)       -- 판매계획
             , SALES_QTY           DECIMAL(18,0)       -- 판매실적
             , ACRCY_RATE          DECIMAL(18,6)       -- 정확도

        )
    END

    -----------------------------------
    -- 사업계획 比 판매계획 (Pop-up) 임시 테이블
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1020_POP'
    BEGIN

        IF OBJECT_ID('TM_SA1020_POP') IS NOT NULL DROP TABLE TM_SA1020_POP -- 임시테이블 삭제

        CREATE TABLE TM_SA1020_POP
        (
               BASE_YYYYMM         NVARCHAR(100)
             , ORG_CORP_CD         NVARCHAR(100)
             , CORP_CD             NVARCHAR(100)
             , CORP_NM             NVARCHAR(100)
			 , SALES_YN            NVARCHAR(10)
             , ANNUAL_QTY          DECIMAL(18,0)     -- 사업계획
             , SALES_QTY           DECIMAL(18,0)     -- 판매수량 (실적 있으면 실적 없으면 계획)
             , SALES_PLAN_QTY      DECIMAL(18,0)     -- 판매계획
             , SALES_ACT_QTY       DECIMAL(18,0)     -- 판매실적
        )
    END


    -----------------------------------
    -- 조회
    -----------------------------------

    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT X.BASE_YYYYMM                                            AS BASE_YYYYMM
             , LEFT(A.ATTR_05,1)                                        AS ORG_CORP_CD
             , A.ATTR_12                                                AS CORP_CD
             , A.ATTR_13                                                AS CORP_NM
             , A.ATTR_04                                                AS REGION
             , A.ACCOUNT_CD                                             AS ACCOUNT_CD
             , A.ACCOUNT_NM                                             AS ACCOUNT_NM
             , ''                                                       AS EMP_ID
             , ''                                                       AS EMP_NM
             , I.ATTR_06                                                AS BRAND_CD
             , I.ATTR_07                                                AS BRAND
             , I.ATTR_08                                                AS SERIES_CD
             , I.ATTR_09                                                AS SERIES
             , I.ATTR_10                                                AS GRADE_CD
             , I.ATTR_11                                                AS GRADE
             , A.ATTR_05                                                AS PLNT_CD
             , A.ATTR_06                                                AS PLNT_NM
             , SUM(ISNULL(X.ANNUAL_QTY ,0))                             AS ANNUAL_QTY
             , SUM(ISNULL(X.RTF_QTY    ,0))                             AS RTF_QTY
             , SUM(ISNULL(X.SALES_QTY  ,0))                             AS SALES_QTY
			 , DBO.FN_G_LEAST(SUM(ANNUAL_QTY   ), SUM(SALES_QTY))       AS MIN_QTY
             , DBO.FN_G_GREATEST(SUM(ANNUAL_QTY), SUM(SALES_QTY))       AS MAX_QTY
             , (DBO.FN_G_LEAST(SUM(ANNUAL_QTY   ), SUM(SALES_QTY)) / DBO.FN_G_GREATEST(SUM(ANNUAL_QTY), SUM(SALES_QTY))) * 100   AS ACRCY_RATE    -- 정확도 (Min / Max)
          INTO #TM_QTY
          FROM ( -- 판매실적
                  SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                       , ITEM_MST_ID                               AS ITEM_MST_ID
                       , ACCOUNT_ID                                AS ACCOUNT_ID
                       , 0                                         AS RTF_QTY        -- 계획
                       , QTY                                       AS SALES_QTY
                       , 0                                         AS ANNUAL_QTY
                    FROM TB_CM_ACTUAL_SALES
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @P_FR_YYYYMM AND @V_ACT_YYYYMM

                   UNION ALL
                 -- 사업계획
                  SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                       , ITEM_MST_ID                               AS ITEM_MST_ID
                       , ACCOUNT_ID                                AS ACCOUNT_ID
                       , 0                                         AS RTF_QTY               -- 계획
                       , 0                                         AS SALES_QTY             -- 판매실적
                       , ANNUAL_QTY                                AS ANNUAL_QTY            -- 사업계획
                    FROM TB_DP_MEASURE_DATA
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                   UNION ALL
                 -- 판매계획
                  SELECT CONVERT(NVARCHAR(6), BASE_DATE, 112)      AS BASE_YYYYMM
                       , ITEM_MST_ID                               AS ITEM_MST_ID
                       , ACCOUNT_ID                                AS ACCOUNT_ID
                       , QTY_R                                     AS RTF_QTY               -- 판매 계획
                       , 0                                         AS SALES_QTY             -- 판매실적
                       , 0                                         AS ANNUAL_QTY            -- 사업계획
                    FROM TB_DP_ENTRY
                   WHERE VER_ID = (   SELECT DP_VERSION_ID
                                        FROM DBO.FN_DP_CLOSE_VERSION( @V_ACT_YYYYMM, @V_ACT_YYYYMM)   -- 기준월의 확정버전
                     WHERE ROW_NUM = 1
                                  )
                     AND CONVERT(NVARCHAR(6), BASE_DATE, 112)  BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
               ) X
             , (  SELECT ID
                       , I.ATTR_06
                       , I.ATTR_07
                       , I.ATTR_08
                       , I.ATTR_09
                       , I.ATTR_10
                       , I.ATTR_11
                    FROM TB_CM_ITEM_MST I
                   WHERE 1=1
                     AND I.ATTR_04   IN ('11', '1B')          -- Copoly, PET (11, 1B)   2024.07.17 AJS
                     AND I.ATTR_06 != '11-A0140'              -- SKYPURA   2024.07.17 AJS
					 AND I.ATTR_07 IN ('ECOZEN', 'ECOTRIA', 'SKYGREEN')   -- 계획, 실적에는 ECOZEN, ECOTRIA, SKYGREEN만 반영   2024.08.11 AJS
               ) I
             , (  SELECT ID
                       , A.ATTR_01
                       , A.ATTR_12
                       , A.ATTR_13
                       , A.ATTR_04
                       , A.ATTR_05
                       , A.ATTR_06
                       , A.ACCOUNT_CD
                       , A.ACCOUNT_NM
                    FROM TB_DP_ACCOUNT_MST A
                   WHERE A.ACTV_YN    = 'Y'
                     AND A.ATTR_12   != '123'                 -- GC-CHDM
                     AND A.ATTR_12   != '133'                 -- GC-유화
                     AND A.ATTR_12 IS NOT NULL

                     AND A.ATTR_05   != '1130'                -- CHDM  2024.07.15 AJS
                     AND A.ATTR_05   != '1250'                -- DMT   2024.07.15 AJS
               ) A
         WHERE 1=1
           AND X.ACCOUNT_ID      = A.ID
           AND X.ITEM_MST_ID     = I.ID


         GROUP BY X.BASE_YYYYMM
             , A.ATTR_01
             , A.ATTR_12
             , A.ATTR_13
             , A.ATTR_04
             , A.ACCOUNT_CD
             , A.ACCOUNT_NM
             , I.ATTR_06
             , I.ATTR_07
             , I.ATTR_08
             , I.ATTR_09
             , I.ATTR_10
             , I.ATTR_11
             , A.ATTR_05
             , A.ATTR_06

			 
    -----------------------------------
    -- Home
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1010'
    BEGIN

        INSERT INTO TM_SA1010
        SELECT A.BASE_YYYYMM                        AS BASE_YYYYMM
             , SUM(A.ANNUAL_QTY   )                 AS ANNUAL_QTY            -- 사업계획
             , SUM(A.SALES_QTY  )                   AS SALES_ACT_QTY        -- 판매실적
			 --, @P_USER_ID                           AS LOGIN_ID   
          FROM #TM_QTY A
		 WHERE ORG_CORP_CD = '1'
         GROUP BY
               A.BASE_YYYYMM
    END

    -----------------------------------
    -- 사업 계획 달성률
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1030'
    BEGIN

        INSERT INTO TM_SA1030
        SELECT *
          FROM #TM_QTY
    END


    -----------------------------------
    -- 사업 계획 달성률
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1030_POP'
    BEGIN
        INSERT INTO TM_SA1030_POP
        SELECT ORG_CORP_CD
             , CORP_CD
             , CORP_NM
             , REGION
             , ACCOUNT_CD
             , ACCOUNT_NM
             , BRAND_CD
             , BRAND
             , GRADE_CD
             , GRADE
             , PLNT_CD
             , PLNT_NM
             , ANNUAL_QTY
             , RTF_QTY
             , SALES_QTY
             , ACRCY_RATE
          FROM #TM_QTY A
    END

    -----------------------------------
    -- 회의체 - 사업계획 比 판매계획 (Pop-up) 임시 테이블
    -----------------------------------
    IF @P_VIEW_ID = 'UI_SA1020_POP'
    BEGIN

        INSERT INTO TM_SA1020_POP
        SELECT A.BASE_YYYYMM                        AS BASE_YYYYMM
             , A.ORG_CORP_CD                        AS ORG_CORP_CD
             , A.CORP_CD                            AS CORP_CD
             , A.CORP_NM                            AS CORP_NM
             , CASE WHEN A.BASE_YYYYMM <= @V_ACT_YYYYMM THEN 'Y'
                    ELSE 'N'
                END                                 AS SALES_YN
             , SUM(A.ANNUAL_QTY   )                 AS ANNUAL_QTY            -- 사업계획
             , CASE WHEN A.BASE_YYYYMM <= @V_ACT_YYYYMM THEN SUM(A.SALES_QTY)
                    ELSE SUM(A.RTF_QTY)
                END                                 AS SALES_QTY
             , SUM(A.RTF_QTY  )                     AS SALES_PLAN_QTY        -- 판매계획
             , SUM(A.SALES_QTY)                     AS SALES_ACT_QTY         -- 판매실적
          FROM #TM_QTY A
         GROUP BY
               A.BASE_YYYYMM
			 , A.ORG_CORP_CD
             , A.CORP_CD
             , A.CORP_NM
             , CASE WHEN A.BASE_YYYYMM <= @V_ACT_YYYYMM THEN 'Y'
                    ELSE 'N'
                END                      
    END
		
END
GO
