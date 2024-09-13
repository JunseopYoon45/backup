USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_Q2] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_Q1
-- COPYRIGHT       : ZIONEX
-- REMARK          : DMT 생산계획
--                   1) Flake/Briquet, Molten 에 대한 일 단위 생산계획을 수립 유관부서에 배포
--					 2) 하단GRID
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-19  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_Q2' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2020_Q2  'FP-20240813-DM-11','I23768','UI_FP2020'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

	  , @PLAN_STR_DTE NVARCHAR(8) = ''
	  , @PLAN_END_DTE NVARCHAR(8) = ''
	  , @EOH_DTE      NVARCHAR(8) = ''


    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')

                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


  SELECT  @PLAN_STR_DTE  = CONVERT(NVARCHAR(8), FROM_DT, 112)
       ,  @EOH_DTE       = CONVERT(NVARCHAR(8), DATEADD(DAY, -1, FROM_DT), 112)
       ,  @PLAN_END_DTE  = CONVERT(NVARCHAR(8), TO_DT, 112)
    FROM  VW_FP_PLAN_VERSION
   WHERE  VERSION = @P_FP_VERSION
---------- LOG END ----------
BEGIN

	EXEC SP_SKC_UI_FP2020_RAW_Q2 @P_FP_VERSION, @P_USER_ID, @P_VIEW_ID;

    -----------------------------------
    -- 조회 
    -----------------------------------
	
	IF OBJECT_ID('tempdb..#TM_MES') IS NOT NULL DROP TABLE #TM_MES -- 임시테이블 삭제		  

        SELECT  B.ATTR_06 AS BRND_CD
		     ,  B.ATTR_07 AS BRND_NM
		     ,  B.ATTR_08 AS PRDT_GRADE_CD
		     ,  B.ATTR_09 AS PRDT_GRADE_NM
		     ,  B.ITEM_CD
		     ,  B.ITEM_NM
		     ,  A.COMN_CD AS MEASURE_CD
		     ,  A.COMN_CD_NM AS MEASURE_NM
			 , CASE WHEN COMN_CD = '02' THEN '#a59ed9'					
					WHEN COMN_CD = '03' THEN '#2f57d2'
					WHEN COMN_CD = '04' THEN '#23bd19'
					WHEN COMN_CD = '05' THEN '#bd195d'
					WHEN COMN_CD = '06' THEN '#b5e14d'
					WHEN COMN_CD = '07' THEN '#44546a'
					WHEN COMN_CD = '08' THEN '#ffc000' END AS COL_CD
			 ,  C.DAT_ID
             ,  ISNULL(D.BOH_QTY, 0) AS BOH_QTY
          INTO  #TM_MES
		  FROM  FN_COMN_CODE('FP2020', '') A
         INNER  JOIN TB_CM_ITEM_MST B
		    ON  1=1
           AND  ITEM_TP_ID = 'GFRT'
           AND  ATTR_10    = '27-A0310B3130C0850'
         INNER  JOIN TB_CM_CALENDAR C
	        ON  1=1
           AND  C.DAT_ID BETWEEN  @PLAN_STR_DTE  AND @PLAN_END_DTE
          LEFT  OUTER JOIN 
             (
			 
			  --  SELECT  SUM(STCK_QTY)/1000 AS BOH_QTY
		   --       FROM  TB_SKC_CM_FERT_STCK_HST A
				 --WHERE  EXISTS ( SELECT 1 FROM TB_CM_ITEM_MST X WHERE A.ITEM_CD = X.ITEM_CD AND  X.ITEM_TP_ID = 'GFRT' AND  X.ATTR_04    = '27')
     --              AND  A.PLNT_CD = '1250'
				 --  AND  CONVERT(NVARCHAR(8),NEW_AGNG_STD_DATE,112) = @EOH_DTE
				 --GROUP  BY A.ITEM_CD
                SELECT  SUM(STCK_QTY) AS BOH_QTY 
                  FROM  TB_SKC_CM_MES_LINE_STCK_HST
                 WHERE  CONVERT(NVARCHAR(8),CLOSE_DT,112) = @EOH_DTE
                   AND  ITEM_CD = '204601'
				   AND  RSRC_NM = 'DMT'
 

             )  D
            ON  1=1
         WHERE  A.COMN_CD IN ('02', '03', '04', '05', '06', '07', '08');

	IF OBJECT_ID('tempdb..#TM_FP_QTY') IS NOT NULL DROP TABLE #TM_FP_QTY -- 임시테이블 삭제

		SELECT A.BRND_CD
		     , A.BRND_NM
		     , A.PRDT_GRADE_CD
		     , A.PRDT_GRADE_NM
		     , A.ITEM_CD
			 , A.ITEM_NM
			 , A.DAT_ID
			 , A.BOH_QTY
			 , A.MEASURE_CD
			 , A.MEASURE_NM
			 , CASE WHEN A.MEASURE_CD = '02' THEN B.PLAN_QTY
					WHEN A.MEASURE_CD = '03' THEN B.DMND_REQ_QTY
					WHEN A.MEASURE_CD = '04' THEN B.SP_REQ_QTY
					WHEN A.MEASURE_CD = '05' THEN B.SD_REQ_QTY 
					WHEN A.MEASURE_CD = '06' THEN B.EOH_QTY 
					WHEN A.MEASURE_CD = '07' THEN B.MAX_STK_LVL
					WHEN A.MEASURE_CD = '08' THEN B.MIN_STK_LVL END AS QTY
             ,  A.COL_CD
		  INTO  #TM_FP_QTY
		  FROM  #TM_MES A
		 INNER JOIN TM_FP2020 B
		    ON A.ITEM_CD = B.ITEM_CD
		   AND A.DAT_ID = B.DAT_ID
		 WHERE  1=1

		  SELECT @P_FP_VERSION AS VER_ID
			   , A.BRND_CD
			   , A.BRND_NM
			   , A.PRDT_GRADE_CD
			   , A.PRDT_GRADE_NM
			   , A.ITEM_CD
			   , A.ITEM_NM
			   , A.BOH_QTY /1000 as BOH_QTY
			   , A.DAT_ID AS PLAN_DTE
			   , B.DOW_NM
			   , B.HOLID_YN
			   , MEASURE_CD
			   , MEASURE_NM
			   , CASE WHEN A.DAT_ID >= FORMAT(GETDATE(), 'yyyyMMdd') THEN 'Y'
					  ELSE 'N' END AS ADJ_YN
			   , QTY /1000 AS QTY
			   , A.COL_CD
			   , CASE WHEN MEASURE_CD IN ('07', '08') THEN '재고 관리 Level'
					  ELSE MEASURE_NM END AS MEASURE_SUB_NM
		    FROM #TM_FP_QTY A
		   INNER JOIN TB_CM_CALENDAR B
		      ON A.DAT_ID = B.DAT
		   ORDER BY A.ITEM_CD, A.DAT_ID, MEASURE_CD;
		   --EXEC SP_SKC_UI_FP2020_Q2'','','UI_FP2020'
END;
GO
