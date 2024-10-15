USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1060_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1060_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_CORP_CD               NVARCHAR(100)   = NULL    -- 법인
   , @P_EMP_CD                NVARCHAR(100)   = NULL    -- 담당자
   , @P_REGION_CD             NVARCHAR(100)   = NULL    -- 권역
   , @P_ACCOUNT_FILTER        NVARCHAR(MAX)   = '[]'    -- 매출처
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1060_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 긴급 요청률
--                   수요계획 및 RTF 수량 대비 긴급 주문 물량을 조회하는 상세 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1060_POP_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_SA1060_POP_Q1 '202407','1060','175974','ALL','[]','ALL','ALL','ko','I23779','UI_SA1060'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_BASE_YYYYMM           ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_CORP_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_EMP_CD                ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_REGION_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_ACCOUNT_FILTER        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_BRAND_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_GRADE_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

/************************************************************************************************************************
  -- Account Search
************************************************************************************************************************/
  DECLARE @P_STR  NVARCHAR(MAX);
  DECLARE @TMP_ACCOUNT TABLE (ACCOUNT_ID NVARCHAR(32) COLLATE DATABASE_DEFAULT, ACCOUNT_CD NVARCHAR(100) COLLATE DATABASE_DEFAULT, ACCOUNT_NM NVARCHAR(255) COLLATE DATABASE_DEFAULT);

  SELECT @P_STR = dbo.FN_G_ACCT_FILTER_EXTENDS('CONTAINS', @P_ACCOUNT_FILTER);

  INSERT INTO @TMP_ACCOUNT
  EXECUTE sp_executesql @P_STR;
--------------------------------
   DECLARE @V_TO_DAY NVARCHAR(10) = (SELECT CONVERT(NVARCHAR(10), MAX(BASE_DATE), 112) FROM TB_SKC_CM_FERT_STCK_HST WITH(NOLOCK))


   DECLARE @V_FR_YYYYMM NVARCHAR(6) = @P_BASE_YYYYMM
   DECLARE @V_TO_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH,  3, @P_BASE_YYYYMM+'01'), 112)
   
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
    -- DP M0 : 기준년월이 6월일때 5월에 수립한 6월 7 8 9월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_ENTRY') IS NOT NULL DROP TABLE #TM_ENTRY -- 임시테이블 삭제

        SELECT Y.YYYYMM_SEQ                                   AS YYYYMM_SEQ
             , CONVERT(NVARCHAR(6), BASE_DATE, 112)           AS BASE_YYYYMM
             , VER_ID                                         AS VER_ID
             , ACCOUNT_ID                                     AS ACCOUNT_ID
             , ITEM_MST_ID                                    AS ITEM_MST_ID
             , EMP_ID                                         AS EMP_ID
             , QTY                                            AS QTY
             , QTY_R                                          AS RTF_QTY
          INTO #TM_ENTRY
          FROM TB_DP_ENTRY X WITH(NOLOCK)
             , (  SELECT ROW_NUMBER() OVER(ORDER BY YYYYMM)     AS YYYYMM_SEQ
                       , YYYYMM
                    FROM TB_CM_CALENDAR WITH(NOLOCK)
                   WHERE YYYYMM  BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
                   GROUP BY YYYYMM
               ) Y

         WHERE CONVERT(NVARCHAR(6), BASE_DATE, 112) = Y.YYYYMM
           AND X.VER_ID = (SELECT DP_VERSION_ID FROM DBO.FN_DP_CLOSE_VERSION( @P_BASE_YYYYMM, @P_BASE_YYYYMM ) WHERE ROW_NUM = 1) --'948C2C3CB26E4A5B8E88652BEBD4DFE5'
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM


       --SELECT * FROM #TM_ENTRY WHERE EMP_ID = 'I23036'
    -----------------------------------
    -- 조회
    -----------------------------------
