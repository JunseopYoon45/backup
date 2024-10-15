USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1130_POP_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1130_POP_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_RSRC_CD               NVARCHAR(100)   = NULL    -- 라인
   , @P_PRDT_GRADE_CD         NVARCHAR(100)   = NULL    -- 생산 Grade
   , @P_PRDT_GBN              NVARCHAR(100)   = NULL    -- 생산 계획/실적 구분   -- 2024.07.25 AJS
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1130_POP_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 비정상 제품 발생률
--                   라인별로 발생한 비정상 제품에 대한 수준을 측정하는 지표
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-02  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1130_POP_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1130_POP_Q1 '202406','CPR20','11-A0120B1210C0230|11-A0120B1210C0170','ACT','ko','I23779','UI_SA1130'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_GRADE_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_GBN                  ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    ---------------------------------
  -- RAW
    ---------------------------------

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1130_RAW_Q1
         @P_BASE_YYYYMM                   -- 기준년월
       , @P_BASE_YYYYMM                   -- 기준년월
       , @P_LANG_CD                       -- LANG_CD (ko, en)
       , @P_USER_ID                       -- USER_ID
       , @P_VIEW_ID                       -- VIEW_ID
    ;

	
    -----------------------------------
    -- #TM_PRDT_GRADE
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_PRDT_GRADE') IS NOT NULL DROP TABLE #TM_PRDT_GRADE -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_PRDT_GRADE
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_PRDT_GRADE_CD),''),'|')

		  --SELECT * FROM #TM_PRDT_GRADE
    -----------------------------------
    -- 조회 (전체)
    -----------------------------------
    BEGIN

        SELECT RSRC_NM                                                  AS RSRC_CD
             , BRAND                                                    AS BRAND
             , PRDT_GRADE_CD                                            AS PRDT_GRADE_CD
             , PRDT_GRADE_NM                                            AS PRDT_GRADE_NM
             , CASE WHEN PRDT_GBN = 'ACT' THEN '실적' ELSE '계획' END   AS PRDT_GBN
             , SUM(TOT_QTY    ) / 1000                                  AS TOT_QTY
             , SUM(ON_SPEC_QTY) / 1000                                  AS ON_SPEC_QTY
             , SUM(MIX_QTY    ) / 1000                                  AS MIX_QTY
             , SUM(ERR_QTY    ) / 1000                                  AS ERR_QTY
             , SUM(FILTER_QTY ) / 1000                                  AS FILTER_QTY
             , SUM(WIDE_QTY   ) / 1000                                  AS WIDE_QTY
             , (SUM(MIX_QTY) + SUM(ERR_QTY) + SUM(FILTER_QTY)) / SUM(TOT_QTY) * 100                   AS MEF_RATE
             , (SUM(MIX_QTY) + SUM(ERR_QTY) + SUM(FILTER_QTY) + SUM(WIDE_QTY)) / SUM(TOT_QTY) * 100   AS MEFW_RATE

          FROM TM_SA1130 WITH(NOLOCK)
         WHERE PRDT_GBN = @P_PRDT_GBN
		   AND RSRC_CD  = @P_RSRC_CD
           --AND (PRDT_GRADE_CD  IN (PRDT_GRADE_CD)   OR ISNULL( @P_PRDT_GRADE_CD , 'ALL') = 'ALL' )
         GROUP BY RSRC_NM
             , BRAND
             , PRDT_GRADE_CD
             , PRDT_GRADE_NM
             , PRDT_GBN

         ORDER BY RSRC_NM
             , BRAND
             , PRDT_GBN
             , PRDT_GRADE_CD
    END
	
    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1130') IS NOT NULL  DROP TABLE TM_SA1130
END

GO
