USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1140_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1140_Q1] (
     @P_BASE_YYYYMM           NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1140_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 품변기회비용
--                   특정 기준년월의 품변 기회비용을 조회할 수 있는 상세 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-07-08  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1140_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1140_Q1 '202407','ko','I23779','UI_SA1140'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYYMM               ), '')
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

    EXEC T3SMARTSCM_NEW.DBO.SP_SKC_UI_SA1140_RAW_Q1
         @P_BASE_YYYYMM              -- 기준년월
       , @P_LANG_CD                  -- LANG_CD (ko, en)
       , @P_USER_ID                  -- USER_ID
       , @P_VIEW_ID                  -- VIEW_ID
    ;

	
	---------------------------------
  -- 조회
    ---------------------------------
	SELECT BASE_YYYYMM
         , RSRC_CD
		 , RSRC_NM   AS RSRC_NM
         , F_GC_CNT
         , L_GC_CNT
         , GAP_CNT
         , F_GC_QTY
         , L_GC_QTY
         , GAP_QTY
         , PROP_COST
         , GC_COST
	  FROM TM_SA1140 WITH(NOLOCK)

     UNION ALL	  
	SELECT BASE_YYYYMM	  AS BASE_YYYYMM
         , 'Total'		  AS RSRC_CD
         , 'Total'		  AS RSRC_NM
         , SUM(F_GC_CNT	)	  AS F_GC_CNT
         , SUM(L_GC_CNT	)	  AS L_GC_CNT
         , SUM(GAP_CNT	)	  AS GAP_CNT
         , SUM(F_GC_QTY	)	  AS F_GC_QTY
         , SUM(L_GC_QTY	)	  AS L_GC_QTY
         , SUM(GAP_QTY	)	  AS GAP_QTY
         , NULL          	  AS PROP_COST
         , SUM(GC_COST	)	  AS GC_COST
	  FROM TM_SA1140 WITH(NOLOCK)
	  GROUP BY BASE_YYYYMM	 

	  ORDER BY RSRC_CD, BASE_YYYYMM


END

GO
