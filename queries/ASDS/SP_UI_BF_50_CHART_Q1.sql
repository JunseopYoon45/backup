CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_CHART_Q1" 
(
    p_VER_CD        	VARCHAR2,
    p_ITEM       		VARCHAR2,
    p_ITEM_LV			VARCHAR2,
    p_SALES        	 	VARCHAR2,
    p_SALES_LV			VARCHAR2,
    p_FROM_DATE    		DATE,
    p_TO_DATE    	  	DATE,
    p_SRC_TP			VARCHAR2,
    p_SUM				VARCHAR2 := 'Y',
    p_BEST_SELECT_YN  	VARCHAR2,
    pRESULT         OUT SYS_REFCURSOR
)IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_50_CHART_Q1
   * Purpose : 주 단위 수요예측 결과 차트 조회
   * Notes :
   * 	M20180115092445697M411878346346N	ITEM_ALL	상품전체
		N20180115092528519N506441512113N	LEVEL1		대분류
		N20180115092559329M499525073971N	LEVEL2		중분류
		FA5FEBBCADDED90DE053DD0A10AC8DB5	LEVEL3		소분류
		M20180115092627169N446701842271O	ITEM		상품선택
		N20180115092712856O251735022591O	ALL			채널전체
		FE00001E54F88F3FE053DD0A10AC762B	CENTER		센터
		N20180115092710840N520475678180O	CHANNEL		채널선택
   **************************************************************************/
    p_TARGET_FROM_DATE  DATE := NULL;
    v_TARGET_FROM_DATE  DATE := NULL;
    v_TO_DATE           DATE := NULL;
    v_BUKT              VARCHAR2(5);
    v_SRC_TP			VARCHAR2(5) := NULL;
	v_EXISTS_NUM		INT := 0;
	v_VER_CD			VARCHAR2(100);

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

    SELECT MAX(END_DATE) INTO v_TO_DATE
      FROM (
            SELECT YYYY
                 , DP_WK
                 , MIN(DAT) AS STRT_DATE
                 , MAX(DAT) AS END_DATE
              FROM TB_CM_CALENDAR C
             WHERE DAT BETWEEN p_FROM_DATE AND p_TO_DATE
	      GROUP BY YYYY, DP_WK
      HAVING COUNT(DP_WK) >= 7
      );

	v_SRC_TP := NVL(p_SRC_TP,'');

	SELECT CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 1 ELSE 0 END INTO v_EXISTS_NUM
    FROM DUAL;

	/* 합계 조회 O, BEST SELECT Y, 소분류 이상 조건 */
	IF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y' AND v_EXISTS_NUM = 1
	THEN 
    OPEN pRESULT FOR
    WITH IDS AS (
    	SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
    )
    , ADS AS (
    	SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , SL.SALES_LV_NM 	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_SALES_LEVEL_MGMT SL 
         	ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_SALES_LV
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_SALES||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , AM.ACCOUNT_NM	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_ACCOUNT_MST AM 
         	ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_SALES||'%'  
    )
    , RT AS (
	    SELECT 
	    	   IH.ANCESTER_CD 	AS ITEM_CD
			 , AH.ANCESTER_CD 	AS ACCOUNT_CD
			 , BASE_DATE
			 , 'FCST' 			AS ENGINE_TP_CD
			 , SUM(QTY) 		AS QTY
		  FROM TB_BF_RT_AGG RT
		 INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
		 	ON RT.ITEM_CD = IH.DESCENDANT_CD
		 INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH 
		 	ON RT.ACCOUNT_CD = AH.DESCENDANT_CD
		 INNER JOIN ADS AH2 
		    ON AH.DESCENDANT_CD = AH2.DESC_CD 
		   AND AH.ANCESTER_CD = AH2.ANCS_CD
		 WHERE 1=1
		   AND VER_CD = p_VER_CD
		   AND BASE_DATE BETWEEN p_TARGET_FROM_DATE AND v_TO_DATE
		   AND AH.ANCESTER_CD LIKE p_SALES||'%'
		   AND IH.ANCESTER_CD = p_ITEM
		   AND SRC_TP LIKE v_SRC_TP||'%'
		 GROUP BY IH.ANCESTER_CD, AH.ANCESTER_CD, BASE_DATE, ENGINE_TP_CD    
    ) 
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2) AS BUKT
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     

    )
    , CA AS (
        SELECT MIN(DAT)	 AS STRT_DATE
             , BUKT	
             , MAX(DAT)	 AS END_DATE
          FROM CALENDAR CA
         GROUP BY BUKT 
    )
    , SA AS (
       SELECT IH.ANCESTER_CD AS ITEM_CD
      	    , AH.ANCESTER_CD AS ACCOUNT_CD
            , CA.STRT_DATE
            , CA.BUKT 
            , SUM(S.QTY)	QTY 
         FROM (SELECT BASE_DATE
         	   	 	, ITEM_CD
         	   	 	, ACCOUNT_CD
         	   	 	, QTY
         	   	 	, SRC_TP 
         	   	 FROM TB_CM_ACTUAL_SALES_AGG 
         	   	WHERE VER_CD = p_VER_CD 
         	   	  AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE  
         	   	  AND SRC_TP LIKE v_SRC_TP||'%') S
        INNER JOIN CA ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
        INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH ON S.ITEM_CD = IH.DESCENDANT_CD
        INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH ON S.ACCOUNT_CD = AH.DESCENDANT_CD
        INNER JOIN ADS AH2 ON AH.DESCENDANT_CD = AH2.DESC_CD AND AH.ANCESTER_CD = AH2.ANCS_CD
        WHERE 1=1
          AND IH.ANCESTER_CD = p_ITEM
          AND AH.ANCESTER_CD LIKE p_SALES||'%'
        GROUP BY IH.ANCESTER_CD, AH.ANCESTER_CD, CA.BUKT, CA.STRT_DATE
    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , RT.ACCOUNT_CD	AS ACCOUNT_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)		AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
         GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, ENGINE_TP_CD 
         UNION
        SELECT SA.ITEM_CD
             , SA.ACCOUNT_CD
             , BUKT
             , 'Z_ACT_SALES'	AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ACCOUNT_CD 
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
                  	   FROM N  
                      GROUP BY ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ACCOUNT_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
      	ON M.ITEM_CD = N.ITEM_CD
       AND M.ACCOUNT_CD = N.ACCOUNT_CD
       AND M.BUKT = N.BUKT
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
     	ON SUBSTR(M.BUKT, 1, 4) || SUBSTR(M.BUKT, 7) = C.DP_WK
     WHERE C.DOW = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE;

     COMMIT;        

    /* 합계 조회 O, BEST SELECT Y, 센터 이상 조건 */
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y' AND v_EXISTS_NUM = 0
	THEN 
    OPEN pRESULT FOR
    WITH IDS AS (
    	SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
    )
    , ADS AS (
    	SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , SL.SALES_LV_NM 	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_SALES_LEVEL_MGMT SL 
         	ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_SALES_LV
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_SALES||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , AM.ACCOUNT_NM	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_ACCOUNT_MST AM 
         	ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_SALES||'%'  
    )
    , RT AS (
		SELECT IH.ANCS_CD AS ITEM_CD
         	 , AH.ANCS_CD AS ACCOUNT_CD
	         , BASE_DATE 
	         , 'FCST' AS ENGINE_TP_CD
	         , SUM(QTY)	  AS QTY
	      FROM TB_BF_RT_FINAL RT
	     INNER JOIN ADS AH 
	     	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN IDS IH 
         	ON IH.DESC_CD = RT.ITEM_CD
	     WHERE 1=1
		   AND RT.VER_CD = p_VER_CD	
		   AND BASE_DATE BETWEEN p_TARGET_FROM_DATE AND v_TO_DATE
         GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE  
    ) 
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2) AS BUKT
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 STRT_DATE
             , BUKT	
             , MAX(DAT)	 END_DATE
          FROM CALENDAR CA
       GROUP BY BUKT 
    )
    , SA AS (
       SELECT ITEM_CD
      	    , ACCOUNT_CD
            , CA.STRT_DATE
            , CA.BUKT 
            , QTY 
          FROM (SELECT BASE_DATE
          			 , IH.ANCS_CD AS ITEM_CD
          			 , AH.ANCS_CD AS ACCOUNT_CD
          			 , SUM(QTY)   AS QTY 
          		  FROM TB_CM_ACTUAL_SALES_HIST S
          		 INNER JOIN IDS IH 
         		    ON IH.DESC_ID = S.ITEM_MST_ID
		         INNER JOIN ADS AH
		          	ON AH.DESC_ID = S.ACCOUNT_ID
          		 WHERE VER_CD = p_VER_CD
          		   AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
          		 GROUP BY BASE_DATE, IH.ANCS_CD, AH.ANCS_CD) S 
        INNER JOIN CA ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE  
    )
    , N AS (
        SELECT RT.ITEM_CD					AS ITEM_CD
             , RT.ACCOUNT_CD				AS ACCOUNT_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)					AS QTY 			 
          FROM RT 
         INNER JOIN CA 
            ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
         GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, ENGINE_TP_CD 
         UNION
        SELECT SA.ITEM_CD
             , SA.ACCOUNT_CD
             , BUKT
             , 'Z_ACT_SALES'						AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    ), M
    AS (
        SELECT ITEM_CD
             , ACCOUNT_CD 
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
                       FROM N  
                      GROUP BY ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ACCOUNT_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
        ON M.ITEM_CD = N.ITEM_CD
       AND M.ACCOUNT_CD = N.ACCOUNT_CD
       AND M.BUKT = N.BUKT
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
     	ON SUBSTR(M.BUKT, 1, 4) || SUBSTR(M.BUKT, 7) = C.DP_WK
     WHERE C.DOW = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE;

     COMMIT;        

    /* 합계 조회 O, BEST SELECT N 조건 */
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N'
	THEN 
    OPEN pRESULT FOR
    WITH IDS AS (
    	SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
    )
    , ADS AS (
    	SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , SL.SALES_LV_NM 	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_SALES_LEVEL_MGMT SL 
         	ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_SALES_LV
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_SALES||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , AM.ACCOUNT_NM	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_ACCOUNT_MST AM 
         	ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_SALES||'%'  
    )
    , RT AS (
	    SELECT /*+ FULL(RT) PARALLEL(RT 4) */
        	   IH.ANCS_CD AS ITEM_CD
         	 , AH.ANCS_CD AS ACCOUNT_CD
	         , BASE_DATE 
	         , ENGINE_TP_CD
	         , SUM(QTY)	  AS QTY
	      FROM TB_BF_RT RT
	     INNER JOIN ADS AH 
	     	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN IDS IH 
         	ON IH.DESC_CD = RT.ITEM_CD
	     WHERE 1=1
		   AND RT.VER_CD = p_VER_CD	
		   AND BASE_DATE BETWEEN p_TARGET_FROM_DATE AND v_TO_DATE
         GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE, ENGINE_TP_CD
    ) 
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2) AS BUKT
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 STRT_DATE
             , BUKT	
             , MAX(DAT)	 END_DATE
          FROM CALENDAR CA
         GROUP BY BUKT 
    )
    , SA AS ( 
         SELECT /*+ PARALLEL(4) */
         		ITEM_CD 
              , ACCOUNT_CD
              , CA.STRT_DATE
              , CA.BUKT 
              , QTY
--              , SUM(QTY) AS QTY
          FROM (SELECT BASE_DATE
          			 , IH.ANCS_CD AS ITEM_CD
          			 , AH.ANCS_CD AS ACCOUNT_CD
          			 , SUM(QTY)   AS QTY 
--          			 , QTY
          		  FROM TB_CM_ACTUAL_SALES_HIST S
          		 INNER JOIN IDS IH 
         		    ON IH.DESC_ID = S.ITEM_MST_ID
		         INNER JOIN ADS AH
		          	ON AH.DESC_ID = S.ACCOUNT_ID
          		 WHERE VER_CD = p_VER_CD
          		 GROUP BY BASE_DATE, IH.ANCS_CD, AH.ANCS_CD) S 
         INNER JOIN CA 
         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
    ) 
    , N AS (
        SELECT RT.ITEM_CD					AS ITEM_CD
             , RT.ACCOUNT_CD				AS ACCOUNT_CD
             , CA.BUKT
             , ENGINE_TP_CD
             , SUM(RT.QTY)					AS QTY 			 
          FROM RT 
         INNER JOIN CA 
            ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
         GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, ENGINE_TP_CD 
         UNION
        SELECT SA.ITEM_CD
             , SA.ACCOUNT_CD
             , BUKT
             , 'Z_ACT_SALES'						AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ACCOUNT_CD 
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
         		       FROM N 
                      GROUP BY ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ACCOUNT_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
        ON M.ITEM_CD = N.ITEM_CD
       AND M.ACCOUNT_CD = N.ACCOUNT_CD
       AND M.BUKT = N.BUKT
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
     	ON SUBSTR(M.BUKT, 1, 4) || SUBSTR(M.BUKT, 7) = C.DP_WK
     WHERE C.DOW = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE;

     COMMIT;        

     ELSE
     OPEN pRESULT FOR
     WITH IDS AS (
    	SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM  
    )
    , ADS AS (
    	SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , SL.SALES_LV_NM 	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_SALES_LEVEL_MGMT SL 
         	ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_SALES_LV
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_SALES||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
             , SH.DESCENDANT_CD AS DESC_CD
             , SH.DESCENDANT_NM AS DESC_NM
             , SH.ANCESTER_CD 	AS ANCS_CD
             , AM.ACCOUNT_NM	AS ANCS_NM
          FROM TB_DPD_SALES_HIER_CLOSURE SH
         INNER JOIN TB_DP_ACCOUNT_MST AM 
         	ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_SALES||'%'  
    )
    , RT AS (
	    SELECT IH.DESC_CD AS ITEM_CD
         	 , AH.DESC_CD AS ACCOUNT_CD
	         , BASE_DATE 
	         , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD
	         , COALESCE(SUM(QTY),0)	AS QTY
	      FROM TB_BF_RT RT
	     INNER JOIN ADS AH 
	     	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN IDS IH 
         	ON IH.DESC_CD = RT.ITEM_CD
	     WHERE 1=1
   	       AND VER_CD = p_VER_CD
	       AND BASE_DATE BETWEEN p_TARGET_FROM_DATE and v_TO_DATE
         GROUP BY IH.DESC_CD, AH.DESC_CD, BASE_DATE, ENGINE_TP_CD
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2) AS BUKT
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 STRT_DATE
             , BUKT	
             , MAX(DAT)	 END_DATE
          FROM CALENDAR CA
         GROUP BY BUKT 
    )
    , SA AS (
        SELECT ITEM_CD
        	  , ACCOUNT_CD
              , CA.STRT_DATE
              , CA.BUKT 
              , SUM(S.QTY)	QTY 
          FROM (SELECT BASE_DATE
          			 , IH.DESC_CD AS ITEM_CD
          			 , AH.DESC_CD AS ACCOUNT_CD
          			 , ITEM_MST_ID
          			 , ACCOUNT_ID
          			 , QTY 
          		  FROM TB_CM_ACTUAL_SALES_HIST S
          		 INNER JOIN IDS IH 
         		    ON IH.DESC_ID = S.ITEM_MST_ID
		         INNER JOIN ADS AH
		          	ON AH.DESC_ID = S.ACCOUNT_ID
          		 WHERE VER_CD = p_VER_CD
          		   AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE) S  

         INNER JOIN CA 
         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
         WHERE 1=1
         GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, CA.STRT_DATE
    )
    , N AS (
        SELECT RT.ITEM_CD					AS ITEM_CD
             , RT.ACCOUNT_CD				AS ACCOUNT_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)					AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
    	 GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, ENGINE_TP_CD 
         UNION 
        SELECT SA.ITEM_CD
             , SA.ACCOUNT_CD
             , BUKT
             , 'Z_ACT_SALES'						AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ACCOUNT_CD 
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN (SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
                       FROM N  
                      GROUP BY ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD) RT
    )
    SELECT M.ITEM_CD
         , M.ACCOUNT_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , C.DAT AS "DATE"
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N 
      	ON M.ITEM_CD = N.ITEM_CD
       AND M.ACCOUNT_CD = N.ACCOUNT_CD
       AND M.BUKT = N.BUKT
       AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     INNER JOIN TB_CM_CALENDAR C 
     	ON SUBSTR(M.BUKT, 1, 4) || SUBSTR(M.BUKT, 7) = C.DP_WK
     WHERE C.DOW = 1
     ORDER BY M.ITEM_CD, M.ACCOUNT_CD, M.ENGINE_TP_CD, M.STRT_DATE;

	 COMMIT;    

     END IF;


END
;