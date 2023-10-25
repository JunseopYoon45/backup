CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_CHART_MA_Q1" 
(
    p_VER_CD         VARCHAR2,
    p_ITEM       	 VARCHAR2,
    p_ITEM_LV		 VARCHAR2,
    p_FROM_DATE      DATE,
    p_TO_DATE        DATE,
    p_SUM			 VARCHAR2 := 'Y',
    p_BEST_SELECT_YN VARCHAR2,
    pRESULT         OUT SYS_REFCURSOR  
)
IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_50_CHART_MA_Q1
   * Purpose : 월/총량 수요예측 결과 차트 조회
   * Notes :
   * 	M20180115092445697M411878346346N	ITEM_ALL	상품전체
		N20180115092528519N506441512113N	LEVEL1		대분류
		N20180115092559329M499525073971N	LEVEL2		중분류
		FA5FEBBCADDED90DE053DD0A10AC8DB5	LEVEL3		소분류
   **************************************************************************/
    p_TARGET_FROM_DATE  DATE := NULL;
    v_TO_DATE           DATE := NULL;
    v_BUKT              VARCHAR2(5);
	v_EXISTS_NUM		INT := 0;

BEGIN
    SELECT MAX(TARGET_FROM_DATE)
         , MAX(TARGET_BUKT_CD)
           INTO
           p_TARGET_FROM_DATE
         , v_BUKT
      FROM TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND ENGINE_TP_CD IS NOT NULL
    ;

    v_TO_DATE := p_TO_DATE;
   
	SELECT CASE WHEN p_ITEM_LV = 'FA5FEBBCADDED90DE053DD0A10AC8DB5' THEN '0' ELSE '1' END INTO v_EXISTS_NUM
  	FROM DUAL;
  
    /* 합계 조회 O, 소분류 이상, BEST SELECT N인 조건 */
    IF p_SUM = 'Y' AND v_EXISTS_NUM = 1 AND p_BEST_SELECT_YN = 'N'
    THEN 
    OPEN pRESULT FOR
    WITH ITEM_HIER AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'N'
           AND LENGTH(IH.DESCENDANT_CD) = 4
           AND ANCESTER_CD LIKE p_ITEM||'%'
    )
    , RT AS (
        SELECT IH.ANCS_CD 			AS ITEM_CD
             , BASE_DATE 
             , ENGINE_TP_CD
             , COALESCE(SUM(QTY),0)	AS QTY
          FROM TB_BF_RT_MA RT
         INNER JOIN ITEM_HIER IH 
         	ON RT.ITEM_CD = IH.DESC_CD
         WHERE BASE_DATE BETWEEN p_FROM_DATE and v_TO_DATE
           AND VER_CD = p_VER_CD
         GROUP BY IH.ANCS_CD, BASE_DATE, ENGINE_TP_CD  
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , YYYYMM AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 			AS STRT_DATE
             , BUKT	
             , MAX(LAST_DAY(DAT))	AS END_DATE
          FROM CALENDAR CA
         WHERE TRUNC(DAT, 'MONTH') BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY BUKT 
    )
    , SA AS (
   		SELECT IH2.ANCS_CD 	AS ITEM_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , ROUND(SUM(SAL_AMT), 2)		AS QTY 
          FROM DS_TB_IF_SALESPLAN_DIVSAL S
         INNER JOIN CA 
         	ON S.YYYYMM = CA.BUKT           
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.DIV_COD = IH.DESCENDANT_CD
         INNER JOIN ITEM_HIER IH2 
         	ON IH2.DESC_CD = IH.ANCESTER_CD
         WHERE 1=1 
           AND IH2.ANCS_CD LIKE p_ITEM||'%' 
           AND CA.STRT_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY IH2.ANCS_CD, CA.BUKT, CA.STRT_DATE    
    )
