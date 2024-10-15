USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1090_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1090_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_BRAND_CD              NVARCHAR(100)   = NULL    -- BRAND
   , @P_GRADE_CD              NVARCHAR(100)   = NULL    -- GRADE
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1090_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 비정상 재고 상세
--                   비정상 재고 수량을 상세 lv로 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-25  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1090_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1090_POP_Q1  '202406','11-A0110','ALL','ko','I23779','UI_SA1090'
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

    -----------------------------------
    -- #TM_BRND
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_BRND') IS NOT NULL DROP TABLE #TM_BRND -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_BRND
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_BRAND_CD),''),'|')
		  ;
    -----------------------------------
    -- #TM_GRADE
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_GRADE
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_GRADE_CD),''),'|')
		  ;

    -----------------------------------
    -- 조회
    -----------------------------------
        SELECT I.ATTR_15                                 AS NRML_TYPE  -- 비정상
             , I.ATTR_07                                 AS BRAND
             , I.ATTR_11                                 AS GRADE
             , X.ITEM_CD                                 AS ITEM_CD
             , I.ITEM_NM                                 AS ITEM_NM
             , SUM(ISNULL(X.STCK_QTY    , 0)) / 1000     AS STCK_QTY      -- 재고수량
          FROM (
                  SELECT PLNT_CD                         AS PLNT_CD
                       , ITEM_CD                         AS ITEM_CD
                       , STCK_QTY                        AS STCK_QTY    -- 재고수량
                    FROM TB_SKC_CM_FERT_EOH_HST WITH(NOLOCK)
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), IF_STD_DATE, 112)  = @P_BASE_YYYYMM
                     AND PLNT_CD IN ('1110', '1230')
               ) X

             , TB_CM_ITEM_MST              I

         WHERE X.ITEM_CD      = I.ITEM_CD
           AND I.ATTR_04 IN ( '11','1B')   -- 제품그룹코드 (COPOLYESTER)
           AND (I.ATTR_06  IN (SELECT VAL FROM #TM_BRND)    OR ISNULL( @P_BRAND_CD , 'ALL') = 'ALL' )
           AND (I.ATTR_10  IN (SELECT VAL FROM #TM_GRADE)   OR ISNULL( @P_GRADE_CD , 'ALL') = 'ALL' )


         GROUP BY I.ATTR_15
             , I.ATTR_07
             , I.ATTR_11
             , X.ITEM_CD
             , I.ITEM_NM

         ORDER BY I.ATTR_15
             , I.ATTR_07
             , I.ATTR_11
             , X.ITEM_CD
             , I.ITEM_NM



END

GO
