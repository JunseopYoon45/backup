USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1080_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1080_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1080_RAW_Q1
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1080_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1080_RAW_Q1  '202404','202406', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    BEGIN
        IF OBJECT_ID('TM_SA1080') IS NOT NULL DROP TABLE TM_SA1080 -- 임시테이블 삭제

         CREATE TABLE TM_SA1080
             (
               WR_DATE          NVARCHAR(100)
             , CORP_CD          NVARCHAR(100)
             , CORP_NM          NVARCHAR(100)
             , STCK_TYPE_CD     NVARCHAR(100)
             , STCK_TYPE        NVARCHAR(100)
             , QTY              DECIMAL(18,0)
             , LOGIN_ID         NVARCHAR(50) 
             )
    END

PRINT '@P_FR_YYYYMM  ' + @P_FR_YYYYMM
PRINT '@P_TO_YYYYMM  ' + @P_TO_YYYYMM
    -----------------------------------
    -- 조회
    -----------------------------------

        INSERT INTO TM_SA1080
        SELECT WDM.WR_DATE                                                                       AS WR_DATE
		     , WDM.CORP_CD																		 AS CORP_CD
             , (SELECT TOP 1 CORP_NM FROM TB_SKC_CM_PLNT_MST A  WITH(NOLOCK) WHERE A.CORP_CD = WDM.CORP_CD)    AS CORP_NM
             , CASE WHEN STCK_TYPE  = '평가감 수량' THEN '01' ELSE '02' END                       AS STCK_TYPE_CD
             , STCK_TYPE                                                                         AS STCK_TYPE
             , SUM(CASE WHEN STCK_TYPE = '평가감 수량' THEN TOTAL / 1000
                        WHEN STCK_TYPE = '평가감 금액' THEN TOTAL / 1000000 ELSE 0 END )          AS QTY
			 , @P_USER_ID                                                      AS LOGIN_ID   
          FROM TB_SKC_CM_STCK_WRITE_DOWN_LIST WDM WITH(NOLOCK)
         WHERE 1=1
           AND WDM.STCK_TYPE IN ('평가감 수량', '평가감 금액')
           AND WR_DATE     BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM       -- 기준일자
		   AND WRHS_CD != '1700'
           AND EXISTS (SELECT 1
                         FROM TB_SKC_CM_PLNT_MST Z WITH(NOLOCK)
                        WHERE WDM.PLNT_CD = Z.PLNT_CD
                          AND Z.STCK_YN   = 'Y'
						  AND Z.PLNT_CD NOT IN ('1120', '1250', '1130')
                       )
           AND EXISTS (SELECT 1
                         FROM TB_CM_ITEM_MST I WITH(NOLOCK)
                        WHERE WDM.ITEM_CD = I.ITEM_CD
                          AND I.ATTR_04 IN ( '11', '1B')
						  AND ITEM_TP_ID IN ('GSUB', 'GFRT')
                      )
         GROUP BY WDM.WR_DATE
		     , WDM.CORP_CD	
             , CASE WHEN STCK_TYPE  = '평가감 수량' THEN '01' ELSE '02' END
             , STCK_TYPE
             , WDM.CORP_CD




END

GO