--    , SA AS (
--        SELECT IH2.ANCS_CD 	AS ITEM_CD
--             , CA.STRT_DATE
--             , CA.BUKT 
--             , SUM(AMT)		AS QTY 
--          FROM TB_CM_ACTUAL_SALES S
--         INNER JOIN CA 
--         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
--         INNER JOIN TB_CM_ITEM_MST IM 
--         	ON S.ITEM_MST_ID = IM.ID 
--           AND COALESCE(IM.DEL_YN,'N') = 'N'           
--         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
--         	ON IM.ITEM_CD = IH.DESCENDANT_CD
--         INNER JOIN ITEM_HIER IH2 
--         	ON IH2.DESC_CD = IH.ANCESTER_CD
--         WHERE 1=1 
----           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
--           AND IH2.ANCS_CD LIKE p_ITEM||'%' 
--           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
--         GROUP BY IH2.ANCS_CD, CA.BUKT, CA.STRT_DATE
--    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)		AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
    	 GROUP BY ITEM_CD, CA.BUKT, ENGINE_TP_CD 
         UNION ALL
        SELECT SA.ITEM_CD
             , BUKT
             , 'Z_ACT_SALES'	AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ENGINE_TP_CD
                       FROM N  
                      GROUP BY ITEM_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
      	ON M.ITEM_CD = N.ITEM_CD 
       AND M.BUKT = N.BUKT 
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
        ON M.BUKT = C.YYYYMM           
     WHERE C.DD = '1' 
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE
     ;
    COMMIT;
  
    /* 합계 조회 O, 소분류 이상, BEST SELECT Y인 조건 */
    ELSIF p_SUM = 'Y' AND v_EXISTS_NUM = 1 AND p_BEST_SELECT_YN = 'Y'
    THEN 
    OPEN pRESULT FOR
    WITH ITEM_HIER AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'N'
           AND LENGTH(IH.DESCENDANT_CD) = 4
           AND ANCESTER_CD LIKE p_ITEM||'%'
    )
    , RT AS (
        SELECT IH.ANCS_CD 			AS ITEM_CD
             , BASE_DATE 
             , 'FCST'				AS ENGINE_TP_CD
             , COALESCE(SUM(QTY),0)	AS QTY
          FROM TB_BF_RT_FINAL_MA RT
         INNER JOIN ITEM_HIER IH 
         	ON RT.ITEM_CD = IH.DESC_CD
         WHERE BASE_DATE BETWEEN p_FROM_DATE and v_TO_DATE
           AND VER_CD = p_VER_CD
         GROUP BY IH.ANCS_CD, BASE_DATE  
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , YYYYMM AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 			AS STRT_DATE
             , BUKT	
             , MAX(LAST_DAY(DAT))	AS END_DATE
          FROM CALENDAR CA
         WHERE TRUNC(DAT, 'MONTH') BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY BUKT 
    )
    , SA AS (
   		SELECT IH2.ANCS_CD 	AS ITEM_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , ROUND(SUM(SAL_AMT), 2)		AS QTY 
          FROM DS_TB_IF_SALESPLAN_DIVSAL S
         INNER JOIN CA 
         	ON S.YYYYMM = CA.BUKT           
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.DIV_COD = IH.DESCENDANT_CD
         INNER JOIN ITEM_HIER IH2 
         	ON IH2.DESC_CD = IH.ANCESTER_CD
         WHERE 1=1 
           AND IH2.ANCS_CD LIKE p_ITEM||'%' 
           AND CA.STRT_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY IH2.ANCS_CD, CA.BUKT, CA.STRT_DATE        
    )
