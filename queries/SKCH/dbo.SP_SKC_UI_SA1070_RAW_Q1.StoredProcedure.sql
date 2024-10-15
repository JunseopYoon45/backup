USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1070_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1070_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1070_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 재고 Sight 상세
--                   재고 Sight 정보를 상세 Lv로 조회하는 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1070_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1070_RAW_Q1  '202405','202406','ko','I23779','UI_SA1070'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

   DECLARE @V_BASE_DATE NVARCHAR(8) = (SELECT CONVERT(NVARCHAR(10), MAX(IF_STD_DATE), 112) FROM TB_SKC_CM_FERT_EOH_HST )
   DECLARE @V_TO_YYYYMM NVARCHAR(6) = @P_TO_YYYYMM
   --DECLARE @V_FR_YYYYMM NVARCHAR(6) = @P_FR_YYYYMM  --CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @P_TO_YYYYMM + '01'), 112)
   DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), DATEADD(MONTH, -16, @P_TO_YYYYMM + '01'), 112)

 PRINT '재고일수  @V_TO_YYYYMM ' +@V_TO_YYYYMM
 PRINT '재고일수  @V_FR_YYYYMM ' +@V_FR_YYYYMM
    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    BEGIN
        IF OBJECT_ID('TM_SA1070') IS NOT NULL DROP TABLE TM_SA1070 -- 임시테이블 삭제

        CREATE TABLE TM_SA1070
        (
          YYYYMM          NVARCHAR(100)
        , BRAND_CD        NVARCHAR(100)
        , BRAND           NVARCHAR(100)
        , GRADE_CD        NVARCHAR(100)
        , GRADE           NVARCHAR(100)
        , ITEM_CD         NVARCHAR(100)
        , ITEM_NM         NVARCHAR(100)
        , STCK_QTY        DECIMAL(18,0)
        , STCK_AMT        DECIMAL(18,0)
        , EX_ORG_AMT      DECIMAL(18,0)
        , STOCK_DAYS      DECIMAL(18,0)
        , LOGIN_ID        NVARCHAR(50) 

        )
    END
  --PRINT @V_FR_YYYYMM
  --PRINT @P_TO_YYYYMM
    -----------------------------------
    -- 매출원가
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_EX_ORG_AMT') IS NOT NULL DROP TABLE #TM_EX_ORG_AMT -- 임시테이블 삭제
        SELECT ITEM_CD                    AS ITEM_CD
			 , YYYYMM					  AS YYYYMM
             , MAX(SALES_QTY)             AS SALES_QTY
             --, AVG(EX_ORG_AMT)            AS EX_ORG_AMT
			 , AVG(EX_ORG_AMT) OVER (PARTITION BY ITEM_CD ORDER BY ITEM_CD, YYYYMM ROWS BETWEEN 5 PRECEDING AND CURRENT ROW ) AS EX_ORG_AMT --24.10.14 매출원가는 6개월간의 평균
          INTO #TM_EX_ORG_AMT
          FROM (
                  SELECT A.YYYYMM                                                           AS YYYYMM
                       , A.ITEM_CD                                                          AS ITEM_CD
                       , SUM(A.SALES_QTY )                                                  AS SALES_QTY
                       , (ISNULL(SUM(A.EX_ORG_AMT),0) + ISNULL(SUM(PRD_FIX_RT),0))          AS EX_ORG_AMT
                    FROM TB_SKC_DP_RPRT_PROF  A WITH(NOLOCK)
                   WHERE YYYYMM BETWEEN @V_FR_YYYYMM AND @P_TO_YYYYMM
                   GROUP BY A.YYYYMM, A.ITEM_CD
               ) X
         GROUP BY ITEM_CD, YYYYMM, EX_ORG_AMT

    -----------------------------------
    -- 조회
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제
        SELECT X.YYYYMM                                                           AS YYYYMM
             , I.ATTR_06                                                          AS BRAND_CD
             , I.ATTR_07                                                          AS BRAND
             , I.ATTR_10                                                          AS GRADE_CD
             , I.ATTR_11                                                          AS GRADE
             , X.ITEM_CD                                                          AS ITEM_CD
             , I.ITEM_NM                                                          AS ITEM_NM
             , SUM(ISNULL(X.STCK_QTY    , 0))  / 1000                             AS STCK_QTY         -- 재고수량
             , SUM(ISNULL(X.STCK_PRICE  , 0))                                     AS STCK_AMT         -- 재고금액
             , MAX(ISNULL(Y.EX_ORG_AMT  , 0))                                     AS EX_ORG_AMT       -- 6개월 매출 원가
             , 0                                                                  AS STOCK_DAYS       -- 재고일수
          INTO #TM_QTY
          FROM (
                  SELECT CONVERT(NVARCHAR(6), IF_STD_DATE, 112)    AS YYYYMM
                       , ITEM_CD                                   AS ITEM_CD
                       , STCK_QTY                                  AS STCK_QTY     -- 재고수량
                       , STCK_PRICE                                AS STCK_PRICE   -- 재고금액
                    FROM TB_SKC_CM_FERT_EOH_HST WITH(NOLOCK)
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), IF_STD_DATE, 112)  BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                     AND PLNT_CD IN ('1110', '1230')
               ) X

               LEFT JOIN
                    (
                       SELECT A.ITEM_CD                            AS ITEM_CD
							, A.YYYYMM							   AS YYYYMM
                            , A.SALES_QTY                          AS SALES_QTY
                            , A.EX_ORG_AMT                         AS EX_ORG_AMT
                         FROM #TM_EX_ORG_AMT A
                        WHERE A.EX_ORG_AMT  > 0
                    ) Y
                 ON X.ITEM_CD     = Y.ITEM_CD
				AND X.YYYYMM	  = Y.YYYYMM

             , TB_CM_ITEM_MST              I

         WHERE X.ITEM_CD      = I.ITEM_CD
           AND I.ATTR_04 IN ( '11','1B')   -- 제품그룹코드 (COPOLYESTER)
                 --AND I.ATTR_11 IN ('K2012','S2008','J2003','PN N1','PN N2','SF700')

         GROUP BY X.YYYYMM
             , I.ATTR_06
             , I.ATTR_07
             , I.ATTR_10
             , I.ATTR_11
             , X.ITEM_CD
             , I.ITEM_NM

    -----------------------------------
    -- 조회
    -----------------------------------
        INSERT INTO TM_SA1070
        SELECT YYYYMM                                                          AS YYYYMM
             , BRAND_CD                                                        AS BRAND_CD
             , BRAND                                                           AS BRAND
             , GRADE_CD                                                        AS GRADE_CD
             , GRADE                                                           AS GRADE
             , ITEM_CD                                                         AS ITEM_CD
             , ITEM_NM                                                         AS ITEM_NM
             , ISNULL(STCK_QTY   , 0)                                          AS STCK_QTY
             , ISNULL(STCK_AMT   , 0)                                          AS STCK_AMT
             , ISNULL(EX_ORG_AMT , 0)                                          AS EX_ORG_AMT  -- 6개월 매출원가
             , (ISNULL(STCK_AMT  , 0) / ISNULL(EX_ORG_AMT , 0)) * 365 / 12     AS STOCK_DAYS
			 , @P_USER_ID                                                      AS LOGIN_ID   
          FROM #TM_QTY

END

GO
