USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1040_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1040_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_CORP_CD               NVARCHAR(100)   = NULL    -- 법인
   , @P_EMP_CD                NVARCHAR(100)   = NULL    -- 담당자
   , @P_REGION_CD             NVARCHAR(100)   = NULL    -- 권역
   , @p_ACCOUNT_FILTER        NVARCHAR(MAX)   = '[]'    -- 매출처
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1040_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 수요 ? 판매계획 상세
--                   수요계획, 판매계획 관련 달성율 지표를 상세 Lv로 조회하는 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1040_POP_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_SA1040_POP_Q1 '202407','1060','176863','ALL','[]','ALL','ALL','ko','I23779','UI_SA1040'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_BASE_YYYYMM           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_CORP_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_EMP_CD                ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_REGION_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @p_ACCOUNT_FILTER        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_BRAND_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_GRADE_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN


    -----------------------------------
    -- #TM_REGION
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_REGION') IS NOT NULL DROP TABLE #TM_REGION -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_REGION
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_REGION_CD),''),'|')

    -----------------------------------
    -- #TM_BRND
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_BRAND') IS NOT NULL DROP TABLE #TM_BRAND -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_BRAND
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_BRAND_CD),''),'|')

    -----------------------------------
    -- #TM_GRADE
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_GRADE
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_GRADE_CD),''),'|')

    -----------------------------------
    -- #TM_USER
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_USER') IS NOT NULL DROP TABLE #TM_USER
		
		-- 팀장
        SELECT DESC_ID AS EMP_ID
          INTO #TM_USER
          FROM TB_DPD_USER_HIER_CLOSURE
         WHERE ANCS_CD         = @P_EMP_CD
           AND MAPPING_SELF_YN = 'Y'
           AND DEPTH_NUM      != 0
           AND DESC_ROLE_CD    = 'MARKETER'
		   UNION ALL
		-- 본인
        SELECT DESC_ID AS EMP_ID
          FROM TB_DPD_USER_HIER_CLOSURE
         WHERE DESC_ID         = @P_EMP_CD
           AND MAPPING_SELF_YN = 'Y'
           AND DEPTH_NUM      != 0
           AND DESC_ROLE_CD    = 'MARKETER'

    -----------------------------------
    -- #Account
    -----------------------------------
    DECLARE @P_STR  NVARCHAR(MAX);
    DECLARE @TMP_ACCOUNT TABLE (ACCOUNT_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ACCOUNT_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);

    SELECT @P_STR = dbo.FN_G_ACCT_FILTER_EXTENDS('CONTAINS', @P_ACCOUNT_FILTER);

    INSERT INTO @TMP_ACCOUNT
    EXECUTE sp_executesql @P_STR;
   -------------------------------


    SET @P_CORP_CD = CASE WHEN @P_CORP_CD = 'ALL' THEN '' ELSE @P_CORP_CD END
    ---------------------------------
    -- RAW
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
        SELECT *
          FROM TM_SA1040    A WITH(NOLOCK)
             , @TMP_ACCOUNT B
             , #TM_USER     U
         WHERE 1=1
           AND CORP_CD         LIKE '%' + @P_CORP_CD           + '%'   -- 법인
           AND A.EMP_CD        = U.EMP_ID  -- 2024.08.21 AJS 팀장은 팀원까지 조회 가능
           AND A.ACCOUNT_CD    = B.ACCOUNT_CD
           AND (REGION    IN (SELECT VAL FROM #TM_REGION)  OR ISNULL( @P_REGION_CD, 'ALL') = 'ALL' )
           AND (BRAND_CD  IN (SELECT VAL FROM #TM_BRAND)   OR ISNULL( @P_BRAND_CD , 'ALL') = 'ALL' )
           AND (GRADE_CD  IN (SELECT VAL FROM #TM_GRADE)   OR ISNULL( @P_GRADE_CD , 'ALL') = 'ALL' )
           AND (M3_QTY + M2_QTY + M1_QTY + RTF_QTY + SALES_QTY) > 0
         ORDER BY A.CORP_NM
                , A.REGION
                , A.ACCOUNT_NM
                , A.EMP_NM
                , A.BRAND
                , A.SERIES
                , A.GRADE
                , A.PLNT_NM

END

GO
