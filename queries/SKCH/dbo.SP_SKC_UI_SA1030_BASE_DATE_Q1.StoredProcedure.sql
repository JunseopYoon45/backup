USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1030_BASE_DATE_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1030_BASE_DATE_Q1] (
     @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1030_BASE_DATE_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 사업 계획 달성률
--                   사업계획 대비 판매실적의 달성률을 조회하는 상세 화면
--                   기준일자 Default Setting용
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1030_BASE_DATE_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1030_BASE_DATE_Q1  'I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    --  기준년월
    -----------------------------------
    DECLARE @V_TO_YYYYMM NVARCHAR(7) = (SELECT CONVERT(NVARCHAR(10), CONVERT(DATE, DBO.FN_SnOP_BASE_YYYYMM()+'01'), 121))   --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일
    DECLARE @V_FR_YYYYMM NVARCHAR(7) = CONVERT(NVARCHAR(7), DATEADD(MONTH, 0, @V_TO_YYYYMM+ '-01'), 121)


        SELECT @V_FR_YYYYMM AS FR_YYYYMM
             , @V_TO_YYYYMM AS TO_YYYYMM


END
GO
