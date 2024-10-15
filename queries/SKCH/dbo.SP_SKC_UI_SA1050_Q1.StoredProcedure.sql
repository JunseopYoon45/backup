USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1050_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1050_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1050_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 수요계획 변경률
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1050_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1050_Q1  '202407','ko','I23779','UI_SA1050'
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
	   
    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
		  INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1050','')
		  
    ---------------------------------
  -- RAW DATA
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
        SELECT Y.MEASURE_CD            AS MEASURE_CD
             , Y.MEASURE_NM            AS MEASURE_NM
             , X.CORP_CD               AS CORP_CD
             , X.CORP_NM               AS CORP_NM			 
             , CASE WHEN MEASURE_CD = '01' THEN SUM(M3_QTY	) / 1000								  -- (M-3) 수요계획
                    WHEN MEASURE_CD = '02' THEN SUM(M2_QTY	) / 1000								  -- (M-2) 수요계획
                    WHEN MEASURE_CD = '03' THEN SUM(M1_QTY	) / 1000								  -- (M-1) 수요계획
                    WHEN MEASURE_CD = '04' THEN (SUM(M3_QTY) - SUM(M1_QTY))	/ 1000  -- Gap
                    WHEN MEASURE_CD = '05' THEN ISNULL(ABS((SUM(M3_QTY) - SUM(M1_QTY)) / SUM(M3_QTY)) * 100 ,0)		  -- 변경율
                END               AS QTY

          FROM TM_SA1040 X --#TM_QTY X
             , #TM_MEASURE Y
         GROUP BY Y.MEASURE_CD
                , Y.MEASURE_NM
                , X.CORP_CD
                , X.CORP_NM
         UNION ALL
        SELECT Y.MEASURE_CD          AS MEASURE_CD
             , Y.MEASURE_NM          AS MEASURE_NM
             , '00000'               AS CORP_CD
             , ' Total'               AS CORP_NM			 
             , CASE WHEN MEASURE_CD = '01' THEN SUM(M3_QTY	) / 1000										  -- (M-3) 수요계획
                    WHEN MEASURE_CD = '02' THEN SUM(M2_QTY	) / 1000										  -- (M-2) 수요계획
                    WHEN MEASURE_CD = '03' THEN SUM(M1_QTY	) / 1000										  -- (M-1) 수요계획
                    WHEN MEASURE_CD = '04' THEN (SUM(M3_QTY) - SUM(M1_QTY))	/ 1000  -- Gap
                    WHEN MEASURE_CD = '05' THEN ISNULL(ABS((SUM(M3_QTY) - SUM(M1_QTY)) / SUM(M3_QTY)) * 100 ,0)		  -- 변경율
                END               AS QTY

          FROM TM_SA1040 x --#TM_QTY X
             , #TM_MEASURE Y
         GROUP BY Y.MEASURE_CD
                , Y.MEASURE_NM

         ORDER BY Y.MEASURE_CD
                , Y.MEASURE_NM
                , X.CORP_NM

    -----------------------------------
    -- 임시테이블 삭제
    -----------------------------------
        --IF OBJECT_ID('TM_SA1040') IS NOT NULL DROP TABLE TM_SA1040

END

GO
