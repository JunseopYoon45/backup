USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1010_Q2]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1010_Q2] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1010_Q2
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1010_Q2' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1010_Q2   'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100),  @P_LANG_CD             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_USER_ID             ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100),  @P_VIEW_ID             ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN   
    -----------------------------------
    --  기준년월
    -----------------------------------
   DECLARE @V_TO_YYYYMM NVARCHAR(6) = (SELECT DBO.FN_SnOP_BASE_YYYYMM())                                     --  기준년월은 10일 이전은 M-2, 10일부터 M-1으로 일괄 통일
   DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6),DATEADD(MONTH, -1,  @V_TO_YYYYMM + '01'), 112)

   PRINT '@V_FR_YYYYMM    '+ @V_FR_YYYYMM
   PRINT '@V_TO_YYYYMM    '+ @V_TO_YYYYMM
    -----------------------------------
	-- 
    -----------------------------------
	DECLARE @TM_DMND_PLAN TABLE
	(

        BASE_YYYYMM		   NVARCHAR(10)
     ,  M3_QTY			   DECIMAL(18,0)
     ,  M2_QTY			   DECIMAL(18,0)
     ,  M1_QTY			   DECIMAL(18,0)
     ,  CHNG_RATE		   DECIMAL(18,6)
     ,  RTF_QTY			   DECIMAL(18,0)
     ,  SALES_QTY		   DECIMAL(18,0)
     ,  ACHIEV_RATE		   DECIMAL(18,6)
     ,  URNT_DMND_QTY	   DECIMAL(18,0)
     ,  URNT_DMND_RATE	   DECIMAL(18,6)
	
	)
    
    
    ---------------------------------
	-- (전월) 수요계획, 판매계획
    ---------------------------------    
    INSERT INTO @TM_DMND_PLAN
    EXEC SP_SKC_UI_SA1010_Q2_DTL   @V_FR_YYYYMM,@P_LANG_CD,@P_USER_ID,@P_VIEW_ID  
    
    
    ---------------------------------
	-- (당월) 수요계획, 판매계획
    ---------------------------------    
    INSERT INTO @TM_DMND_PLAN
    EXEC SP_SKC_UI_SA1010_Q2_DTL   @V_TO_YYYYMM,@P_LANG_CD,@P_USER_ID,@P_VIEW_ID
    
    ---------------------------------
	-- 조회
    ---------------------------------    
    SELECT * FROM @TM_DMND_PLAN

END

GO