--    , SA AS (
--        SELECT IH2.ANCS_CD 	AS ITEM_CD
--             , CA.STRT_DATE
--             , CA.BUKT 
--             , SUM(AMT)		AS QTY 
--          FROM TB_CM_ACTUAL_SALES S
--         INNER JOIN CA 
--         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
--         INNER JOIN TB_CM_ITEM_MST IM 
--         	ON S.ITEM_MST_ID = IM.ID 
--           AND COALESCE(IM.DEL_YN,'N') = 'N'           
--         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
--         	ON IM.ITEM_CD = IH.DESCENDANT_CD
--         INNER JOIN ITEM_HIER IH2 
--         	ON IH2.DESC_CD = IH.ANCESTER_CD
--         WHERE 1=1 
----           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
--           AND IH2.ANCS_CD LIKE p_ITEM||'%' 
--           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
--         GROUP BY IH2.ANCS_CD, CA.BUKT, CA.STRT_DATE
--    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , CA.BUKT
             , 'FCST' 			AS ENGINE_TP_CD
             , SUM(RT.QTY)		AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
    	 GROUP BY ITEM_CD, CA.BUKT, ENGINE_TP_CD 
         UNION ALL
        SELECT SA.ITEM_CD
             , BUKT
             , 'Z_ACT_SALES'	AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ENGINE_TP_CD
                       FROM N  
                      GROUP BY ITEM_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
      	ON M.ITEM_CD = N.ITEM_CD 
       AND M.BUKT = N.BUKT 
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
        ON M.BUKT = C.YYYYMM           
     WHERE C.DD = '1' 
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE
     ;
   COMMIT;
  
   ELSE
   OPEN pRESULT FOR
    WITH ITEM_HIER AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'N'
           AND LENGTH(IH.DESCENDANT_CD) = 4
           AND ANCESTER_CD LIKE p_ITEM||'%'
    )
    , RT AS (
        SELECT IH.DESC_CD 		AS ITEM_CD
             , BASE_DATE 
             , ENGINE_TP_CD
             , COALESCE(QTY,0)	AS QTY
          FROM TB_BF_RT_MA RT
         INNER JOIN ITEM_HIER IH ON RT.ITEM_CD = IH.DESC_CD
         WHERE BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
           AND VER_CD = p_VER_CD
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , YYYYMM AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 			AS STRT_DATE
             , BUKT	
             , MAX(LAST_DAY(DAT))	AS END_DATE
          FROM CALENDAR CA
         WHERE TRUNC(DAT, 'MONTH') BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY BUKT 
    )
    , SA AS (
   		SELECT IH2.DESC_CD 	AS ITEM_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , ROUND(SUM(SAL_AMT), 2)		AS QTY 
          FROM DS_TB_IF_SALESPLAN_DIVSAL S
         INNER JOIN CA 
         	ON S.YYYYMM = CA.BUKT           
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.DIV_COD = IH.DESCENDANT_CD
         INNER JOIN ITEM_HIER IH2 
         	ON IH2.DESC_CD = IH.ANCESTER_CD
         WHERE 1=1 
           AND IH2.ANCS_CD LIKE p_ITEM||'%' 
           AND CA.STRT_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY IH2.DESC_CD, CA.BUKT, CA.STRT_DATE        
    )
--    , SA AS (
--        SELECT IH2.DESC_CD 	AS ITEM_CD
--             , CA.STRT_DATE
--             , CA.BUKT 
--             , SUM(AMT)		AS QTY 
--          FROM TB_CM_ACTUAL_SALES S
--         INNER JOIN CA 
--         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
--         INNER JOIN TB_CM_ITEM_MST IM 
--         	ON S.ITEM_MST_ID = IM.ID 
--           AND COALESCE(IM.DEL_YN,'N') = 'N'           
--         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
--         	ON IM.ITEM_CD = IH.DESCENDANT_CD
--         INNER JOIN ITEM_HIER IH2 
--         	ON IH2.DESC_CD = IH.ANCESTER_CD
--         WHERE 1=1 
--           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
--           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
--         GROUP BY IH2.DESC_CD, CA.BUKT, CA.STRT_DATE
--    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)		AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
    	 GROUP BY ITEM_CD, CA.BUKT, ENGINE_TP_CD 
         UNION ALL
        SELECT SA.ITEM_CD
             , BUKT
             , 'Z_ACT_SALES'	AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ENGINE_TP_CD
	      	           FROM N  
                      GROUP BY ITEM_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
      	ON M.ITEM_CD = N.ITEM_CD 
       AND M.BUKT = N.BUKT 
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
        ON M.BUKT = C.YYYYMM           
     WHERE C.DD = '1' 
     ORDER BY M.ITEM_CD, M.ENGINE_TP_CD, M.STRT_DATE
     ;
   COMMIT;  
   END IF;
END;