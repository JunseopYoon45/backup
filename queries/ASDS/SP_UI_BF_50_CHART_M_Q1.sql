CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_CHART_M_Q1" 
(
    p_VER_CD         VARCHAR2,
    p_ITEM       	 VARCHAR2,
    p_ITEM_LV		 VARCHAR2,
    p_SALES          VARCHAR2,
    p_SALES_LV		 VARCHAR2,
    p_FROM_DATE      DATE,
    p_TO_DATE        DATE,
    p_SRC_TP		 VARCHAR2,
    p_SUM			 VARCHAR2 := 'Y',
    p_BEST_SELECT_YN VARCHAR2,
    pRESULT         OUT SYS_REFCURSOR  
)IS 

    p_TARGET_FROM_DATE  DATE := NULL;
    v_TO_DATE           DATE := NULL;
    v_BUKT              VARCHAR2(5);
    v_SRC_TP			VARCHAR2(5) := NULL;
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
    v_SRC_TP := NVL(p_SRC_TP,'');
   
    SELECT CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN '1' ELSE '0' END INTO v_EXISTS_NUM
  	FROM DUAL;
   
	DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
  	
    INSERT INTO TEMP_ITEM_HIER2 (
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
           AND ANCESTER_CD LIKE p_ITEM||'%'  
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
           AND ANCESTER_CD LIKE p_ITEM||'%'
    );
    
   	COMMIT;
   
    INSERT INTO TEMP_ACCT_HIER2 (
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
    );
   
    COMMIT;

   	IF p_SUM = 'Y' AND v_EXISTS_NUM = 1 AND p_BEST_SELECT_YN = 'N'
   	THEN
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT IH.ANCS_CD AS ITEM_CD
         	 , AH.ANCS_CD AS ACCOUNT_CD
	         , BASE_DATE 
	         , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD
	         , COALESCE(SUM(QTY),0)	AS QTY
          FROM TB_BF_RT_M RT
		 INNER JOIN TEMP_ACCT_HIER2 AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN TEMP_ITEM_HIER2 IH 
         	ON IH.DESC_CD = RT.ITEM_CD
	     WHERE BASE_DATE BETWEEN p_FROM_DATE and v_TO_DATE
	       AND VER_CD = p_VER_CD
         GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE, ENGINE_TP_CD          
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , CASE v_BUKT
                 WHEN 'W' THEN SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2)
                 WHEN 'PW' THEN YYYYMM || ' w' || SUBSTR(DP_WK, 5, 2)
                 WHEN 'M' THEN YYYYMM
               END AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE and v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 STRT_DATE
             , BUKT	
             , MAX(DAT)	 END_DATE
          FROM CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE and v_TO_DATE 
       GROUP BY BUKT 
    )
    , SA AS (
        SELECT /*+ INDEX(S IDX_IDX_ACTUAL_SALES_T_01) */
        	   IH.ANCESTER_CD AS ITEM_CD
             , AH.ANCESTER_CD AS ACCOUNT_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , SUM(QTY)	QTY 
          FROM TB_CM_ACTUAL_SALES S
         INNER JOIN CA 
         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.ITEM_MST_ID = IH.DESCENDANT_ID
         INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH 
         	ON S.ACCOUNT_ID = AH.DESCENDANT_ID
         INNER JOIN TB_BF_ITEM_ACCOUNT_MODEL_MAP IAM 
         	ON IH.DESCENDANT_CD = IAM.ITEM_CD
           AND AH.DESCENDANT_CD = IAM.ACCOUNT_CD
         INNER JOIN TB_CM_ITEM_MST IT 
         	ON IH.DESCENDANT_CD = IT.ITEM_CD
         WHERE 1=1
           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
           AND AH.ANCESTER_CD LIKE p_SALES||'%'
           AND IAM.ACTV_YN = 'Y'
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
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
         CROSS JOIN(SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
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
     	ON M.BUKT = C.YYYYMM
     WHERE C.DD = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE
              ;
     COMMIT;
     DELETE TEMP_ITEM_HIER2;
     DELETE TEMP_ACCT_HIER2;
   		
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y'
   	THEN
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT IH.ANCS_CD 			AS ITEM_CD
         	 , AH.ANCS_CD 			AS ACCOUNT_CD
	         , BASE_DATE 
	         , 'FCST' 				AS ENGINE_TP_CD
	         , COALESCE(SUM(QTY),0)	AS QTY
          FROM TB_BF_RT_M RT
		 INNER JOIN TEMP_ACCT_HIER2 AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN TEMP_ITEM_HIER2 IH 
         	ON IH.DESC_CD = RT.ITEM_CD
         INNER JOIN (SELECT ITEM_CD
         				  , ACCOUNT_CD
         				  , ENGINE_TP_CD
         			   FROM TB_BF_RT_ACCRCY_M
         			  WHERE 1=1
         			    AND SELECT_SEQ = 1
         			    AND VER_CD = p_VER_CD) AC 
            ON RT.ITEM_CD = AC.ITEM_CD
           AND RT.ACCOUNT_CD = AC.ACCOUNT_CD
           AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
	     WHERE BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
	       AND VER_CD = p_VER_CD
         GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE          
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , CASE v_BUKT
                 WHEN 'W' THEN SUBSTR(DP_WK, 1, 4) || ' w' || SUBSTR(DP_WK, 5, 2)
                 WHEN 'PW' THEN YYYYMM || ' w' || SUBSTR(DP_WK, 5, 2)
                 WHEN 'M' THEN YYYYMM
               END AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 AS STRT_DATE
             , BUKT	
             , MAX(DAT)	 AS END_DATE
          FROM CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE 
       GROUP BY BUKT 
    )
    , SA AS (
        SELECT /*+ INDEX(S IDX_IDX_ACTUAL_SALES_T_01) */
        	   IH.ANCESTER_CD AS ITEM_CD
             , AH.ANCESTER_CD AS ACCOUNT_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , SUM(QTY)		  AS QTY 
          FROM TB_CM_ACTUAL_SALES S
         INNER JOIN CA 
         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.ITEM_MST_ID = IH.DESCENDANT_ID
         INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH 
         	ON S.ACCOUNT_ID = AH.DESCENDANT_ID
         INNER JOIN TB_BF_ITEM_ACCOUNT_MODEL_MAP IAM 
         	ON IH.DESCENDANT_CD = IAM.ITEM_CD 
           AND AH.DESCENDANT_CD = IAM.ACCOUNT_CD
         INNER JOIN TB_CM_ITEM_MST IT 
         	ON IH.DESCENDANT_CD = IT.ITEM_CD
         WHERE 1=1
           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
           AND AH.ANCESTER_CD LIKE p_SALES||'%'
           AND IAM.ACTV_YN = 'Y'
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
         GROUP BY IH.ANCESTER_CD, AH.ANCESTER_CD, CA.BUKT, CA.STRT_DATE
    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , RT.ACCOUNT_CD	AS ACCOUNT_CD
             , CA.BUKT
             , 'FCST' 			AS ENGINE_TP_CD
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
     	ON M.BUKT = C.YYYYMM
     WHERE C.DD = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE
              ;
    
	 DELETE TEMP_ITEM_HIER2;
     DELETE TEMP_ACCT_HIER2;
     COMMIT;    
    
     ELSE
     OPEN pRESULT FOR   
	 WITH RT AS (
        SELECT IH.DESC_CD 		AS ITEM_CD
         	 , AH.DESC_CD 		AS ACCOUNT_CD
	         , BASE_DATE 
	         , ENGINE_TP_CD
	         , COALESCE(QTY,0)	AS QTY
          FROM TB_BF_RT_M RT
		 INNER JOIN TEMP_ACCT_HIER2 AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
         INNER JOIN TEMP_ITEM_HIER2 IH 
         	ON IH.DESC_CD = RT.ITEM_CD
	     WHERE BASE_DATE BETWEEN p_FROM_DATE and v_TO_DATE
	       AND VER_CD = p_VER_CD
	       AND IH.ANCS_CD LIKE p_ITEM||'%'
	       AND AH.ANCS_CD LIKE p_SALES||'%'
    ) 
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , YYYYMM AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE and v_TO_DATE
    )
    , CA AS (
        SELECT MIN(DAT)	 AS STRT_DATE
             , BUKT	
             , MAX(DAT)	 AS END_DATE
          FROM CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE and v_TO_DATE
         GROUP BY BUKT 
    ) 
    , SA AS (
        SELECT /*+ INDEX(S IDX_IDX_ACTUAL_SALES_T_01) */
		       IH.DESCENDANT_CD AS ITEM_CD
             , AH.DESCENDANT_CD AS ACCOUNT_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , QTY
          FROM TB_CM_ACTUAL_SALES S
         INNER JOIN CA 
         	ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
         INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
         	ON S.ITEM_MST_ID = IH.DESCENDANT_ID
         INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH 
         	ON S.ACCOUNT_ID = AH.DESCENDANT_ID
         INNER JOIN TB_BF_ITEM_ACCOUNT_MODEL_MAP IAM 
         	ON IH.DESCENDANT_CD = IAM.ITEM_CD 
           AND AH.DESCENDANT_CD = IAM.ACCOUNT_CD
         INNER JOIN TB_CM_ITEM_MST IT ON IH.DESCENDANT_CD = IT.ITEM_CD
         WHERE 1=1
           AND IH.ANCESTER_CD LIKE p_ITEM||'%'
           AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE 
           AND AH.ANCESTER_CD LIKE p_SALES||'%'
           AND IAM.ACTV_YN = 'Y'
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
    ) 
    , N AS (
        SELECT RT.ITEM_CD			AS ITEM_CD
             , RT.ACCOUNT_CD		AS ACCOUNT_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)			AS QTY 			 
          FROM RT 
         INNER JOIN CA 
         	ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
         GROUP BY ITEM_CD, ACCOUNT_CD, CA.BUKT, ENGINE_TP_CD 
         UNION
        SELECT SA.ITEM_CD
             , SA.ACCOUNT_CD
             , BUKT
             , 'Z_ACT_SALES'		AS ENGINE_TP_CD
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
         CROSS JOIN(SELECT ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD
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
     	ON M.BUKT = C.YYYYMM
     WHERE C.DD = 1
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE;
     COMMIT;
     END IF;
END
;