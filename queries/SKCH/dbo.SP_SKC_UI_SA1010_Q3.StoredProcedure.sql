USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q3]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q3] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q3
-- COPYRIGHT       : AJS
-- REMARK          : Main (재고 Sight )
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q3' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q3  'ko','I23671','HOME'
EXEC SP_SKC_UI_SA1010_Q3  'ko','I23671','UI_SA1012'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),@P_LANG_CD         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
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

    SELECT @V_FR_YYYYMM = CASE WHEN @P_VIEW_ID = 'HOME' THEN CONVERT(NVARCHAR(6), DATEADD(MONTH, -5, @V_TO_YYYYMM+'01'), 112)
                               ELSE CONVERT(NVARCHAR(6), DATEADD(MONTH, -11, @V_TO_YYYYMM + '01'), 112)
                           END

						   
    --SELECT @V_FR_YYYYMM = CONVERT(NVARCHAR(6), DATEADD(MONTH, -11, @V_TO_YYYYMM + '01'), 112) 

    --SET @V_FR_YYYYMM  = CASE WHEN @V_FR_YYYYMM < '202401' THEN '202401' ELSE @V_FR_YYYYMM END -- 24.10.11 S&OP 재고 수량 12개월로 조회되도록 수정


    PRINT '@V_FR_YYYYMM   ' + @V_FR_YYYYMM
    PRINT '@V_TO_YYYYMM   ' + @V_TO_YYYYMM
    ---------------------------------
    -- RAW
    ---------------------------------
    BEGIN
          EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1090_RAW_Q1
               @V_FR_YYYYMM                    -- 기준년월
             , @V_TO_YYYYMM                    -- 기준년월
             , @P_LANG_CD                      -- LANG_CD (ko, en)
             , @P_USER_ID                      -- USER_ID
             , 'UI_SA1010_3'                   -- VIEW_ID
          ;


          EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1070_RAW_Q1
               @V_FR_YYYYMM                    -- 기준년월
             , @V_TO_YYYYMM                    -- 기준년월
             , @P_LANG_CD                      -- LANG_CD (ko, en)
             , @P_USER_ID                      -- USER_ID
             , 'UI_SA1010_3'                   -- VIEW_ID
          ;
    END

    -----------------------------------
    -- 조회
    -----------------------------------	
	BEGIN
        SELECT X.YYYYMM                                                      AS YYYYMM
             , M.MEASURE_CD                                                  AS MEASURE_CD
             , M.MEASURE_NM                                                  AS MEASURE_NM
             , (CASE WHEN M.MEASURE_CD = '01' THEN SUM(X.TOT_STCK_QTY   )
                     WHEN M.MEASURE_CD = '02' THEN SUM(X.OFF_SPEC_STCK_QTY )
                     WHEN M.MEASURE_CD = '03' THEN SUM(X.ON_SPEC_STCK_QTY)
                     --WHEN M.MEASURE_CD = '04' THEN (ISNULL(MAX(Y.STCK_AMT) , 0) / ISNULL(MAX(Y.EX_ORG_AMT)  , 0)) * 365 / 12
					 WHEN M.MEASURE_CD = '04' THEN CASE WHEN MAX(Y.EX_ORG_AMT) != 0 THEN (ISNULL(MAX(Y.STCK_AMT) , 0) / ISNULL(MAX(Y.EX_ORG_AMT)  , 0)) * 365 / 12
														ELSE 0 END
                     WHEN M.MEASURE_CD = '05' THEN SUM(X.OFF_SPEC_STCK_QTY )    /  SUM(X.TOT_STCK_QTY   ) * 100
                    END)                                                     AS QTY
          FROM TM_SA1090 X  WITH(NOLOCK)                                    -- 비정상 재고
             , ( -- 재고 Sight 상세
                  SELECT YYYYMM                                              AS YYYYMM
                       , SUM(STCK_AMT)                                       AS STCK_AMT
                       , SUM(EX_ORG_AMT)                                     AS EX_ORG_AMT
                    FROM TM_SA1070 WITH(NOLOCK)
                   GROUP BY YYYYMM
               ) Y
             , (
                  SELECT COMN_CD                                             AS MEASURE_CD
                       , COMN_CD_NM                                          AS MEASURE_NM
                       , SEQ                                                 AS SEQ
                    FROM FN_COMN_CODE('SA1010_3','')
               ) M

         WHERE 1=1
           AND X.YYYYMM = Y.YYYYMM

         GROUP BY X.YYYYMM
             , M.MEASURE_CD
             , M.MEASURE_NM

         ORDER BY YYYYMM
             , MEASURE_CD
		

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
		--SELECT * INTO TM_SA10702 FROM TM_SA1070
		--SELECT * INTO TM_SA10902 FROM TM_SA1090
        --IF OBJECT_ID('TM_SA1090') IS NOT NULL   DROP TABLE TM_SA1090
        --IF OBJECT_ID('TM_SA1070') IS NOT NULL   DROP TABLE TM_SA1070
		
		
	END
END

GO