--SET @V_TO_DAY = '20240529'
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT X.CORP_CD                                                  AS CORP_CD
             , X.CORP_NM                                                  AS CORP_NM
             , X.REGION                                                   AS REGION
             , X.ACCOUNT_NM                                               AS ACCOUNT_NM
             , X.EMP_ID                                                   AS EMP_ID
             , X.EMP_NM                                                   AS EMP_NM
             , X.BRAND                                                    AS BRAND
             , X.SERIES                                                   AS SERIES
             , X.GRADE                                                    AS GRADE
             , X.PLNT_CD                                                  AS PLNT_CD
             , X.PLNT_NM                                                  AS PLNT_NM
             , SUM(X.URNT_DMND_QTY) / 1000                                AS URNT_DMND_QTY
             , SUM(X.QTY    )   / 1000                                    AS TOT_QTY
             , SUM(X.M1_QTY )   / 1000                                    AS M1_QTY
             , SUM(X.M2_QTY )   / 1000                                    AS M2_QTY
             , SUM(X.M3_QTY )   / 1000                                    AS M3_QTY
             , SUM(X.M4_QTY )   / 1000                                    AS M4_QTY
             , SUM(X.RTF_QTY)   / 1000                                    AS RTF_QTY
             , (SUM(X.QTY   ) - SUM(RTF_QTY )) / 1000                     AS GAP_QTY
             , (SUM(X.URNT_DMND_QTY ) / SUM(RTF_QTY ) ) * 100             AS URNT_DMND_RATE
          INTO #TM_QTY
          FROM (

                  SELECT D.ANCESTER_CD                                            AS CORP_CD
                       , D.ANCESTER_NM                                            AS CORP_NM
                       , A.ATTR_04                                                AS REGION
                       , A.ACCOUNT_NM                                             AS ACCOUNT_NM
                       , U.EMP_ID                                                 AS EMP_ID
                       , N.DISPLAY_NAME                                           AS EMP_NM
                       , I.ATTR_07                                                AS BRAND
                       , I.ATTR_09                                                AS SERIES
                       , I.ATTR_11                                                AS GRADE
                       , A.ATTR_05                                                AS PLNT_CD
                       , A.ATTR_06                                                AS PLNT_NM
                       , Y.URNT_DMND_QTY                                          AS URNT_DMND_QTY
                       , CASE WHEN YYYYMM_SEQ IN (1,2,3,4) THEN X.QTY ELSE 0 END  AS QTY
                       , CASE WHEN YYYYMM_SEQ = 1 THEN X.QTY       END            AS M1_QTY
                       , CASE WHEN YYYYMM_SEQ = 2 THEN X.QTY       END            AS M2_QTY
                       , CASE WHEN YYYYMM_SEQ = 3 THEN X.QTY       END            AS M3_QTY
                       , CASE WHEN YYYYMM_SEQ = 4 THEN X.QTY       END            AS M4_QTY
                       , CASE WHEN YYYYMM_SEQ = 1 THEN X.RTF_QTY   END            AS RTF_QTY
                    FROM (
                            SELECT YYYYMM_SEQ                           AS YYYYMM_SEQ
                                 , ITEM_MST_ID                          AS ITEM_MST_ID
                                 , ACCOUNT_ID                           AS ACCOUNT_ID
                                 , EMP_ID                               AS EMP_ID
                                 , ISNULL(QTY     , 0)                  AS QTY
                                 , ISNULL(RTF_QTY , 0)                  AS RTF_QTY
                              FROM #TM_ENTRY

                         ) X
                         LEFT
                         JOIN (
                                 SELECT ITEM_MST_ID                     AS ITEM_MST_ID
                                      , ACCOUNT_ID                      AS ACCOUNT_ID
                                      , EMP_ID                          AS EMP_ID
                                      , ISNULL(URNT_DMND_QTY, 0)        AS URNT_DMND_QTY
                                   FROM TB_SKC_DP_URNT_DMND_MST WITH(NOLOCK)
                                   WHERE CONVERT(NVARCHAR(6), REQUEST_DATE_ID, 112) = @P_BASE_YYYYMM

                              ) Y
                           ON X.ITEM_MST_ID = Y.ITEM_MST_ID
                          AND X.EMP_ID      = Y.EMP_ID
                          AND X.ACCOUNT_ID  = Y.ACCOUNT_ID

                       , TB_DP_USER_ITEM_ACCOUNT_MAP U WITH(NOLOCK)
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
                     AND U.ACTV_YN          = 'Y'

               ) X
             , #TM_USER     U
         WHERE CORP_CD =  @P_CORP_CD
           AND X.EMP_ID        = U.EMP_ID  -- 2024.08.21 AJS 팀장은 팀원까지 조회 가능
           AND REGION  = CASE WHEN @P_REGION_CD = 'ALL' THEN REGION ELSE @P_REGION_CD END
      GROUP BY X.CORP_CD
             , X.CORP_NM
             , X.REGION
             , X.ACCOUNT_NM
             , X.EMP_ID
             , X.EMP_NM
             , X.BRAND
             , X.SERIES
             , X.GRADE
             , X.PLNT_CD
             , X.PLNT_NM


    -----------------------------------
    -- 조회
    -----------------------------------
     SELECT * FROM #TM_QTY

END

GO
