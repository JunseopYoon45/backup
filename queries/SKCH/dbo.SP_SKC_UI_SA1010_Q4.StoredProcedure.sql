USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q4]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q4] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q4
-- COPYRIGHT       : AJS
-- REMARK          : Main (평가감 재고)
--                    SCM Main 운영지표에 대해서 GC 사업부 기준 종합 숫자를 조회할 수 있는 Main 화면
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q4' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q4   'ko','I23671','HOME'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    --  기준년월
    -----------------------------------
  -- HOME 은 12개월
  -- Main Dashboard 는 6개월 조회
  -- 202401 이전은 데이터가 없으므로 202401이후로만 조회
    -----------------------------------
    DECLARE @V_FR_YYYYMM NVARCHAR(6)
    DECLARE @V_TO_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일

    --SELECT @V_FR_YYYYMM = CASE WHEN @P_VIEW_ID = 'HOME' THEN CONVERT(NVARCHAR(6), DATEADD(MONTH, -11, @V_TO_YYYYMM+'01'), 112)
    --                           ELSE CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @V_TO_YYYYMM + '01'), 112)
    --                       END
						   
    SELECT @V_FR_YYYYMM =  CONVERT(NVARCHAR(6), DATEADD(MONTH, -11, @V_TO_YYYYMM + '01'), 112)

    --SET @V_FR_YYYYMM  = CASE WHEN @V_FR_YYYYMM < '202401' THEN '202401' ELSE @V_FR_YYYYMM END -- 24.10.11 S&OP 재고 수량 12개월로 조회되도록 수정

    ---------------------------------
    -- RAW
    ---------------------------------
    BEGIN
        EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1080_RAW_Q1
             @V_FR_YYYYMM                -- 기준년월
           , @V_TO_YYYYMM                -- 기준년월
           , @P_LANG_CD                  -- LANG_CD (ko, en)
           , @P_USER_ID                  -- USER_ID
           , 'UI_SA1080'                 -- VIEW_ID
        ;
     END


    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_SA1080') IS NOT NULL DROP TABLE #TM_SA1080
        SELECT *
          INTO #TM_SA1080
          FROM TM_SA1080

    -----------------------------------
    -- 조회
    -----------------------------------

        SELECT D.YYYYMM                                  AS YYYYMM
             , CASE WHEN D.STCK_TYPE_CD = '01' THEN D.CORP_CD
                    ELSE '9999'
                END                                      AS MEASURE_CD
             , CASE WHEN D.STCK_TYPE_CD = '01' THEN D.CORP_NM
                    ELSE '평가감 금액 (백만원)'
                END                                      AS MEASURE_NM
             , ISNULL(SUM(X.QTY),0)                      AS QTY
          FROM (  SELECT DISTINCT YYYYMM
                       , STCK_TYPE_CD
                       , CORP_CD
                       , CORP_NM
                    FROM TB_CM_CALENDAR    C WITH(NOLOCK)
                       , #TM_SA1080         A WITH(NOLOCK)
                   WHERE YYYYMM BETWEEN @V_FR_YYYYMM AND @V_TO_YYYYMM
               ) D

               LEFT JOIN #TM_SA1080 X WITH(NOLOCK)
                 ON D.YYYYMM           = X.WR_DATE
                AND D.STCK_TYPE_CD     = X.STCK_TYPE_CD
                AND D.CORP_CD          = X.CORP_CD

         GROUP BY D.YYYYMM
                , D.STCK_TYPE_CD
                , CASE WHEN D.STCK_TYPE_CD = '01' THEN D.CORP_CD
                       ELSE '9999'
                   END
                , CASE WHEN D.STCK_TYPE_CD = '01' THEN D.CORP_NM
                       ELSE '평가감 금액 (백만원)'
                   END
         ORDER BY D.YYYYMM
                , D.STCK_TYPE_CD
                , MEASURE_NM



    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1080') IS NOT NULL   DROP TABLE TM_SA1080


END
GO
