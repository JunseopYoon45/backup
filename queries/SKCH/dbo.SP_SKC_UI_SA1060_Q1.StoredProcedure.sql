USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1060_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1060_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1060_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1060_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_SA1060_Q1 '202406','ko','I23779',''
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


   --DECLARE @V_TO_DAY NVARCHAR(10) = (SELECT CONVERT(NVARCHAR(10), MAX(BASE_DATE), 112) FROM TB_SKC_CM_FERT_STCK_HST)

    ----START   POPUP 과 동일-------------------------------


   DECLARE @V_FR_YYYYMM NVARCHAR(6) = @P_BASE_YYYYMM
   DECLARE @V_TO_YYYYMM NVARCHAR(6) = @P_BASE_YYYYMM  -- 2024.08.23 AJS
   --DECLARE @V_TO_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH,  3, @P_BASE_YYYYMM+'01'), 112)

   --SELECT @V_FR_YYYYMM, @V_TO_YYYYMM
   
    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1060','')

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
          FROM DBO.FN_DP_CLOSE_VERSION( @P_BASE_YYYYMM, @P_BASE_YYYYMM )


    -----------------------------------
    -- DP M0 : 기준년월이 6월일때 5월에 수립한 6월 7 8 9월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_ENTRY') IS NOT NULL DROP TABLE #TM_ENTRY -- 임시테이블 삭제

        SELECT Y.YYYYMM_SEQ                         AS YYYYMM_SEQ
             , CONVERT(NVARCHAR(6), BASE_DATE, 112) AS BASE_YYYYMM
             , ACCOUNT_ID                           AS ACCOUNT_ID
             , ITEM_MST_ID                          AS ITEM_MST_ID
             , EMP_ID                               AS EMP_ID
             , QTY                                  AS QTY
             , QTY_R                                AS RTF_QTY
          INTO #TM_ENTRY
          FROM TB_DP_ENTRY X WITH(NOLOCK)
             , (  SELECT ROW_NUMBER() OVER(ORDER BY YYYYMM) AS YYYYMM_SEQ
                       , YYYYMM
                    FROM TB_CM_CALENDAR WITH(NOLOCK)
                   WHERE YYYYMM  BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
                   GROUP BY YYYYMM
               ) Y

         WHERE CONVERT(NVARCHAR(6), BASE_DATE, 112) = Y.YYYYMM
           AND X.VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 1) --'948C2C3CB26E4A5B8E88652BEBD4DFE5'
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM


       --SELECT * FROM #TM_ENTRY
    -----------------------------------
    -- 조회
    -----------------------------------
