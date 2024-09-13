USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP1080_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP1080_Q1] (
     @P_CP_VERSION            NVARCHAR(100)    = NULL    /* COPOLY FP Version*/  
   , @P_CH_VERSION			  NVARCHAR(100)	   = NULL    /* CHDM   FP Version*/  
   , @P_DM_VERSION			  NVARCHAR(100)	   = NULL    /* DMT    FP Version*/  
   , @P_ITEM_GRP	          NVARCHAR(100)    = NULL    -- 제품군
   , @P_PRDT_GRADE_CD         NVARCHAR(100)    = NULL    -- 생산 GRADE
   , @P_SUM					  NVARCHAR(2)	   = 'Y'     -- 제품군 합계
   , @P_USER_ID               NVARCHAR(100)    = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)    = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP1080_Q1
-- COPYRIGHT       : ZIONEX
-- REMARK          : 생산계획 VS. 재고 Balance
--                   Copoly, CHDM, DMT 간의 재고 Balance를 일원화해서 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-10  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP1080_Q1' ORDER BY LOG_DTTM DESC


EXEC 
EXEC SP_SKC_UI_FP1080_Q1'FP-20240816-CO-04','FP-20240816-CH-02','FP-20240816-DM-01','ALL','580','N','I23671','UI_FP1080'
EXEC SP_SKC_UI_FP1080_Q1 'FP-20240625-CO-01','ALL','','N','I23768','UI_FP1080'
SELECT* FROM TB_SKC_FP_PRDT_gRADE_MST
 WHERE PRDT_gRADE_CD = '580'
 */
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_CP_VERSION        ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CH_VERSION        ), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_DM_VERSION        ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_GRP          ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_GRADE_CD     ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_SUM               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID               ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID               ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------


