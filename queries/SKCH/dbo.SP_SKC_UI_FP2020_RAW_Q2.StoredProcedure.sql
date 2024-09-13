USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_RAW_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_RAW_Q2] (
     @P_FP_VERSION			NVARCHAR(30)    = NULL    /*FP 버전*/   
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_RAW_Q2
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_RAW_Q2' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2020_RAW_Q2  'FP-20240813-DM-11','I23768','UI_FP2020'
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

    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    BEGIN
        IF OBJECT_ID('TM_FP2020') IS NOT NULL DROP TABLE TM_FP2020 -- 임시테이블 삭제

        CREATE TABLE TM_FP2020
        (
		  DAT_ID		CHAR(8)
		, ITEM_CD		NVARCHAR(10)
		, PLAN_QTY		DECIMAL(18, 0)
		, DMND_REQ_QTY  DECIMAL(18, 0)
		, SP_REQ_QTY    DECIMAL(18, 0)
		, SD_REQ_QTY    DECIMAL(18, 0)
		, EOH_QTY		DECIMAL(18, 0)
		, MAX_STK_LVL   DECIMAL(18, 0)
		, MIN_STK_LVL   DECIMAL(18, 0)
		);
	END;

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



	IF OBJECT_ID('tempdb..#TM_PSI') IS NOT NULL DROP TABLE #TM_PSI -- 임시테이블 삭제

        SELECT  DISTINCT A.ITEM_CD
		     ,  A.BOH_QTY
			 ,  A.DAT_ID
		     ,  ISNULL(B.DMND_REQ_QTY,0) AS DMND_REQ_QTY
			 ,  ISNULL(D.SP_REQ_QTY,0) AS SP_REQ_QTY
			 ,  ISNULL(C.PLAN_QTY,0) AS PLAN_QTY
			 ,  ISNULL(A.BOH_QTY,0) + SUM(ISNULL(C.PLAN_QTY,0) - ISNULL(B.DMND_REQ_QTY,0) - ISNULL(D.SP_REQ_QTY,0)) OVER(PARTITION BY A.ITEM_CD ORDER BY A.DAT_ID) AS EOH_QTY
          INTO  #TM_PSI
		  FROM  #TM_MES  A
		  LEFT  OUTER JOIN  
		     (  
			  SELECT PRDT_REQ_DTE, SUM(PRDT_REQ_QTY) AS DMND_REQ_QTY
			    FROM 
			       (    /*MOLTEN 판매 필요량*/
				        SELECT  PRDT_REQ_DTE, PRDT_REQ_QTY AS PRDT_REQ_QTY  
						  FROM  TB_SKC_FP_RS_PRDT_REQ_DM A
						 WHERE  1=1
						   AND  ATTR_01   NOT IN ( 'DMCD','CHDM')
						   AND  VER_ID    =  @P_FP_VERSION
						   AND  EXISTS ( SELECT  1 FROM TB_CM_ITEM_MST X 
										  WHERE  X.ITEM_TP_ID = 'GFRT' 
											AND  X.ATTR_10 IN ('27-A0310B3130C0850')
					 						AND  A.ITEM_CD = X.ITEM_CD)
                        
						  UNION  ALL
						 /*F/B 용 DEMAND 생산계획*/
						 SELECT  PLAN_DTE, ADJ_PLAN_QTY				   
						   FROM  TB_SKC_FP_RS_PRDT_PLAN_DM A
						  WHERE  1=1
						    AND  VER_ID    =  @P_FP_VERSION
						    AND  EXISTS ( SELECT  1 FROM TB_CM_ITEM_MST X 
										   WHERE  X.ITEM_TP_ID = 'GFRT' 
											 AND  X.ATTR_10 IN ('27-A0310B3110C0830', '27-A0310B3120C0840') 
					 						 AND A.ITEM_CD = X.ITEM_CD)
							AND  PLAN_TYPE_CD = 'DMND'
                  )  A
              GROUP  BY PRDT_REQ_DTE

			 ) B 
			ON  1=1
           AND  A.DAT_ID  = B.PRDT_REQ_DTE
		  LEFT  OUTER JOIN  
		     (  SELECT   PLAN_DTE, SUM(ADJ_PLAN_QTY) AS PLAN_QTY
                  FROM  TB_SKC_FP_RS_PRDT_PLAN_DM
                 WHERE  1=1
                   AND  VER_ID    = @P_FP_VERSION
				   AND  PLAN_TYPE_CD = 'PRDT'
                 GROUP  BY PLAN_DTE
			 )  C
			ON  1=1
           AND  A.DAT_ID  = C.PLAN_DTE
		  LEFT  OUTER JOIN  
		     (  SELECT  PRDT_REQ_DTE, SUM(PRDT_REQ_QTY) AS SP_REQ_QTY  
				  FROM  TB_SKC_FP_RS_PRDT_REQ_DM A
				 WHERE  1=1
				   AND  VER_ID    =  @P_FP_VERSION
				   AND  ATTR_01   IN ( 'DMCD','CHDM')
                 GROUP  BY PRDT_REQ_DTE
			 )  D
			ON  1=1
           AND  A.DAT_ID  = D.PRDT_REQ_DTE
		 WHERE  A.MEASURE_CD  = '06'

		 


	IF OBJECT_ID('tempdb..#STK_LVL') IS NOT NULL DROP TABLE #STK_LVL -- 임시테이블 삭제


		 SELECT CALD_DATE_ID, MIN_STK_LVL*1000 AS MIN_STK_LVL, MAX_STK_LVL*1000 AS MAX_STK_LVL
		   INTO #STK_LVL
		   FROM TB_SKC_FP_SFG_STK_LVL A
		  WHERE EXISTS ( SELECT 1 FROM TB_SKC_FP_RSRC_MST   B
		                  WHERE  A.CORP_CD = B.CORP_CD
						    AND  A.PLNT_CD = B.PLNT_CD
						    AND  A.RSRC_CD = B.RSRC_CD
							AND  B.ATTR_01 = '27'
                       ) 


	IF OBJECT_ID('tempdb..#SD_QTY') IS NOT NULL DROP TABLE #SD_QTY -- 임시테이블 삭제


	     SELECT  IIF(PRDT_REQ_DTE<@PLAN_STR_DTE,@PLAN_STR_DTE,PRDT_REQ_DTE) AS SD_REQ_DTE , SUM(PRDT_REQ_QTY*1000) AS SD_REQ_QTY 
		   INTO  #SD_QTY
		   FROM  TB_SKC_FP_RS_PRDT_REQ_DM A
	      WHERE  1=1
		    AND  DMND_TYPE = 'SD'
			AND  VER_ID    =  @P_FP_VERSION
		    AND  EXISTS ( SELECT 1 FROM TB_CM_ITEM_MST   B
		                   WHERE  A.ITEM_CD = B.ITEM_CD
							 AND  B.ATTR_04 = '27'
                        ) 
	      GROUP  BY  IIF(PRDT_REQ_DTE<@PLAN_STR_DTE,@PLAN_STR_DTE,PRDT_REQ_DTE)



		INSERT TM_FP2020
			SELECT DAT_ID
		     	 , ITEM_CD
		     	 , PLAN_QTY
		     	 , DMND_REQ_QTY
		     	 , SP_REQ_QTY
		     	 , SD_REQ_QTY
				 , EOH_QTY
		     	 , MAX_STK_LVL
		     	 , MIN_STK_LVL
		      FROM #TM_PSI A
		      LEFT JOIN #SD_QTY B
		        ON A.DAT_ID = B.SD_REQ_DTE
		      LEFT JOIN #STK_LVL C
		        ON A.DAT_ID = C.CALD_DATE_ID;

END;
GO