--SET @V_TO_DAY = '20240529'
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT CORP_CD                                                  AS CORP_CD
             , CORP_NM                                                  AS CORP_NM
             , REGION                                                   AS REGION
             , ACCOUNT_NM                                               AS ACCOUNT_NM
             , EMP_ID                                                   AS EMP_ID
             , EMP_NM                                                   AS EMP_NM
             , BRAND                                                    AS BRAND
             , SERIES                                                   AS SERIES
             , GRADE                                                    AS GRADE
             , PLNT_CD                                                  AS PLNT_CD
             , PLNT_NM                                                  AS PLNT_NM
             , SUM(URNT_DMND_QTY ) / 1000                               AS URNT_DMND_QTY
             , SUM(QTY    )        / 1000                               AS TOT_QTY
             , SUM(M1_QTY )        / 1000                               AS M1_QTY
             , SUM(M2_QTY )        / 1000                               AS M2_QTY
             , SUM(M3_QTY )        / 1000                               AS M3_QTY
             , SUM(M4_QTY )        / 1000                               AS M4_QTY
             , SUM(RTF_QTY)        / 1000                               AS RTF_QTY
             , (SUM(QTY    ) - SUM(RTF_QTY ) ) / 1000                   AS GAP_QTY
             , (SUM(URNT_DMND_QTY) / SUM(RTF_QTY )) / 100               AS URNT_DMND_RATE
          INTO #TM_QTY
          FROM (
                  SELECT D.ANCESTER_CD                                  AS CORP_CD
                       , D.ANCESTER_NM                                  AS CORP_NM
                       , A.ATTR_04                                      AS REGION
                       , A.ACCOUNT_NM                                   AS ACCOUNT_NM
                       , U.EMP_ID                                       AS EMP_ID
                       , N.DISPLAY_NAME                                 AS EMP_NM
                       , I.ATTR_07                                      AS BRAND
                       , I.ATTR_09                                      AS SERIES
                       , I.ATTR_11                                      AS GRADE
                       , A.ATTR_05                                      AS PLNT_CD
                       , A.ATTR_06                                      AS PLNT_NM
                       , Y.URNT_DMND_QTY                                AS URNT_DMND_QTY
                       , X.QTY                                          AS QTY
                       , CASE WHEN YYYYMM_SEQ = 1 THEN X.QTY END        AS M1_QTY
                       , CASE WHEN YYYYMM_SEQ = 2 THEN X.QTY END        AS M2_QTY
                       , CASE WHEN YYYYMM_SEQ = 3 THEN X.QTY END        AS M3_QTY
                       , CASE WHEN YYYYMM_SEQ = 4 THEN X.QTY END        AS M4_QTY
                       , CASE WHEN YYYYMM_SEQ = 1 THEN X.RTF_QTY END    AS RTF_QTY
                    FROM (
                            SELECT YYYYMM_SEQ                           AS YYYYMM_SEQ
                                 , ITEM_MST_ID                          AS ITEM_MST_ID
                                 , ACCOUNT_ID                           AS ACCOUNT_ID
                                 , EMP_ID                               AS EMP_ID
                                 , QTY                                  AS QTY
                                 , RTF_QTY                              AS RTF_QTY
                              FROM #TM_ENTRY
                         ) X
                         LEFT JOIN
                              (  -- 긴급요청
                                 SELECT ITEM_MST_ID                     AS ITEM_MST_ID
                                      , ACCOUNT_ID                      AS ACCOUNT_ID
                                      , EMP_ID                          AS EMP_ID
                                      , URNT_DMND_QTY                   AS URNT_DMND_QTY
                                   FROM TB_SKC_DP_URNT_DMND_MST WITH(NOLOCK)
                                  WHERE CONVERT(NVARCHAR(6), REQUEST_DATE_ID, 112) = @P_BASE_YYYYMM
                              ) Y
                                ON X.ITEM_MST_ID      = Y.ITEM_MST_ID
                               AND X.EMP_ID           = Y.EMP_ID
                               AND X.ACCOUNT_ID       = Y.ACCOUNT_ID

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
                     AND I.ATTR_04   IN ('11', '1B')               -- Copoly, PET (11, 1B)   2024.07.17 AJS
                     AND I.ATTR_06   != '11-A0140'                 -- SKYPURA   2024.07.17 AJS
               ) X
      GROUP BY CORP_CD
             , CORP_NM
             , REGION
             , ACCOUNT_NM
             , EMP_ID
             , EMP_NM
             , BRAND
             , SERIES
             , GRADE
             , PLNT_CD
             , PLNT_NM


    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT M.MEASURE_CD                                                  AS MEASURE_CD
             , M.MEASURE_NM                                                  AS MEASURE_NM
             , A.CORP_CD                                                     AS CORP_CD
             , A.CORP_NM                                                     AS CORP_NM
             , CASE WHEN MEASURE_CD = '01' THEN  ISNULL(SUM(A.TOT_QTY        ) , 0)                             -- 수요계획 수량
                    WHEN MEASURE_CD = '02' THEN  ISNULL(SUM(A.RTF_QTY        ) , 0)                             -- RTF 수량
                    WHEN MEASURE_CD = '03' THEN  ISNULL(SUM(A.GAP_QTY        ) , 0)                             -- Gap
                    WHEN MEASURE_CD = '04' THEN  ISNULL(SUM(A.URNT_DMND_QTY  ) , 0)                             -- 긴급주문물량
                    WHEN MEASURE_CD = '05' THEN  ISNULL(SUM(A.URNT_DMND_QTY ) / SUM(A.RTF_QTY ), 0 ) / 100      -- 긴급 요청률
                END                                                          AS QTY
          FROM #TM_QTY A
             , #TM_MEASURE M
         GROUP BY
               A.CORP_CD
             , A.CORP_NM
             , MEASURE_CD
             , MEASURE_NM
         UNION ALL
        SELECT M.MEASURE_CD                                                  AS MEASURE_CD
             , M.MEASURE_NM                                                  AS MEASURE_NM
             , '999999'                                                      AS CORP_CD
             , ' Total'                                                        AS CORP_NM
             , CASE WHEN MEASURE_CD = '01' THEN  ISNULL(SUM(A.TOT_QTY        ) , 0)                               -- 수요계획 수량
                    WHEN MEASURE_CD = '02' THEN  ISNULL(SUM(A.RTF_QTY        ) , 0)                               -- RTF 수량
                    WHEN MEASURE_CD = '03' THEN  ISNULL(SUM(A.GAP_QTY        ) , 0)                               -- Gap
                    WHEN MEASURE_CD = '04' THEN  ISNULL(SUM(A.URNT_DMND_QTY  ) , 0)                               -- 긴급주문물량
                    WHEN MEASURE_CD = '05' THEN  ISNULL(SUM(A.URNT_DMND_QTY ) / SUM(A.RTF_QTY ), 0 ) / 100        -- 긴급 요청률
               END                                                           AS QTY
          FROM #TM_QTY A
             , #TM_MEASURE M

         GROUP BY
               MEASURE_CD
             , MEASURE_NM
         ORDER BY
               MEASURE_CD
             , MEASURE_NM
             , CORP_NM




END

GO