BEGIN

    DECLARE @V_MP_VERSION_ID    NVARCHAR(100)
          , @V_BOH_YYYYMMDD_CP  NVARCHAR(10)
          , @V_FR_YYYYMMMO_CP   NVARCHAR(10)
          , @V_FR_YYYYMMDD_CP   NVARCHAR(10)
          , @V_TO_YYYYMMDD_CP   NVARCHAR(10)
          , @V_BOH_YYYYMMDD_CH  NVARCHAR(10)
          , @V_FR_YYYYMMMO_CH   NVARCHAR(10)
          , @V_FR_YYYYMMDD_CH   NVARCHAR(10)
          , @V_TO_YYYYMMDD_CH   NVARCHAR(10)
          , @V_BOH_YYYYMMDD_DM  NVARCHAR(10)
          , @V_FR_YYYYMMMO_DM   NVARCHAR(10)
          , @V_FR_YYYYMMDD_DM   NVARCHAR(10)
          , @V_TO_YYYYMMDD_DM   NVARCHAR(10)

    -----------------------------------
    -- #TM_ITEM_GRP_CD
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_ITEM_GRP_CD') IS NOT NULL DROP TABLE #TM_ITEM_GRP_CD -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_ITEM_GRP_CD
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_ITEM_GRP),''),'|')

    -----------------------------------
    -- #TM_PRDT_GRADE_CD
    -----------------------------------
        IF OBJECT_ID('tempdb..#TM_PRDT_GRADE_CD') IS NOT NULL DROP TABLE #TM_PRDT_GRADE_CD -- 임시테이블 삭제

        SELECT Value VAL
          INTO #TM_PRDT_GRADE_CD
          FROM SplitTableNVARCHAR(ISNULL(UPPER(@P_PRDT_GRADE_CD),''),'|')

    -----------------------------------
    -- 기간
    -----------------------------------
        SELECT DISTINCT @V_MP_VERSION_ID      = PRE_VER_ID
             , @V_BOH_YYYYMMDD_CP    = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_FR_YYYYMMDD_CP     = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_TO_YYYYMMDD_CP     = CONVERT(NVARCHAR(8), TO_DT  , 112)
          FROM VW_FP_PLAN_VERSION
         WHERE VERSION =  @P_CP_VERSION;

		SELECT  @V_FR_YYYYMMMO_CP =  MIN(DAT_ID) 
		  FROM  TB_CM_CALENDAR
         WHERE  PARTWK = ( SELECT  MIN(PARTWK) FROM  TB_CM_CALENDAR WHERE  DAT_ID = @V_FR_YYYYMMDD_CP)



        SELECT @V_BOH_YYYYMMDD_CH    = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_FR_YYYYMMDD_CH     = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_TO_YYYYMMDD_CH     = CONVERT(NVARCHAR(8), TO_DT  , 112)
          FROM VW_FP_PLAN_VERSION
         WHERE VERSION =  @P_CH_VERSION;

		SELECT  @V_FR_YYYYMMMO_CH =  MIN(DAT_ID) 
		  FROM  TB_CM_CALENDAR
         WHERE  PARTWK = ( SELECT  MIN(PARTWK) FROM  TB_CM_CALENDAR WHERE  DAT_ID = @V_FR_YYYYMMDD_CH)



        SELECT @V_BOH_YYYYMMDD_DM    = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_FR_YYYYMMDD_DM     = CONVERT(NVARCHAR(8), PLAN_DT, 112)
             , @V_TO_YYYYMMDD_DM     = CONVERT(NVARCHAR(8), TO_DT  , 112)
          FROM VW_FP_PLAN_VERSION
         WHERE VERSION =  @P_DM_VERSION;

		SELECT  @V_FR_YYYYMMMO_DM =  MIN(DAT_ID) 
		  FROM  TB_CM_CALENDAR
         WHERE  PARTWK = ( SELECT  MIN(PARTWK) FROM  TB_CM_CALENDAR WHERE  DAT_ID = @V_FR_YYYYMMDD_DM)




    -----------------------------------
    -- 대상
    -----------------------------------
	IF OBJECT_ID('tempdb..#TM_TGT') IS NOT NULL DROP TABLE #TM_TGT -- 임시테이블 삭제
		SELECT DISTINCT  
		       CASE WHEN B.ATTR_04 IN ('11') THEN @P_CP_VERSION
			        WHEN B.ATTR_04 IN ('12') THEN @P_CH_VERSION
					WHEN B.ATTR_04 IN ('27') THEN @P_DM_VERSION
                END AS VER_ID
		     , ATTR_04 AS ITEM_GRP
			 , ISNULL(PRDT_GRADE_CD, B.ATTR_10) AS PRDT_GRADE_CD
			 , ITEM_CD
		  INTO #TM_TGT
		  FROM TB_CM_ITEM_MST B 
		 WHERE 1=1
		   AND   B.ATTR_04	  IN ('11','12','27')
		   AND   B.ITEM_TP_ID = 'GFRT'
		  -- AND   'Y' = IIF(B.ATTR_04 = '11', IIF(B.ATTR_14 = '010','Y','N'),'Y')  /*COPOLY 일때 정상*/
		   AND ( B.ATTR_04 IN (SELECT VAL FROM #TM_ITEM_GRP_CD)  OR ISNULL( @P_ITEM_GRP, 'ALL') = 'ALL' )
		   AND ( B.PRDT_GRADE_CD IN (SELECT VAL FROM #TM_PRDT_GRADE_CD)  OR ISNULL( @P_PRDT_GRADE_CD, 'ALL') = 'ALL' )
--         UNION  
--		SELECT ITEM_CD
--		  FROM TB_SKC_FP_RS_PRDT_PLAN_CO  
--	     WHERE VER_ID = @P_CP_VERSION
--	       AND ADJ_PLAN_QTY > 0 
--         UNION  
--        SELECT   A.ITEM_CD                                AS ITEM_CD					     
--          FROM  TB_SKC_MP_REQ_PLAN     A WITH (NOLOCK)				  
--         INNER  JOIN  VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
--            ON  C.LOCAT_CD = A.TO_LOCAT_CD
--         INNER  JOIN  VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
--            ON  D.ITEM_CD  = A.ITEM_CD
--           AND  D.LOCAT_CD = C.LOCAT_CD
--         WHERE  1 = 1  
--           AND  A.MP_VERSION_ID = @V_MP_VERSION_ID       	 
--           AND  A.REQ_QTY       > 0
--           AND  A.DMND_TP       = 'C'             -- 다음 생산 공정에 연계되는 종속 Demand		
--           AND  A.CNSG_YN       = 'Y'             -- 사급 자재 여부
--           AND  D.ITEM_TP       = 'GFRT'        
--           AND  (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')	
		
---------------------------------------------------------------------------
--         UNION  
---------------------------------------------------------------------------
--        -- 출하필요량 (완제품)
--        SELECT  A.ITEM_CD                                AS ITEM_CD
--		  FROM  TB_SKC_MP_REQ_PLAN A WITH (NOLOCK)
--         INNER  JOIN TB_DP_ACCOUNT_MST B   WITH (NOLOCK)
--			ON  A.ACCOUNT_ID  = B.ID 
--		   AND  B.ACTV_YN       = 'Y'
--         WHERE  1 = 1          	       	  
--           AND  A.MP_VERSION_ID =  @V_MP_VERSION_ID       	 
--           AND  A.SHNG_QTY      > 0
--		   AND  EXISTS( SELECT 1 FROM TB_CM_ITEM_MST X WHERE A.ITEM_CD = X.ITEM_CD AND  X.ITEM_tP_ID = 'GFRT')
--           AND  A.DMND_TP       = 'D'             -- 최종 독립 Demand
--           AND  EXISTS (SELECT 1 FROM VW_LOCAT_DTS_INFO C  WITH (NOLOCK) WHERE  A.TO_LOCAT_CD = C.LOCAT_CD AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y'))


	   ;


		---- CHDM
		-- UNION ALL
		--SELECT DISTINCT A.ITEM_CD  
		--  FROM TB_SKC_FP_RS_PRDT_PLAN_CH A
		-- INNER JOIN TB_CM_ITEM_MST B
		--	ON A.ITEM_CD = B.ITEM_CD
		-- WHERE VER_ID = @P_CH_VERSION
		---- DMT
 	--	 UNION ALL
		--SELECT DISTINCT A.ITEM_CD  
		--  FROM TB_SKC_FP_RS_PRDT_PLAN_DM A
		-- INNER JOIN TB_CM_ITEM_MST B
		--	ON A.ITEM_CD = B.ITEM_CD
		-- WHERE VER_ID = @P_DM_VERSION
		--   AND PLAN_TYPE_CD = 'DMND'
		--   AND B.ATTR_10 != '27-A0310B3130C0850'
		-- UNION ALL
		--SELECT DISTINCT A.ITEM_CD  
		--  FROM TB_SKC_FP_RS_PRDT_PLAN_DM A
		-- INNER JOIN TB_CM_ITEM_MST B
		--	ON A.ITEM_CD = B.ITEM_CD
		-- WHERE VER_ID = @P_DM_VERSION
		--   AND PLAN_TYPE_CD = 'PRDT'
		--   AND B.ATTR_10 = '27-A0310B3130C0850' -- MOLTEN		

   -----------------------------------
    -- 출하실적 : 버전의 FROM MM (주초) ~ 버전의 FROM DATE -1일  (실적은 계획 시작일 이전)
    -- 출하필요량 (계획) : 버전의 FROM DATE ~ 버전의 TO DATE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_SHMT') IS NOT NULL DROP TABLE #TM_SHMT -- 임시테이블 삭제

        SELECT PARTWK                AS PARTWK
			 , PLAN_DTE				 AS PLAN_DTE
             , ITEM_GRP              AS ITEM_GRP
			 , PRDT_GRADE_CD		 AS PRDT_GRADE_CD
             , SUM(SHMT_QTY    )     AS SHMT_QTY
			 , 0					 AS MP_PLAN_QTY
          INTO #TM_SHMT
          FROM (
                  -- 출하실적
                  SELECT CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112)      AS PLAN_DTE
                       , Z.ITEM_GRP                                     AS ITEM_GRP
					   , Z.PRDT_GRADE_CD								AS PRDT_GRADE_CD
                       , ROUND(SUM(X.SHMT_QTY)/1000, 3)                 AS SHMT_QTY
                    FROM TB_SKC_CM_ACT_SHMT X
					   , #TM_TGT Z
                   WHERE 1=1
					 AND X.ITEM_CD = Z.ITEM_CD
                     AND CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112) BETWEEN @V_FR_YYYYMMMO_CP AND CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @V_FR_YYYYMMDD_CP), 112)
                     AND SHMT_QTY > 0
				   GROUP BY CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112), Z.ITEM_GRP, Z.PRDT_GRADE_CD
               ) A
             , TB_CM_CALENDAR C
         WHERE C.YYYYMMDD BETWEEN @V_FR_YYYYMMMO_CP AND @V_TO_YYYYMMDD_CP
           AND A.PLAN_DTE = C.YYYYMMDD
         GROUP BY PARTWK
		     , PLAN_DTE
             , ITEM_GRP
			 , PRDT_GRADE_CD

   -----------------------------------
   -- REQ_PLAN 임시 테이블
   -----------------------------------	
	--IF OBJECT_ID('tempdb..#TM_REQ_PLAN') IS NOT NULL DROP TABLE #TM_REQ_PLAN -- 임시테이블 삭제
	--	SELECT  SHNG_DATE
	--		 ,  SHNG_QTY
	--		 ,  B.LOCAT_CD
	--		 ,  ACCOUNT_ID
	--		 ,  A.ITEM_CD
	--		 ,  T.ITEM_GRP
	--		 ,  T.PRDT_GRADE_CD
	--		 ,  MP_VERSION_ID
	--		 ,  DMND_TP
	--		 ,  TO_LOCAT_CD
	--		 ,  REQ_QTY
	--		 ,  CNSG_YN
	--	  INTO  #TM_REQ_PLAN
	--	  FROM  TB_SKC_MP_REQ_PLAN A
	--	 INNER  JOIN #TM_TGT T
	--	    ON  A.ITEM_CD     = T.ITEM_CD
	--	 INNER  JOIN  VW_LOCAT_DTS_INFO B WITH (NOLOCK)
 --           ON  B.LOCAT_CD    = A.TO_LOCAT_CD
	--	 WHERE  MP_VERSION_ID = @V_MP_VERSION_ID
	--	   AND  (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')	;

	IF OBJECT_ID('tempdb..#TM_REQ_PLAN') IS NOT NULL DROP TABLE #TM_REQ_PLAN;
		SELECT  SHNG_DATE		   AS BASE_YYYYMMDD
			 ,  ITEM_GRP
			 ,  PRDT_GRADE_CD
			 ,  SUM(PLAN_QTY)/1000 AS PLAN_QTY
		  INTO  #TM_REQ_PLAN
		  FROM  (SELECT  SHNG_DATE
			    	  ,  T.ITEM_GRP
			    	  ,  T.PRDT_GRADE_CD
			    	  ,  CASE WHEN DMND_TP = 'C' AND CNSG_YN = 'Y' THEN REQ_QTY
			    	  		  WHEN DMND_TP = 'D'				   THEN SHNG_QTY END AS PLAN_QTY
				   FROM  TB_SKC_MP_REQ_PLAN A
				  INNER  JOIN #TM_TGT T
					 ON  A.ITEM_CD     = T.ITEM_CD
				  INNER  JOIN  VW_LOCAT_DTS_INFO B WITH (NOLOCK)
					 ON  B.LOCAT_CD    = A.TO_LOCAT_CD
				  WHERE  MP_VERSION_ID = @V_MP_VERSION_ID
					AND  (B.CUST_SHPP_YN = 'Y' OR B.PRDT_YN = 'Y')	
					AND  (A.REQ_QTY       > 0  OR A.SHNG_QTY > 0)
				 ) A
	     GROUP  BY SHNG_DATE, ITEM_GRP, PRDT_GRADE_CD

    -----------------------------------
    -- 출하필요량 (COPOLY) : 버전의 FROM DATE ~ 버전의 TO DATE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MP_PLAN') IS NOT NULL DROP TABLE #TM_MP_PLAN -- 임시테이블 삭제

		--SELECT X.SHNG_DATE AS PLAN_DTE
		--	 , CAL.PARTWK AS PARTWK
		--	 , Y.ATTR_04 AS ITEM_GRP 
		--	 , COALESCE(Y.PRDT_GRADE_CD, Y.ATTR_10) AS PRDT_GRADE_CD
		--	 , 0 AS SHMT_QTY
		--	 , SUM(X.GROSS_QTY/1000) AS MP_PLAN_QTY 
		--  INTO #TM_MP_PLAN
		--  FROM TB_SKC_MP_REQ_PLAN X WITH (NOLOCK)					  
		-- INNER JOIN TB_CM_ITEM_MST Y WITH (NOLOCK)
		--	ON X.ITEM_CD = Y.ITEM_CD
		-- INNER JOIN #TM_TGT Z
		--    ON X.ITEM_CD = Z.ITEM_CD 
  --       INNER JOIN TB_CM_CALENDAR CAL
		--    ON X.SHNG_DATE = CAL.DAT_ID 
  --       INNER JOIN VW_LOCAT_INFO LCI
		--    ON X.TO_LOCAT_CD = LCI.LOCAT_CD 
  --       WHERE 1 = 1          	       	  
  --         AND X.MP_VERSION_ID     = @V_MP_VERSION_ID       	    	    
  --         AND X.GROSS_QTY          > 0
		--   AND Y.ATTR_04 = '11'		
		--   AND X.DMND_ID NOT LIKE 'SFST%'
  --         AND 'Y' = CASE WHEN DMND_TP = 'D' THEN IIF(LCI.LOCAT_CD IN ( 'CDC-UL-UL','RDC-UL-CY'),'Y','N')
		--                  WHEN DMND_TP = 'C' THEN IIF(LCI.LOCAT_CD IN ( 'FG-UL-1110'),'Y','N')
		--				  ELSE 'N'
  --                   END
		--   AND ( Y.ATTR_04 IN (SELECT VAL FROM #TM_ITEM_GRP_CD)  OR ISNULL( @P_ITEM_GRP, 'ALL') = 'ALL' )
		--   AND (ISNULL(Y.PRDT_GRADE_CD,Y.ATTR_10) IN (SELECT VAL FROM #TM_PRDT_GRADE_CD)  OR ISNULL( @P_PRDT_GRADE_CD, 'ALL') = 'ALL' )
		-- GROUP BY X.SHNG_DATE, CAL.PARTWK, Y.ATTR_04, COALESCE(Y.PRDT_GRADE_CD, Y.ATTR_10)



		SELECT A.PLAN_DTE
			 , A.PARTWK
			 , A.ITEM_GRP 
			 , A.PRDT_GRADE_CD
			 , 0 AS SHMT_QTY
			 , dbo.FN_G_GREATEST(A.MP_PLAN_QTY-COALESCE(B.SHMT_QTY, 0), 0) AS MP_PLAN_QTY
		  INTO  #TM_MP_PLAN
		  FROM (
		  SELECT  A.BASE_YYYYMMDD                                  AS PLAN_DTE
			   ,  CAL.PARTWK                                       AS PARTWK
			   ,  ITEM_GRP		                                   AS ITEM_GRP 
			   ,  A.PRDT_GRADE_CD								   AS PRDT_GRADE_CD
			   ,  0                                                AS SHMT_QTY
			   ,  SUM(A.PLAN_QTY)                                  AS MP_PLAN_QTY             
		    FROM #TM_REQ_PLAN A
--			   ( -- 출하필요량 (사급자재)
--                  SELECT  A.SHNG_DATE                              AS BASE_YYYYMMDD  
--				       ,  '1000'                                   AS CORP_CD
--					   ,  A.ITEM_GRP							   AS ITEM_GRP
--				       ,  A.PRDT_GRADE_CD					       AS PRDT_GRADE_CD						     
--                       ,  0                                        AS SHMT_QTY
--                       ,  SUM(A.REQ_QTY)  /1000                    AS PLAN_QTY  
--					FROM  #TM_REQ_PLAN A WITH (NOLOCK)	  
--                   --INNER  JOIN  VW_LOCAT_DTS_INFO      C WITH (NOLOCK)
--                   --   ON  C.LOCAT_CD = A.TO_LOCAT_CD
--                   INNER  JOIN  VW_LOCAT_ITEM_DTS_INFO D WITH (NOLOCK)
--                      ON  D.ITEM_CD  = A.ITEM_CD
--                     AND  D.LOCAT_CD = A.LOCAT_CD
--                   WHERE  1 = 1  
--                     AND  A.MP_VERSION_ID = @V_MP_VERSION_ID       	 
--                     AND  A.REQ_QTY       > 0
--                     AND  A.DMND_TP       = 'C'             -- 다음 생산 공정에 연계되는 종속 Demand		
--                     AND  A.CNSG_YN       = 'Y'             -- 사급 자재 여부
--                     AND  D.ITEM_TP       = 'GFRT'        
--                     --AND  (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y')	
--				   GROUP  BY A.SHNG_DATE, A.PRDT_GRADE_CD, A.ITEM_GRP
---------------------------------------------------------------------------
--					UNION  ALL
---------------------------------------------------------------------------
--                   -- 출하필요량 (완제품)
--                   SELECT  A.SHNG_DATE                              AS BASE_YYYYMMDD
--				        ,  B.ATTR_01                                AS CORP_CD
--						,  A.ITEM_GRP								AS ITEM_GRP
--				        ,  A.PRDT_GRADE_CD					        AS PRDT_GRADE_CD
--						,  0                                        AS SHMT_QTY
--                        ,  SUM(A.SHNG_QTY)   /1000                  AS PLAN_QT 
--					 FROM  #TM_REQ_PLAN A WITH (NOLOCK)
--                    INNER  JOIN TB_DP_ACCOUNT_MST B   WITH (NOLOCK)
--					   ON  A.ACCOUNT_ID    = B.ID 
--					  AND  B.ACTV_YN       = 'Y'
--                    WHERE  1 = 1          	       	  
--                      AND  A.MP_VERSION_ID = @V_MP_VERSION_ID       	 
--                      AND  A.SHNG_QTY      > 0
--                      AND  A.DMND_TP       = 'D'             -- 최종 독립 Demand
--                      --AND  EXISTS (SELECT 1 FROM VW_LOCAT_DTS_INFO C  WITH (NOLOCK) WHERE  A.TO_LOCAT_CD = C.LOCAT_CD AND (C.CUST_SHPP_YN = 'Y' OR C.PRDT_YN = 'Y'))
--					GROUP  BY A.SHNG_DATE, B.ATTR_01, A.ITEM_GRP, A.PRDT_GRADE_CD
--               )  A
           INNER  JOIN TB_CM_CALENDAR CAL
              ON  A.BASE_YYYYMMDD = CAL.DAT_ID 
           GROUP  BY A.BASE_YYYYMMDD,  CAL.PARTWK, ITEM_GRP, A.PRDT_GRADE_CD
		   ) A       
		   LEFT  JOIN #TM_SHMT B
		     ON  A.PLAN_DTE      = B.PLAN_DTE
			AND  A.ITEM_GRP      = B.ITEM_GRP
			AND  A.PRDT_GRADE_CD = B.PRDT_GRADE_CD    





    -----------------------------------
    -- 외부 판매량 (CHDM/DMT) 
	-- CHDM: TB_SKC_FP_RS_PRDT_REQ_CH WHERE DMND_TYPE = 'MP' / PACK_REQ_QTY
	-- DMT : TB_SKC_FP_RS_PRDT_REQ_DM / PACK_REQ_QTY	
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_REQ_PACK') IS NOT NULL DROP TABLE #TM_REQ_PACK -- 임시테이블 삭제
	   SELECT MAX(X.PACK_REQ_DTE)					AS PLAN_DTE
			, Z2.PARTWK								AS PARTWK
			, Z.ITEM_GRP							AS ITEM_GRP
			, Z.PRDT_GRADE_CD						AS PRDT_GRADE_CD
			, 0										AS SHMT_QTY
			, SUM(X.PACK_REQ_QTY)/1000				AS REQ_PACK_QTY
		 INTO #TM_REQ_PACK
 		 FROM TB_SKC_FP_RS_PRDT_REQ_CH     X
			, #TM_TGT Z
			, TB_CM_CALENDAR Z2
		WHERE X.VER_ID         = @P_CH_VERSION
		  AND X.ITEM_CD		   = Z.ITEM_CD
		  AND X.PRDT_REQ_QTY   > 0
		  AND X.PACK_REQ_DTE   = Z2.DAT
		  AND Z.ITEM_GRP	   = '12'
		  AND X.DMND_TYPE	   = 'MP'
		  AND X.PACK_REQ_DTE   >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
		GROUP BY Z2.PARTWK, Z.ITEM_GRP, Z.PRDT_GRADE_CD
		UNION ALL
	   SELECT MAX(X.GI_REQ_DTE)					AS PLAN_DTE
			, Z2.PARTWK							AS PARTWK
			, Y.ITEM_GRP						AS ITEM_GRP
			, Y.PRDT_GRADE_CD					AS PRDT_GRADE_CD
			, 0									AS SHMT_QTY
			, SUM(X.GI_REQ_QTY)/1000			AS REQ_PACK_QTY
 		 FROM TB_SKC_FP_RS_PACK_REQ_DM     X
			, #TM_TGT Y
			, TB_CM_CALENDAR Z2
		WHERE X.VER_ID        = @P_DM_VERSION
		  AND X.ITEM_CD       = Y.ITEM_CD
		  AND X.GI_REQ_DTE    = Z2.DAT
		  AND Y.ITEM_GRP		  = '27'
		  AND Y.PRDT_GRADE_CD	  IN ('27-A0310B3110C0830', '27-A0310B3120C0840', '27-A0310B3130C0850') 		  
		  AND X.GI_REQ_DTE    >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
		GROUP BY Z2.PARTWK, Y.ITEM_GRP, Y.PRDT_GRADE_CD
		--UNION ALL
	 --  SELECT MAX(X.PACK_REQ_DTE)					AS PLAN_DTE
		--	, Z2.PARTWK								AS PARTWK
		--	, Y.ATTR_04								AS ITEM_GRP
		--	, ISNULL(Y.PRDT_GRADE_CD, Y.ATTR_10)	AS PRDT_GRADE_CD
		--	, 0										AS SHMT_QTY
		--	, SUM(X.PACK_REQ_QTY)/1000				AS REQ_PACK_QTY
 	--	 FROM TB_SKC_FP_RS_PRDT_REQ_DM     X
		--	, TB_CM_ITEM_MST Y
		--	, #TM_TGT Z
		--	, TB_CM_CALENDAR Z2
		--WHERE X.VER_ID         = @P_DM_VERSION
		--  AND X.ITEM_CD        = Y.ITEM_CD
		--  AND X.ITEM_CD		   = Z.ITEM_CD
		--  AND X.PRDT_REQ_QTY   > 0
		--  AND X.PACK_REQ_DTE   = Z2.DAT
		--  AND Y.ATTR_04		   = '27'
		--  AND X.PACK_REQ_DTE   >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
		--  AND ( Y.ATTR_04 IN (SELECT VAL FROM #TM_ITEM_GRP_CD)  OR ISNULL( @P_ITEM_GRP, 'ALL') = 'ALL' )
		--  AND (ISNULL(Z.PRDT_GRADE_CD,Y.ATTR_10) IN (SELECT VAL FROM #TM_PRDT_GRADE_CD)  OR ISNULL( @P_PRDT_GRADE_CD, 'ALL') = 'ALL' )
		--GROUP BY Z2.PARTWK, Y.ATTR_04, ISNULL(Y.PRDT_GRADE_CD, Y.ATTR_10)		
		
    -----------------------------------
    -- 자사 투입량 (CHDM/DMT) 
	-- CHDM: TB_SKC_FP_RS_PRDT_REQ_CH WHERE DMND_TYPE = 'CNSM' / PRDT_REQ_QTY
	-- DMT:  TB_SKC_FP_RS_PRDT_PLAN_DM WHERE PLAN_TYPE_CD = 'SP' / PRDT_REQ_QTY (MOLTEN만 구성)
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_REQ_PRDT') IS NOT NULL DROP TABLE #TM_REQ_PRDT -- 임시테이블 삭제
	   SELECT A.PLAN_DTE						 AS PLAN_DTE		  
			, PARTWK
			, C.ITEM_GRP						 AS ITEM_GRP
			, C.PRDT_GRADE_CD					 AS PRDT_GRADE_CD
			, 0 AS SHMT_QTY
			, SUM(ISNULL(B.CNSM_REQ_QTY/1000,0)) AS REQ_PRDT_QTY
		INTO #TM_REQ_PRDT
		FROM 
		(
			 SELECT * FROM
			( SELECT  RSRC_CD, RSRC_NM 
			    FROM  TB_SKC_FP_RSRC_MST
			   WHERE  PLNT_CD IN ('1110', '1230')
				 AND  RSRC_CD    != 'SSP20'
				 AND  SCM_USE_YN = 'Y'
				 AND  ATTR_01    = '11'
			) A
			 CROSS JOIN 
			 (
				SELECT  DAT_ID AS PLAN_DTE 
					 ,  PARTWK
				  FROM  TB_CM_CALENDAR
				 WHERE  DAT_ID >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
				   AND  DAT_ID <= @V_TO_YYYYMMDD_CH
			 ) B
		) A
		LEFT JOIN
		(
			SELECT * 
			FROM TB_SKC_FP_RS_LINE_REQ_CH
			WHERE VER_ID = @P_CH_VERSION
		) B
		ON A.RSRC_CD = B.RSRC_CD
		AND A.PLAN_DTE = B.PRDT_REQ_DTE
		INNER JOIN #TM_TGT C
		   ON B.CNSM_ITEM_CD = C.ITEM_CD
		GROUP BY A.PLAN_DTE, PARTWK, C.ITEM_GRP, C.PRDT_GRADE_CD
		UNION  ALL
	   SELECT  MAX(X.PLAN_DTE)						AS PLAN_DTE
			,  Z2.PARTWK							AS PARTWK
			,  Z.ITEM_GRP							AS ITEM_GRP
			,  Z.PRDT_GRADE_CD						AS PRDT_GRADE_CD
			,  0									AS SHMT_QTY
			,  SUM(X.ADJ_PLAN_QTY)/1000				AS REQ_PRDT_QTY
 		 FROM  TB_SKC_FP_RS_PRDT_PLAN_DM     X
			,  #TM_TGT Z
			,  TB_CM_CALENDAR Z2
		WHERE  X.VER_ID		   = @P_DM_VERSION
		  AND  X.ITEM_CD		   = Z.ITEM_CD
		  AND  X.ADJ_PLAN_QTY   > 0
		  AND  X.PLAN_DTE       = Z2.DAT
		  AND  Z.ITEM_GRP	   = '27'
		  AND  X.PLAN_TYPE_CD   = 'SP'
		  AND  Z.PRDT_GRADE_CD  = '27-A0310B3130C0850'
		  AND  X.PLAN_DTE       >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
		GROUP  BY Z2.PARTWK, Z.ITEM_GRP, Z.PRDT_GRADE_CD
		
    -------------------------------------
    ---- 출하실적 : 버전의 FROM MM (주초) ~ 버전의 FROM DATE -1일  (실적은 계획 시작일 이전)
    ---- 출하필요량 (계획) : 버전의 FROM DATE ~ 버전의 TO DATE
    -------------------------------------
    --IF OBJECT_ID('tempdb..#TM_SHMT') IS NOT NULL DROP TABLE #TM_SHMT -- 임시테이블 삭제

    --    SELECT PARTWK                AS PARTWK
			 --, PLAN_DTE				 AS PLAN_DTE
    --         , ITEM_GRP              AS ITEM_GRP
			 --, PRDT_GRADE_CD		 AS PRDT_GRADE_CD
    --         , SUM(SHMT_QTY    )     AS SHMT_QTY
    --         , SUM(MP_PLAN_QTY )     AS MP_PLAN_QTY
    --      INTO #TM_SHMT
    --      FROM (
    --              -- 출하실적
    --              SELECT CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112)      AS PLAN_DTE
    --                   , Y.ATTR_04                                      AS ITEM_GRP
				--	   , ISNULL(Y.PRDT_GRADE_CD,Y.ATTR_10)				AS PRDT_GRADE_CD
    --                   , ROUND(SUM(X.SHMT_QTY)/1000, 3)                 AS SHMT_QTY
    --                   , 0                                              AS MP_PLAN_QTY
    --                FROM TB_SKC_CM_ACT_SHMT X
				--	   , TB_CM_ITEM_MST Y
				--	   , #TM_TGT Z
    --               WHERE 1=1
				--     AND X.ITEM_CD = Y.ITEM_CD
				--	 AND X.ITEM_CD = Z.ITEM_CD
				--	 AND Y.ATTR_04 IN ('11', '12', '27')
    --                 AND CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112) BETWEEN @V_FR_YYYYMMMO_CP AND CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @V_FR_YYYYMMDD_CP), 112)
    --                 AND SHMT_QTY > 0
				--	 AND ( Y.ATTR_04 IN (SELECT VAL FROM #TM_ITEM_GRP_CD)  OR ISNULL( @P_ITEM_GRP, 'ALL') = 'ALL' )
				--	 AND ( ISNULL(Z.PRDT_GRADE_CD,Y.ATTR_10) IN (SELECT VAL FROM #TM_PRDT_GRADE_CD)  OR ISNULL( @P_PRDT_GRADE_CD, 'ALL') = 'ALL' )
				--   GROUP BY CONVERT(NVARCHAR(10), X.REAL_GI_DTTM,112), Y.ATTR_04, ISNULL(Y.PRDT_GRADE_CD,Y.ATTR_10)
    --              UNION ALL
    --              -- 출하필요량 (공급계획)
    --              SELECT PLAN_DTE
    --                   , ITEM_GRP
				--	   , PRDT_GRADE_CD
    --                   , SHMT_QTY
    --                   , MP_PLAN_QTY
    --                FROM #TM_MP_PLAN
				--  UNION ALL
				--  SELECT PLAN_DTE
    --                   , ITEM_GRP
				--	   , PRDT_GRADE_CD
    --                   , SHMT_QTY
    --                   , REQ_PACK_QTY AS MP_PLAN_QTY
    --                FROM #TM_REQ_PACK
				--   UNION ALL
				--  SELECT PLAN_DTE
    --                   , ITEM_GRP
				--	   , PRDT_GRADE_CD
    --                   , SHMT_QTY
    --                   , REQ_PRDT_QTY AS MP_PLAN_QTY
    --                FROM #TM_REQ_PRDT
    --           ) A
    --         , TB_CM_CALENDAR C
    --     WHERE C.YYYYMMDD BETWEEN @V_FR_YYYYMMMO_CP AND @V_TO_YYYYMMDD_CP
    --       AND A.PLAN_DTE = C.YYYYMMDD
    --     GROUP BY PARTWK
		  --   , PLAN_DTE
    --         , ITEM_GRP
			 --, PRDT_GRADE_CD

    -----------------------------------
    -- CHDM 생산계획
    -- COPOLY 버전의 FROM DATE ~ TO DATE
    -----------------------------------	
	IF OBJECT_ID('tempdb..#TM_CH_QTY') IS NOT NULL DROP TABLE #TM_CH_QTY
        SELECT @P_CH_VERSION AS VER_ID
			 , A.PLAN_DTE
			 , B.ITEM_CD
			 , IIF(SUM(B.ADJ_PLAN_QTY) IS NULL, 0, SUM(B.ADJ_PLAN_QTY)/1000) AS FP_PLAN_QTY		
			 , IIF(SUM(B.PRDT_REQ_QTY) IS NULL, 0, SUM(B.PRDT_REQ_QTY)/1000) AS PRDT_REQ_QTY
			 , IIF(MAX(C.DMND_QTY) IS NULL, 0, MAX(C.DMND_QTY)/1000)		 AS DMND_QTY
		  INTO #TM_CH_QTY
		  FROM
		  (
		    SELECT DISTINCT RSRC_CD, A.MAX_CAPA_QTY, B.PLAN_DTE
			FROM 
			(
				SELECT  DISTINCT RSRC_CD, MAX(MAX_CAPA_QTY)/1000 AS MAX_CAPA_QTY FROM TB_SKC_FP_RS_PRDT_PLAN_CH
				 WHERE  VER_ID = @P_CH_VERSION
				 GROUP  BY VER_ID, RSRC_CD, PLAN_DTE, ITEM_CD
			) A
			CROSS JOIN 
			(
				SELECT  DAT_ID AS PLAN_DTE 
				  FROM  TB_CM_CALENDAR 
				 WHERE  DAT_ID >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
				   AND  DAT_ID <= @V_TO_YYYYMMDD_CP	
			) B
		  ) A
		  LEFT JOIN 
		  (
			SELECT A.* 
			FROM TB_SKC_FP_RS_PRDT_PLAN_CH A
			INNER JOIN TB_SKC_FP_RSRC_MST B 
			ON A.RSRC_CD = B.RSRC_CD
			WHERE  VER_ID =  @P_CH_VERSION
		  ) B
		  ON A.PLAN_DTE = B.PLAN_DTE
		  AND A.RSRC_CD = B.RSRC_CD
		  LEFT JOIN 
		  (  SELECT  PRDT_REQ_DTE
                  ,  SUM(PRDT_REQ_QTY) AS DMND_QTY FROM TB_SKC_FP_RS_PRDT_REQ_CH
              WHERE  VER_ID    = @P_CH_VERSION
			    AND  DMND_TYPE = 'MP'
              GROUP  BY PRDT_REQ_DTE
           )  C
		  ON  A.PLAN_DTE = C.PRDT_REQ_DTE
		 GROUP BY A.RSRC_CD, A.PLAN_DTE, B.ITEM_CD

    -----------------------------------
    -- DMT 생산계획
    -- COPOLY 버전의 FROM DATE ~ TO DATE
    -----------------------------------	
	IF OBJECT_ID('tempdb..#TM_DM_QTY') IS NOT NULL DROP TABLE #TM_DM_QTY
		SELECT  @P_DM_VERSION AS VER_ID
			 ,  PLAN_DTE
			 ,  ITEM_CD
			 ,  IIF(SUM(A.FP_PLAN_QTY) IS NULL, 0, SUM(A.FP_PLAN_QTY)/1000) AS FP_PLAN_QTY		
		  INTO  #TM_DM_QTY
		  FROM  (
				 SELECT  ITEM_CD, PLAN_DTE, SUM(ADJ_PLAN_QTY) AS FP_PLAN_QTY -- MOLTEN 생산
                   FROM  TB_SKC_FP_RS_PRDT_PLAN_DM
                  WHERE  1=1
                    AND  VER_ID       = @P_DM_VERSION
				    AND  PLAN_TYPE_CD = 'PRDT'
				    AND  PLAN_DTE	 >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
				  GROUP  BY ITEM_CD, PLAN_DTE
				  UNION  ALL 
			     SELECT  A.ITEM_CD, PLAN_DTE, SUM(ADJ_PLAN_QTY) AS PLAN_QTY -- BRIQUETTE/FLAKE 생산
                   FROM  TB_SKC_FP_RS_PRDT_PLAN_DM A
				  INNER  JOIN #TM_TGT B
				     ON  A.ITEM_CD	  = B.ITEM_CD
                  WHERE  1=1
				    AND  PLAN_TYPE_CD = 'DMND'
                    AND  A.VER_ID     = @P_DM_VERSION
				    AND  PLAN_DTE	 >= @V_FR_YYYYMMDD_CP -- 24.08.27 Copoly 계획 시작일 기준으로 변경
					AND  B.ITEM_GRP  IN ('27-A0310B3110C0830', '27-A0310B3120C0840') 
                  GROUP  BY A.ITEM_CD, PLAN_DTE
				 ) A
		  GROUP  BY PLAN_DTE, ITEM_CD;

    -----------------------------------
    -- 생산계획
    -- 버전의 FROM DATE ~ TO DATE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_FP_PLAN') IS NOT NULL DROP TABLE #TM_FP_PLAN -- 임시테이블 삭제
		SELECT *
		  INTO #TM_FP_PLAN
		  FROM (
					 SELECT  A.VER_ID
						  ,  PARTWK
						  ,  C.ITEM_GRP		      AS ITEM_GRP
						  ,  C.PRDT_GRADE_CD      AS PRDT_GRADE_CD
						  ,  SUM(ADJ_PLAN_QTY)	  AS FP_PLAN_QTY
					   FROM  TB_SKC_FP_RS_PRDT_PLAN_CO  A
					  INNER  JOIN TB_CM_CALENDAR B
						 ON  A.PLAN_DTE = B.DAT
					  INNER  JOIN #TM_TGT C
						 ON  A.ITEM_CD  = C.ITEM_CD
					  WHERE  A.VER_ID   = @P_CP_VERSION
					  GROUP  BY A.VER_ID, PARTWK, C.ITEM_GRP, C.PRDT_GRADE_CD
					  -- CHDM
					  UNION  ALL
					 SELECT  @P_CH_VERSION
						  ,  PARTWK
						  ,  C.ITEM_GRP			  AS ITEM_GRP
						  ,  C.PRDT_GRADE_CD	  AS PRDT_GRADE_CD
						  ,  SUM(FP_PLAN_QTY)	  AS FP_PLAN_QTY
					   FROM  #TM_CH_QTY A
					  INNER  JOIN TB_CM_CALENDAR B
					     ON  A.PLAN_DTE = B.DAT
					  INNER  JOIN #TM_TGT C
					     ON  A.ITEM_CD  = C.ITEM_CD
					  WHERE  1=1
					  GROUP  BY PARTWK, C.ITEM_GRP, C.PRDT_GRADE_CD
					  -- DMT
					  UNION  ALL
					 SELECT  @P_DM_VERSION
						  ,  PARTWK
						  ,  C.ITEM_GRP			  AS ITEM_GRP
						  ,  C.PRDT_GRADE_CD	  AS PRDT_GRADE_CD
						  ,  SUM(FP_PLAN_QTY)	  AS FP_PLAN_QTY
					   FROM  #TM_DM_QTY A
					  INNER  JOIN TB_CM_CALENDAR B
						 ON  A.PLAN_DTE = B.DAT
					  INNER  JOIN #TM_TGT C
						 ON  A.ITEM_CD  = C.ITEM_CD
					  WHERE  1=1
					  GROUP  BY PARTWK, C.ITEM_GRP, C.PRDT_GRADE_CD
				) B

    -----------------------------------
    -- MIX 생산량
    -- 버전의 FROM DATE ~ TO DATE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_FP_MIX') IS NOT NULL DROP TABLE #TM_FP_MIX -- 임시테이블 삭제
		SELECT *
		  INTO #TM_FP_MIX
		  FROM (SELECT VER_ID
					 , PARTWK
					 , A.TO_PRDT_GRADE_CD   AS PRDT_GRADE_CD
					 , SUM(ADJ_PLAN_QTY)	AS MIX_PLAN_QTY
				 FROM TB_SKC_FP_RS_PRDT_PLAN_MIX  A
				INNER JOIN TB_CM_CALENDAR B
				   ON A.PLAN_DTE = B.DAT
				WHERE VER_ID     = @P_CP_VERSION
				  AND ( A.TO_PRDT_GRADE_CD IN (SELECT VAL FROM #TM_PRDT_GRADE_CD)  OR ISNULL( @P_PRDT_GRADE_CD, 'ALL') = 'ALL' )
				GROUP BY VER_ID, PARTWK, A.TO_PRDT_GRADE_CD) A;

    -----------------------------------
    -- 기초재고 임시 테이블
    -----------------------------------
	IF OBJECT_ID('tempdb..#TM_STCK') IS NOT NULL DROP TABLE #TM_STCK
		SELECT  PLNT_CD
			 ,  WRHS_CD
			 ,  ITEM_GRP
			 ,  PRDT_GRADE_CD
			 ,  BASE_DATE
			 ,  STCK_STUS_CD
			 ,  SUM(STCK_QTY)		AS STCK_QTY
		  INTO  #TM_STCK
		 -- FROM  TB_SKC_CM_FERT_STCK_HST A
		 --INNER  JOIN #TM_TGT B
		  FROM  #TM_TGT A
		 INNER  JOIN TB_SKC_CM_FERT_STCK_HST B
		    ON  A.ITEM_CD = B.ITEM_CD
		 WHERE  BASE_DATE = @V_BOH_YYYYMMDD_CP
		 GROUP  BY PLNT_CD, WRHS_CD, ITEM_GRP, PRDT_GRADE_CD, BASE_DATE, STCK_STUS_CD;

    -----------------------------------
    -- 기초재고
    -- 버전의 FROM DATE의 전일
    -----------------------------------
	IF OBJECT_ID('tempdb..#TM_BOH') IS NOT NULL DROP TABLE #TM_BOH -- 임시테이블 삭제


		SELECT  A.ITEM_GRP						   AS ITEM_GRP
			 ,  A.PRDT_GRADE_CD					   AS PRDT_GRADE_CD
			 ,  BASE_DATE						   AS BASE_DATE
			 ,  SUM(STCK_QTY)/1000                 AS STCK_QTY
		  INTO  #TM_BOH
		  FROM  #TM_STCK A
		 INNER  JOIN ( SELECT  PLNT_CD, WRHS_CD 
		                 FROM  VW_FP_WRHS_MST D
		                UNION 
		               SELECT  PLNT_CD, WRHS_CD 
				 	     FROM  TB_SKC_CM_WRHS_MST D
				 	    WHERE  CORP_CD = '1000'
				 	      AND  PLNT_CD IN ( '1110','1230')
				 	      AND  WRHS_STD_CD  = '02' /*20240819 오창환 매니저 요청 : COPOLY 기준 임가공 재고 기초 포함*/
                     )  D
		    ON  A.PLNT_CD = D.PLNT_CD
		   AND  A.WRHS_CD = D.WRHS_CD
		 WHERE  BASE_DATE = @V_BOH_YYYYMMDD_CP
		--   AND PLNT_CD IN ( '1110','1230')
		   AND  A.ITEM_GRP = '11'
		   AND  A.STCK_STUS_CD = '가용'
		 GROUP  BY A.ITEM_GRP, A.PRDT_GRADE_CD, BASE_DATE
		 UNION  ALL -- CHDM 기초재고 수정
		SELECT  C.ITEM_GRP						   AS ITEM_GRP
			 ,  C.PRDT_GRADE_CD					   AS PRDT_GRADE_CD
			 ,  CLOSE_DT						   AS BASE_DATE
			 ,  SUM(A.STCK_QTY)/1000			   AS STCK_QTY
		  FROM  TB_SKC_CM_MES_LINE_STCK_HST A
         INNER  JOIN TB_SKC_FP_RSRC_MST B
		    ON  ISNULL(B.SCM_CAPA_USE_YN,'N') = 'Y'
           AND  ISNULL(B.SCM_USE_YN,'N')      = 'Y'
		   AND  A.RSRC_NM  = B.SCM_RSRC_NM
		 INNER  JOIN #TM_TGT C
		    ON  A.ITEM_CD = C.ITEM_CD
		 WHERE  CLOSE_DT = (SELECT DISTINCT DATEADD(DAY, -1, FROM_DT) FROM VW_FP_PLAN_VERSION WHERE VERSION = @P_CP_VERSION) -- 24.08.27 Copoly 계획 시작일 기준으로 변경
		   AND  A.ITEM_CD = '100001'
		 GROUP  BY C.ITEM_GRP, C.PRDT_GRADE_CD, CLOSE_DT
		 UNION  ALL 
		SELECT  A.ITEM_GRP						 AS ITEM_GRP
			 ,  A.PRDT_GRADE_CD					 AS PRDT_GRADE_CD
			 ,  BASE_DATE						 AS BASE_DATE
			 ,  SUM(STCK_QTY)/1000				 AS STCK_QTY
		  FROM  #TM_STCK A
		 WHERE  1=1
		   AND  A.PLNT_CD    = '1250'
		   AND  A.ITEM_GRP   = '27'
		 GROUP  BY A.ITEM_GRP, A.PRDT_GRADE_CD, BASE_DATE
	 --    UNION  ALL
  --   	SELECT  A.ITEM_GRP						AS ITEM_GRP
		--	 ,  A.PRDT_GRADE_CD					AS PRDT_GRADE_CD
		--	 ,  BASE_DATE						AS BASE_DATE
		--	 ,  SUM(STCK_QTY)/1000				AS STCK_QTY
		--  FROM  #TM_STCK A
		-- INNER  JOIN ( SELECT  PLNT_CD, WRHS_CD 
		--                 FROM  VW_FP_WRHS_MST D
		--                UNION 
		--               SELECT  PLNT_CD, WRHS_CD 
		--		 	     FROM  TB_SKC_CM_WRHS_MST D
		--		 	    WHERE  CORP_CD = '1000'
		--		 	      AND  PLNT_CD IN ( '1110','1230')
		--		 	      AND  WRHS_STD_CD  = '02' /*20240819 오창환 매니저 요청 : COPOLY 기준 임가공 재고 기초 포함*/
  --                   )  D
		--    ON  A.PLNT_CD = D.PLNT_CD
		--   AND  A.WRHS_CD = D.WRHS_CD
		-- WHERE  BASE_DATE = @V_BOH_YYYYMMDD_CP
		----   AND PLNT_CD IN ( '1110','1230')
		--   AND  ITEM_GRP = '11'
		--   AND  A.STCK_STUS_CD = '가용'
		--   AND  A.PRDT_GRADE_CD IS NOT NULL
		-- GROUP  BY A.ITEM_GRP, A.PRDT_GRADE_CD, BASE_DATE
		
    -----------------------------------
    -- 기초재고(톤): Report 시작 주차의 예상 기초 재고  
	-- 계산식: 생산 계획 수립일 기초 재고 – (당주 출하 필요량 – 당주 출하 실적) + (당주 잔여일 동안 생산계획)  
    -----------------------------------		
	IF OBJECT_ID('tempdb..#TM_BASESTCK') IS NOT NULL DROP TABLE #TM_BASESTCK -- 임시테이블 삭제
		SELECT A.ITEM_GRP
		 	 , A.PRDT_GRADE_CD
			 --, ROUND(A.STCK_QTY - COALESCE(B.MP_PLAN_QTY, 0) + COALESCE(B.SHMT_QTY, 0) + COALESCE(FP_PLAN_QTY, 0), 0) AS BOH_QTY
			 , A.STCK_QTY AS BOH_QTY
		  INTO #TM_BASESTCK
		  FROM #TM_BOH A
		 INNER JOIN TB_CM_CALENDAR CAL
			ON A.BASE_DATE = CAL.DAT
		  --LEFT JOIN #TM_SHMT B
		  --LEFT JOIN (SELECT PARTWK
				--		  , ITEM_GRP
				--		  , PRDT_GRADE_CD
				--		  , SUM(SHMT_QTY) AS SHMT_QTY
				--		  , SUM(MP_PLAN_QTY) AS MP_PLAN_QTY
				--	   FROM #TM_SHMT 
				--	  GROUP BY PARTWK, ITEM_GRP, PRDT_GRADE_CD) B
		  --  ON CAL.PARTWK = B.PARTWK
		  -- AND A.ITEM_GRP = B.ITEM_GRP
		  -- AND A.PRDT_GRADE_CD = B.PRDT_GRADE_CD
		  LEFT JOIN #TM_FP_PLAN C
			ON CAL.PARTWK = C.PARTWK
		   AND A.ITEM_GRP = C.ITEM_GRP
		   AND A.PRDT_GRADE_CD = C.PRDT_GRADE_CD		   
		   
    -----------------------------------
    -- 캠페인/Pilot 생산량	
    -----------------------------------		
	IF OBJECT_ID('tempdb..#TM_CAMPIL') IS NOT NULL DROP TABLE #TM_CAMPIL 
		SELECT PARTWK
			 , SUM(ADJ_PLAN_QTY) AS CAMPIL_QTY
		  INTO #TM_CAMPIL
		  FROM TB_SKC_FP_RS_PRDT_GRADE_PLAN_CO A
		 INNER JOIN TB_CM_CALENDAR CAL
			ON A.PLAN_DTE = CAL.DAT
		 WHERE PRDT_GRADE_CD IN ('PIL', 'CAM')
		   AND VER_ID     = @P_CP_VERSION
		 GROUP BY PARTWK		   
		   
    -----------------------------------
	-- 예상 재고: 
	-- COPOLY: 기초재고 + 생산량 - 출하 필요량
	-- CHDM:   기초재고 - 소요량 - 외부 판매량 + 생산량
	-- DMT:    기초재고 - 소요량 - 외부 판매량 + 생산량
    -----------------------------------		
	IF OBJECT_ID('tempdb..#TM_PRED_STCK') IS NOT NULL DROP TABLE #TM_PRED_STCK -- 임시테이블 삭제
		SELECT TGT.VER_ID
			 , TGT.ITEM_GRP
			 , TGT.PRDT_GRADE_CD
			 , MAX(DAT_ID) AS PLAN_DTE
			 , TGT.PARTWK
			 , ISNULL(SUM(FP.FP_PLAN_QTY)   , 0) AS FP_PLAN_QTY
			 , ISNULL(SUM(MP.MP_PLAN_QTY)   , 0) AS MP_PLAN_QTY
			 , ISNULL(SUM(PACK.REQ_PACK_QTY), 0) AS REQ_PACK_QTY
			 , ISNULL(SUM(PRDT.REQ_PRDT_QTY), 0) AS REQ_PRDT_QTY
		  INTO #TM_PRED_STCK
		  FROM (SELECT DISTINCT VER_ID, C.PARTWK, ITEM_GRP, PRDT_GRADE_CD
				  FROM #TM_TGT A
				 CROSS JOIN (SELECT MAX(DAT) AS DAT_ID, PARTWK FROM TB_CM_CALENDAR WHERE DAT BETWEEN @V_FR_YYYYMMDD_CP AND @V_TO_YYYYMMDD_CP GROUP BY PARTWK) C) TGT
		  LEFT JOIN (SELECT PARTWK
						  , ITEM_GRP
						  , PRDT_GRADE_CD
						  , SUM(FP_PLAN_QTY) AS FP_PLAN_QTY
					   FROM  #TM_FP_PLAN A
					  GROUP BY PARTWK, ITEM_GRP, PRDT_GRADE_CD) FP
			ON TGT.PARTWK        = FP.PARTWK
		   AND TGT.ITEM_GRP      = FP.ITEM_GRP
		   AND TGT.PRDT_GRADE_CD = FP.PRDT_GRADE_CD
		  LEFT JOIN (SELECT PARTWK
						  , ITEM_GRP
						  , PRDT_GRADE_CD
						  , SUM(MP_PLAN_QTY) AS MP_PLAN_QTY
					   FROM  #TM_MP_PLAN A
					  GROUP BY PARTWK, ITEM_GRP, PRDT_GRADE_CD) MP
		    ON TGT.PARTWK        = MP.PARTWK
		   AND TGT.ITEM_GRP      = MP.ITEM_GRP
		   AND TGT.PRDT_GRADE_CD = MP.PRDT_GRADE_CD
		  LEFT JOIN (SELECT PARTWK
						  , ITEM_GRP
						  , PRDT_GRADE_CD
						  , SUM(REQ_PACK_QTY) AS REQ_PACK_QTY
					   FROM  #TM_REQ_PACK A
					  GROUP BY PARTWK, ITEM_GRP, PRDT_GRADE_CD) PACK
		    ON TGT.PARTWK        = PACK.PARTWK
		   AND TGT.ITEM_GRP      = PACK.ITEM_GRP
		   AND TGT.PRDT_GRADE_CD = PACK.PRDT_GRADE_CD
		  LEFT JOIN (SELECT PARTWK
						  , ITEM_GRP
						  , PRDT_GRADE_CD
						  , SUM(REQ_PRDT_QTY) AS REQ_PRDT_QTY
					   FROM  #TM_REQ_PRDT A
					  GROUP BY PARTWK, ITEM_GRP, PRDT_GRADE_CD) PRDT
		    ON TGT.PARTWK        = PRDT.PARTWK
		   AND TGT.ITEM_GRP      = PRDT.ITEM_GRP
		   AND TGT.PRDT_GRADE_CD = PRDT.PRDT_GRADE_CD
		 INNER JOIN (SELECT MAX(DAT) AS DAT_ID, PARTWK FROM TB_CM_CALENDAR GROUP BY PARTWK) CAL
		    ON TGT.PARTWK = CAL.PARTWK
		 GROUP BY TGT.VER_ID, TGT.ITEM_GRP, TGT.PRDT_GRADE_CD, TGT.PARTWK
		  ;
		  
	DECLARE @TMP_QTY TABLE (VER_ID CHAR(30), ITEM_GRP CHAR(30), PRDT_GRADE_CD CHAR(30), PLAN_DTE CHAR(10), PARTWK CHAR(10), YYYYMM CHAR(6), PRED_STCK FLOAT, FP_PLAN_QTY FLOAT, BOH_QTY FLOAT, MP_PLAN_QTY FLOAT, REQ_PACK_QTY FLOAT, REQ_PRDT_QTY FLOAT, CAMPIL_QTY FLOAT, MIX_PLAN_QTY FLOAT)
	IF @P_SUM = 'Y'
		BEGIN
			INSERT INTO @TMP_QTY
				SELECT VER_ID
					 , ITEM_GRP
					 , PRDT_GRADE_CD
					 , PLAN_DTE
					 , A.PARTWK	
					 , YYYYMM	 
					 , BOH_QTY + CAL_QTY AS PRED_STCK				 
					 , FP_PLAN_QTY
					 , BOH_QTY
					 , MP_PLAN_QTY
					 , REQ_PACK_QTY
					 , REQ_PRDT_QTY
					 , CAMPIL_QTY
					 , MIX_PLAN_QTY
				  FROM (SELECT VER_ID
							 , ITEM_GRP
							 , PRDT_GRADE_CD
							 , PLAN_DTE
							 , PARTWK
							 , YYYYMM
							 , BOH_QTY
							 , FP_PLAN_QTY
							 , SUM(FP_PLAN_QTY)  OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) AS SUM_FP_PLAN_QTY
							 , MP_PLAN_QTY
							 , REQ_PACK_QTY
							 , REQ_PRDT_QTY
							 , SUM(MP_PLAN_QTY)  OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) AS SUM_MP_PLAN_QTY
							 , SUM(REQ_PACK_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) AS SUM_REQ_PACK_QTY
							 , SUM(REQ_PRDT_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) AS SUM_REQ_PRDT_QTY
							 , CASE WHEN A.ITEM_GRP = '11' THEN SUM(FP_PLAN_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) - SUM(MP_PLAN_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK)
									ELSE SUM(FP_PLAN_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) - SUM(REQ_PACK_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) - SUM(REQ_PRDT_QTY) OVER (PARTITION BY ITEM_GRP ORDER BY PARTWK) END AS CAL_QTY
							 , MIX_PLAN_QTY
						  FROM (SELECT A.VER_ID
									 , A.ITEM_GRP
									 , 'ALL' AS PRDT_GRADE_CD
									 , B.PLAN_DTE
									 , B.PARTWK
									 , B.YYYYMM
									 , NULL AS PRED_STCK
									 , SUM(COALESCE(FP_PLAN_QTY , 0)) AS FP_PLAN_QTY
									 , COALESCE(D.BOH_QTY       , 0)  AS BOH_QTY
									 , SUM(COALESCE(MP_PLAN_QTY , 0)) AS MP_PLAN_QTY
									 , SUM(COALESCE(REQ_PACK_QTY, 0)) AS REQ_PACK_QTY
									 , SUM(COALESCE(REQ_PRDT_QTY, 0)) AS REQ_PRDT_QTY
									 , SUM(MIX_PLAN_QTY) AS MIX_PLAN_QTY
								  FROM (SELECT DISTINCT VER_ID, ITEM_GRP, PRDT_GRADE_CD FROM #TM_PRED_STCK) A
								 CROSS JOIN (SELECT PARTWK, YYYYMM, MAX(DAT_ID) AS PLAN_DTE
											   FROM TB_CM_CALENDAR 
											  WHERE DAT BETWEEN @V_FR_YYYYMMMO_CP AND @V_TO_YYYYMMDD_CP
											  GROUP BY PARTWK, YYYYMM) B
						  LEFT JOIN #TM_PRED_STCK C
						    ON  A.VER_ID        = C.VER_ID
						   AND  A.ITEM_GRP      = C.ITEM_GRP
						   AND  A.PRDT_GRADE_CD = C.PRDT_GRADE_CD
						   AND  B.PLAN_DTE      = C.PLAN_DTE
						   AND  B.PARTWK        = C.PARTWK
						  --LEFT  JOIN (SELECT ITEM_GRP, SUM(ISNULL(BOH_QTY,0)) AS BOH_QTY
								-- 	    FROM (SELECT DISTINCT ITEM_GRP, BOH_QTY FROM #TM_BASESTCK) A
								-- 	   GROUP BY ITEM_GRP) D
						  --  ON  A.ITEM_GRP = D.ITEM_GRP
						  LEFT  JOIN (SELECT ITEM_GRP, SUM(BOH_QTY) AS BOH_QTY
										FROM #TM_BASESTCK
									   GROUP BY ITEM_GRP) D
							ON  A.ITEM_GRP      = D.ITEM_GRP
						  LEFT  JOIN #TM_FP_MIX E
						    ON  A.PRDT_GRADE_CD = E.PRDT_GRADE_CD
						   AND  B.PARTWK        = E.PARTWK
						 GROUP  BY A.VER_ID, A.ITEM_GRP, B.PLAN_DTE, B.PARTWK, B.YYYYMM, D.BOH_QTY) A
						) A
					LEFT  JOIN #TM_CAMPIL B
					  ON  A.PARTWK   = B.PARTWK
		END;

	IF @P_SUM = 'N'
		BEGIN
			INSERT INTO @TMP_QTY
				SELECT VER_ID
					 , ITEM_GRP
					 , PRDT_GRADE_CD
					 , PLAN_DTE
					 , PARTWK		 
					 , YYYYMM
					 , BOH_QTY + CAL_QTY AS PRED_STCK				 
					 , FP_PLAN_QTY
					 , BOH_QTY
					 , MP_PLAN_QTY				 
					 , REQ_PACK_QTY
					 , REQ_PRDT_QTY
					 , NULL
					 , MIX_PLAN_QTY
				  FROM (SELECT A.VER_ID
							 , A.ITEM_GRP
							 , A.PRDT_GRADE_CD
							 , A.PARTWK
							 , A.YYYYMM
							 , A.PLAN_DTE
							 , SUM(COALESCE(FP_PLAN_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) AS SUM_FP_PLAN_QTY
							 , COALESCE(FP_PLAN_QTY , 0) AS FP_PLAN_QTY
							 , COALESCE(D.BOH_QTY   , 0) AS BOH_QTY
							 , COALESCE(MP_PLAN_QTY , 0) AS MP_PLAN_QTY
							 , COALESCE(REQ_PACK_QTY, 0) AS REQ_PACK_QTY
							 , COALESCE(REQ_PRDT_QTY, 0) AS REQ_PRDT_QTY
							 , SUM(COALESCE(MP_PLAN_QTY , 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) AS SUM_MP_PLAN_QTY
							 , SUM(COALESCE(REQ_PACK_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) AS SUM_REQ_PACK_QTY
							 , SUM(COALESCE(REQ_PRDT_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) AS SUM_REQ_PRDT_QTY
							 , CASE WHEN A.ITEM_GRP = '11' THEN SUM(COALESCE(FP_PLAN_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) - SUM(COALESCE(MP_PLAN_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK)
									ELSE SUM(COALESCE(FP_PLAN_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) - SUM(COALESCE(REQ_PACK_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) - SUM(COALESCE(REQ_PRDT_QTY, 0)) OVER (PARTITION BY A.ITEM_GRP, A.PRDT_GRADE_CD ORDER BY A.PARTWK) END AS CAL_QTY
							 , E.MIX_PLAN_QTY
						  FROM (SELECT A.VER_ID
									 , A.ITEM_GRP
									 , A.PRDT_GRADE_CD
									 , B.PARTWK
									 , B.YYYYMM
									 , B.PLAN_DTE
								  FROM (SELECT DISTINCT VER_ID, ITEM_GRP, PRDT_GRADE_CD FROM #TM_PRED_STCK) A
								 CROSS JOIN (SELECT PARTWK, YYYYMM, MAX(DAT_ID) AS PLAN_DTE
											   FROM TB_CM_CALENDAR 
											  WHERE DAT BETWEEN @V_FR_YYYYMMMO_CP AND @V_TO_YYYYMMDD_CP
											  GROUP BY PARTWK, YYYYMM) B) A
								  LEFT  JOIN #TM_PRED_STCK C
								    ON  A.VER_ID = C.VER_ID
								   AND  A.ITEM_GRP = C.ITEM_GRP
								   AND  A.PRDT_GRADE_CD = C.PRDT_GRADE_CD
								   AND  A.PLAN_DTE = C.PLAN_DTE
								   AND  A.PARTWK = C.PARTWK
								  LEFT  OUTER JOIN #TM_BASESTCK D
									ON  A.ITEM_GRP = D.ITEM_GRP
								   AND  A.PRDT_GRADE_CD = D.PRDT_GRADE_CD
								  LEFT  OUTER  JOIN #TM_FP_MIX E
								    ON  A.PRDT_GRADE_CD = E.PRDT_GRADE_CD
								   AND  A.PARTWK = E.PARTWK) A
		END;
		
    -----------------------------------
	-- #TMP_QTY
    -----------------------------------		
	IF OBJECT_ID('tempdb..#TMP_QTY') IS NOT NULL DROP TABLE #TMP_QTY
	SELECT * 
	  INTO #TMP_QTY
	  FROM @TMP_QTY;

    -----------------------------------
	-- QTY
    -----------------------------------		

		SELECT DISTINCT A.VER_ID
		 , A.ITEM_GRP AS ITEM_GRP_CD
		 , CASE WHEN @P_SUM = 'Y' THEN (SELECT ITEM_LV_NM FROM TB_CM_ITEM_LEVEL_MGMT WHERE ITEM_LV_CD = A.ITEM_GRP) ELSE ISNULL(C.ATTR_05, C.ATTR_11) END AS ITEM_GRP_NM
		 , A.PRDT_GRADE_CD
		 , CASE WHEN @P_SUM = 'Y' THEN 'ALL' ELSE ISNULL(C.PRDT_GRADE_NM, C.ATTR_11) END AS PRDT_GRADE_NM
		 , ROUND(A.BOH_QTY, 1) AS BOH_QTY
		 , A.PARTWK
		 , A.YYYYMM
		 , A.PLAN_DTE
		 , B.MEASURE_CD
		 , B.MEASURE_NM
		 , CASE WHEN MEASURE_CD IN ('01', '04', '08')     THEN ROUND(COALESCE(FP_PLAN_QTY , 0),1)
				WHEN MEASURE_CD = '02'					  THEN ROUND(COALESCE(MP_PLAN_QTY , 0),1)
				WHEN MEASURE_CD IN ('03', '07', '11')     THEN ROUND(COALESCE(PRED_STCK   , 0),1)
				WHEN MEASURE_CD = '03_2' AND @P_SUM = 'Y' THEN ROUND(COALESCE(CAMPIL_QTY  , 0),1)
				WHEN MEASURE_CD = '03_3'				  THEN ROUND(COALESCE(MIX_PLAN_QTY, 0),1) 
				WHEN MEASURE_CD IN ('06', '10')			  THEN ROUND(COALESCE(REQ_PACK_QTY, 0),1)
				WHEN MEASURE_CD IN ('05', '09')			  THEN ROUND(COALESCE(REQ_PRDT_QTY, 0),1) END AS QTY
	  FROM (SELECT * 
			  FROM #TMP_QTY
		 	 UNION ALL
			SELECT A.VER_ID
				 , A.ITEM_GRP
				 , A.PRDT_GRADE_CD
				 , 'SUM_' + A.YYYYMM AS PLAN_DTE
				 , 'SUM_' + A.YYYYMM AS PARTWK
				 , A.YYYYMM
				 , MAX(B.PRED_STCK)  AS PRED_STCK
				 , SUM(FP_PLAN_QTY)  AS FP_PLAN_QTY
				 , BOH_QTY
				 , SUM(MP_PLAN_QTY)  AS MP_PLAN_QTY
				 , SUM(REQ_PACK_QTY) AS REQ_PACK_QTY
				 , SUM(REQ_PRDT_QTY) AS REQ_PRDT_QTY
				 , SUM(CAMPIL_QTY)   AS CAMPIL_QTY
				 , SUM(MIX_PLAN_QTY) AS MIXPLAN_QTY
			  FROM #TMP_QTY A
			 INNER JOIN (SELECT DISTINCT VER_ID, ITEM_GRP, PRDT_GRADE_CD, YYYYMM, LAST_VALUE(PRED_STCK) OVER (PARTITION BY VER_ID, ITEM_GRP, PRDT_GRADE_CD, YYYYMM ORDER BY VER_ID, ITEM_GRP, PRDT_GRADE_CD, YYYYMM DESC) AS PRED_STCK
						   FROM #TMP_QTY) B
				ON A.VER_ID		   = B.VER_ID
			   AND A.ITEM_GRP	   = B.ITEM_GRP
			   AND A.PRDT_GRADE_CD = B.PRDT_GRADE_CD
			   AND A.YYYYMM		   = B.YYYYMM
			 GROUP BY A.VER_ID, A.ITEM_GRP, A.PRDT_GRADE_CD, A.YYYYMM, BOH_QTY) A
	 INNER JOIN 
			(SELECT DISTINCT ATTR_01_VAL AS ITEM_GRP
				  , COMN_CD      AS MEASURE_CD
				  , COMN_CD_NM   AS MEASURE_NM
				  , SEQ          AS SEQ
			   FROM FN_COMN_CODE('FP1080','') 
			  WHERE COMN_CD != '03_2'
			  UNION ALL 
			 SELECT DISTINCT ATTR_01_VAL AS ITEM_GRP
				  , COMN_CD      AS MEASURE_CD
				  , COMN_CD_NM   AS MEASURE_NM
				  , SEQ          AS SEQ
			   FROM FN_COMN_CODE('FP1080','') 
			  WHERE COMN_CD = '03_2'
			    AND 1 = CASE WHEN @P_SUM = 'Y' THEN '1' ELSE '2' END) B
		ON A.ITEM_GRP = B.ITEM_GRP
	  LEFT JOIN (SELECT DISTINCT PRDT_GRADE_CD, PRDT_GRADE_NM, ATTR_04, ATTR_05, ATTR_10, ATTR_11 FROM TB_CM_ITEM_MST) C
	    ON A.PRDT_GRADE_CD = ISNULL(C.PRDT_GRADE_CD, C.ATTR_10)
	   AND A.ITEM_GRP      = C.ATTR_04
	ORDER BY A.ITEM_GRP, A.PRDT_GRADE_CD, YYYYMM, PARTWK, MEASURE_CD; 	 

END

GO
