USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q2_DTL]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q2_DTL] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q2_DTL
-- COPYRIGHT       : AJS
-- REMARK          : 수요계획 변경률
--                 + 판매계획 달성률
--                 + 긴급 요청률
--                   (M-2)의 수요계획과 (M-0)의 수요계획 변경률을 조회하는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-20  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q2_DTL' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q2_DTL  '202407','ko','I23670','UI_SA1010'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_BASE_YYYYMM         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID             ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @P_VER_FR_YYYYMM     NVARCHAR(10) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @P_BASE_YYYYMM + '01'), 112)

  PRINT @P_VER_FR_YYYYMM
  PRINT @P_BASE_YYYYMM
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

    -----------------------------------
    -- DP M0 : 기준년월이 6월일때 5월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M0') IS NOT NULL DROP TABLE #TM_DP_M0 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M0
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 1) --'948C2C3CB26E4A5B8E88652BEBD4DFE5'
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM


    -----------------------------------
  -- DP M1 : 기준년월이 6월일때  4월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M1') IS NOT NULL DROP TABLE #TM_DP_M1 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M1
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 2) -- '8C3BBD2D91944C6B9EC006F600E6A8B5'
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM

    -----------------------------------
  -- DP M2   : 기준년월이 6월일때  3월에 수립한 6월 DP
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_DP_M2') IS NOT NULL DROP TABLE #TM_DP_M2 -- 임시테이블 삭제

        SELECT ACCOUNT_ID       AS ACCOUNT_ID
             , ITEM_MST_ID      AS ITEM_MST_ID
             , EMP_ID           AS EMP_ID
             , QTY              AS QTY
             , QTY_R            AS RTF_QTY
          INTO #TM_DP_M2
          FROM TB_DP_ENTRY WITH(NOLOCK)
         WHERE VER_ID = (SELECT DP_VERSION_ID FROM #TM_DP_VER WHERE ROW_NUM = 3) --'69B39F63604B43B0AB01516B9E335711'
           AND CONVERT(NVARCHAR(6), BASE_DATE, 112) = @P_BASE_YYYYMM

    -----------------------------------
    -- 조회
    -----------------------------------
--SET @V_TO_DAY = '20240529'
    --IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제


        SELECT @P_BASE_YYYYMM AS BASE_YYYYMM
             ,  SUM(ISNULL(X.M3_QTY        , 0)) / 1000                                                         AS M3_QTY
             ,  SUM(ISNULL(X.M2_QTY        , 0)) / 1000                                                         AS M2_QTY
             ,  SUM(ISNULL(X.M1_QTY        , 0)) / 1000                                                         AS M1_QTY
             , ABS((SUM(ISNULL(X.M3_QTY        , 0)) - SUM(ISNULL(X.M1_QTY, 0)))) / SUM(ISNULL(X.M3_QTY, 0)) * 100  AS CHNG_RATE     -- 변경률
             ,  SUM(ISNULL(X.RTF_QTY       , 0)) / 1000                                                         AS RTF_QTY
             ,  SUM(ISNULL(X.SALES_QTY     , 0)) / 1000                                                         AS SALES_QTY
             ,  SUM(ISNULL(X.SALES_QTY     , 0)) / SUM(ISNULL(X.RTF_QTY, 0) ) * 100                             AS ACHIEV_RATE   -- 달성률
             ,  SUM(ISNULL(Y.URNT_DMND_QTY , 0)) / 1000                                                         AS URNT_DMND_QTY
             , (SUM(ISNULL(Y.URNT_DMND_QTY , 0)) / SUM(ISNULL(X.RTF_QTY, 0) ) ) / 100                           AS URNT_DMND_RATE
          FROM (
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , QTY                   AS M3_QTY
                       , 0                     AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M2
                   WHERE 1=1

                   UNION ALL
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , QTY                   AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M1

                   UNION ALL
                  SELECT ITEM_MST_ID           AS ITEM_MST_ID
                       , ACCOUNT_ID            AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , 0                     AS M2_QTY
                       , QTY                   AS M1_QTY
                       , RTF_QTY               AS RTF_QTY
                       , 0                     AS SALES_QTY
                    FROM #TM_DP_M0

                   UNION ALL
                   -- 판매실적
                  SELECT I.ID                  AS ITEM_MST_ID
                       , A.ID                  AS ACCOUNT_ID
                       , 0                     AS M3_QTY
                       , 0                     AS M2_QTY
                       , 0                     AS M1_QTY
                       , 0                     AS RTF_QTY
                       , SALES_QTY             AS SALES_QTY
                    FROM TB_SKC_DP_RPRT_PROF X WITH(NOLOCK)
                       , TB_DP_ACCOUNT_MST   A WITH(NOLOCK)
                       , TB_CM_ITEM_MST      I WITH(NOLOCK)
                   WHERE 1=1
                     AND X.YYYYMM           = @P_BASE_YYYYMM
                     AND X.ACNT_CD          = A.ATTR_03
                     AND X.ITEM_CD          = I.ITEM_CD
                     AND I.ATTR_04         IN ('11', '1B')            -- Copoly, PET (11, 1B)   2024.07.17 AJS
                     AND I.ATTR_06         != '11-A0140'              -- SKYPURA   2024.07.17 AJS
               ) X
               LEFT JOIN
                    (
                       SELECT ITEM_MST_ID                                    AS ITEM_MST_ID
                            , ACCOUNT_ID                                     AS ACCOUNT_ID
                            , SUM(URNT_DMND_QTY)                             AS URNT_DMND_QTY
                         FROM TB_SKC_DP_URNT_DMND_MST WITH(NOLOCK)
                        WHERE CONVERT(NVARCHAR(6), REQUEST_DATE_ID, 112)      = @P_BASE_YYYYMM
                        GROUP BY ITEM_MST_ID
                               , ACCOUNT_ID
                    ) Y
                 ON X.ITEM_MST_ID = Y.ITEM_MST_ID
                AND X.ACCOUNT_ID  = Y.ACCOUNT_ID

             , TB_DP_USER_ITEM_ACCOUNT_MAP U
             , TB_CM_ITEM_MST              I
             , TB_DP_ACCOUNT_MST           A
             , TB_AD_USER                  N
             , TB_DPD_SALES_HIER_CLOSURE   D

         WHERE 1=1
           AND X.ACCOUNT_ID       = U.ACCOUNT_ID
           AND X.ITEM_MST_ID      = U.ITEM_MST_ID
           AND U.EMP_ID           = N.USERNAME
           AND X.ACCOUNT_ID       = A.ID
           AND A.ACCOUNT_CD       = D.DESCENDANT_CD
           AND X.ITEM_MST_ID      = I.ID
           AND D.DEPTH_NUM        = 2
           AND D.USE_YN           = 'Y'
           AND A.ACTV_YN          = 'Y'
           AND U.ACTV_YN          = 'Y'
           AND I.ATTR_04         IN ('11', '1B')            -- Copoly, PET (11, 1B)   2024.07.17 AJS
           AND I.ATTR_06         != '11-A0140'              -- SKYPURA   2024.07.17 AJS


END

GO
