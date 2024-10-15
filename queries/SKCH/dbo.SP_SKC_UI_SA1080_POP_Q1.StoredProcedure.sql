USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1080_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1080_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_CORP_CD             NVARCHAR(100)    = NULL    -- 법인
   , @P_PLNT_CD             NVARCHAR(100)    = NULL    -- 플랜트
   , @P_NRML_TYPE_CD        NVARCHAR(100)    = NULL    -- 비정상 구분
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1080_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 평가감 재고
--                   HQ, 법인별 평가감 재고 3개월 Trend를 조회할 수 있는 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1080_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1080_POP_Q1  '202406','1000','', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRAND_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID              ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID              ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

  DECLARE @FERT_DATE NVARCHAR(10) = (SELECT CONVERT(NVARCHAR(10), MAX(BASE_DATE),112) FROM TB_SKC_CM_FERT_STCK_HST  WITH(NOLOCK) )
    -----------------------------------
    -- 조회
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제

        SELECT Y.CORP_NM                                                                                     AS CORP_NM
             , Y.PLNT_NM                                                                                     AS PLNT_NM
             , ITM.NRML_TYPE_NM                                                                              AS NRML_TYPE_NM
             , ITM.BRND_NM                                                                                   AS BRND_NM
             , ITM.GRADE_NM                                                                                  AS GRADE_NM
             , X.ITEM_CD                                                                                     AS ITEM_CD
             , ITM.ITEM_NM                                                                                   AS ITEM_NM
             , SUM(CASE WHEN X.STCK_TYPE  = '평가감 수량' THEN X.TOTAL / 1000  ELSE 0 END )                  AS STCK_QTY
             , SUM(CASE WHEN X.STCK_TYPE  = '평가감 금액' THEN X.TOTAL / 1000  ELSE 0 END )                  AS STCK_AMT
          INTO #TM_QTY
          FROM TB_SKC_CM_STCK_WRITE_DOWN_LIST X
             , (  SELECT CORP_CD
                       , PLNT_CD
                       , CASE WHEN @P_LANG_CD = 'en' THEN CORP_NM_EN ELSE CORP_NM END AS CORP_NM
                       , CASE WHEN @P_LANG_CD = 'en' THEN PLNT_NM_EN ELSE PLNT_NM END AS PLNT_NM
                    FROM TB_SKC_CM_PLNT_MST WITH(NOLOCK)
                   WHERE DEL_YN  = 'N'
                     AND STCK_YN = 'Y'
               ) Y

             , (  SELECT A.ITEM_CD                                                                           AS ITEM_CD
                       , CASE WHEN @P_LANG_CD = 'en' THEN A.ITEM_NM_EN ELSE A.ITEM_NM END                    AS ITEM_NM
                       , A.BRND_CD                                                                           AS BRND_CD
                       , A.BRND_NM                                                                           AS BRND_NM
                       , A.SERIES_CD                                                                         AS SERIES_CD
                       , A.SERIES_NM                                                                         AS SERIES_NM
                       , A.GRADE_CD                                                                          AS GRADE_CD
                       , A.GRADE_NM                                                                          AS GRADE_NM
                       , CASE WHEN @P_LANG_CD = 'en' THEN B.MDM_NRML_TYPE_NM_EN ELSE B.MDM_NRML_TYPE_NM END  AS NRML_TYPE_NM
                       , B.MDM_NRML_TYPE_CD                                                                  AS NRML_TYPE_CD
                    FROM VW_ITEM A  WITH(NOLOCK)
                       , (  SELECT COD.COMN_CD                                                               AS COMN_CD
                                 , COD.ATTR_01_VAL                                                           AS MDM_NRML_TYPE_CD
                                 , COD.ATTR_02_VAL                                                           AS MDM_NRML_TYPE_NM
                                 , COD.ATTR_03_VAL                                                           AS MDM_NRML_TYPE_NM_EN
                              FROM TB_AD_COMN_CODE COD  WITH(NOLOCK)
                             WHERE COD.SRC_ID = (SELECT MAX(ID) FROM dbo.TB_AD_COMN_GRP  WITH(NOLOCK) WHERE GRP_CD = 'NRML_TYPE_MDM')
                         ) B
                   WHERE A.NRML_TYPE_CD = B.COMN_CD
                     AND A.ITEM_GRP_CD IN ( '11','1B')   -- 제품그룹코드 (COPOLYESTER)

             )  ITM

         WHERE X.ITEM_CD      = ITM.ITEM_CD
           AND X.PLNT_CD      = Y.PLNT_CD
           AND X.STCK_TYPE    IN ( '평가감 수량', '평가감 금액')
           AND X.WR_DATE      = @P_BASE_YYYYMM         -- 기준일자
           AND Y.CORP_CD      = CASE WHEN @P_CORP_CD = 'ALL' THEN  Y.CORP_CD ELSE @P_CORP_CD END
           AND X.TOTAL        > 0

         GROUP BY Y.CORP_NM
                , Y.PLNT_NM
                , ITM.BRND_NM
                , ITM.GRADE_NM
                , X.ITEM_CD
                , ITM.ITEM_NM
                , ITM.NRML_TYPE_NM


    -----------------------------------
    -- Sum 조회
    -----------------------------------
        SELECT CORP_NM               AS CORP_NM
             , PLNT_NM               AS PLNT_NM
             , NRML_TYPE_NM          AS NRML_TYPE_NM
             , BRND_NM               AS BRND_NM
             , GRADE_NM              AS GRADE_NM
             , ITEM_CD               AS ITEM_CD
             , ITEM_NM               AS ITEM_NM
             , STCK_QTY              AS STCK_QTY
             , STCK_AMT              AS STCK_AMT
          FROM #TM_QTY
         UNION ALL
        SELECT 'Total'               AS CORP_NM
             , ''                    AS PLNT_NM
             , ''                    AS NRML_TYPE_NM
             , ''                    AS BRND_NM
             , ''                    AS GRADE_NM
             , ''                    AS ITEM_CD
             , ''                    AS ITEM_NM
             , SUM(STCK_QTY)         AS STCK_QTY
             , SUM(STCK_AMT)         AS STCK_AMT
          FROM #TM_QTY



END

GO
