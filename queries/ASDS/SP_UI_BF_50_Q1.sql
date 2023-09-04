CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_Q1" 
(
    p_VER_CD            VARCHAR2, 
    p_ITEM              VARCHAR2,
    p_ITEM_LV			VARCHAR2,
    p_SALES             VARCHAR2,
    p_SALES_LV			VARCHAR2,
    p_FROM_DATE         DATE,
    p_TO_DATE           DATE,
    p_SRC_TP			VARCHAR2,
    p_USERNAME          VARCHAR2,
    p_BEST_SELECT_YN    CHAR,
	p_SUM			    VARCHAR2 := 'Y',	
    pRESULT             OUT SYS_REFCURSOR
)IS 
    p_ACCURACY          VARCHAR2(30);
    v_SRC_TP			VARCHAR2(5) := NULL;
    v_EXISTS_NUM		INT := 0;
BEGIN
    SELECT RULE_01 INTO p_ACCURACY
      FROM TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND (PROCESS_NO = '990000' OR PROCESS_NO = '990')
       ;

    v_SRC_TP := NVL(p_SRC_TP,'');
   
    SELECT CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 1 ELSE 0 END INTO v_EXISTS_NUM
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
   
    IF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N' AND v_EXISTS_NUM = 1
	THEN  
    OPEN pRESULT FOR
	WITH RT AS (
        SELECT B.ITEM_CD
        	 , B.ITEM_NM
             , B.ACCOUNT_CD
             , B.ACCOUNT_NM
             , B.BASE_DATE
             , B.ENGINE_TP_CD
			 , NULL 	AS ACCRY
			 , '1' 		AS SELECT_SEQ
             , SUM(QTY) AS QTY
             , B.VER_CD
          FROM ( 
         	 	SELECT IH.ANCS_CD AS ITEM_CD
					 , IH.ANCS_NM AS ITEM_NM
					 , AH.ANCS_CD AS ACCOUNT_CD
					 , AH.ANCS_NM AS ACCOUNT_NM
					 , BASE_DATE
					 , QTY
					 , RT.ENGINE_TP_CD 
					 , RT.VER_CD
				  FROM TB_BF_RT RT 
				 INNER JOIN TEMP_ITEM_HIER2 IH 
				 	ON IH.DESC_CD = RT.ITEM_CD
				 INNER JOIN TEMP_ACCT_HIER2 AH 
				 	ON AH.DESC_CD = RT.ACCOUNT_CD		
			 	 WHERE 1=1
			 	   AND VER_CD = p_VER_CD 
				   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
				   AND IH.ANCS_CD = p_ITEM
				   AND AH.ANCS_CD LIKE p_SALES||'%'
				) B
		 GROUP BY B.ITEM_CD, B.ITEM_NM, B.ACCOUNT_CD, B.ACCOUNT_NM, B.BASE_DATE, B.ENGINE_TP_CD, B.VER_CD
    )
    SELECT RT.VER_CD
    	 , RT.ITEM_CD
    	 , RT.ITEM_NM
    	 , RT.ACCOUNT_CD 
    	 , RT.ACCOUNT_NM
		 , RT.ENGINE_TP_CD		AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE			AS "DATE"
		 , SUM(RT.QTY)			AS QTY
		 , SELECT_SEQ	
	  FROM RT
	GROUP BY RT.VER_CD
		   , RT.ITEM_CD 
		   , RT.ITEM_NM
		   , RT.ACCOUNT_CD 
		   , RT.ACCOUNT_NM
		   , RT.BASE_DATE
		   , RT.ENGINE_TP_CD
		   , RT.ACCRY
		   , SELECT_SEQ	 
	ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
    ;
    COMMIT;
    DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
   
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y' AND v_EXISTS_NUM = 1
	THEN  
    OPEN pRESULT FOR
	WITH RT AS (
		SELECT IH.ANCESTER_CD 	AS ITEM_CD
			 , IH.ANCESTER_NM 	AS ITEM_NM
			 , AH.ANCESTER_CD 	AS ACCOUNT_CD
			 , AH.ANCESTER_NM	AS ACCOUNT_NM
			 , BASE_DATE
			 , 'FCST'			AS ENGINE_TP_CD
			 , NULL				AS ACCRY
			 , NULL 			AS SELECT_SEQ
             , SUM(QTY) 		AS QTY
             , p_VER_CD 		AS VER_CD
		  FROM TB_BF_RT_AGG RT 		
		 INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH 
		    ON RT.ITEM_CD = IH.DESCENDANT_CD
		 INNER JOIN TB_DPD_SALES_HIER_CLOSURE AH 
		 	ON RT.ACCOUNT_CD = AH.DESCENDANT_CD
		 INNER JOIN TEMP_ACCT_HIER2 AH2 
		 	ON AH.DESCENDANT_CD = AH2.DESC_CD 
		   AND AH.ANCESTER_CD = AH2.ANCS_CD
		 WHERE 1=1
		   AND VER_CD = p_VER_CD 
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
		   AND IH.ANCESTER_CD = p_ITEM
		   AND AH.ANCESTER_CD LIKE p_SALES||'%'
		   AND RT.SRC_TP LIKE v_SRC_TP||'%'
		 GROUP BY IH.ANCESTER_CD, IH.ANCESTER_NM, AH.ANCESTER_CD, AH.ANCESTER_NM, BASE_DATE, VER_CD
    )
    SELECT RT.VER_CD
    	 , RT.ITEM_CD
    	 , RT.ITEM_NM
    	 , RT.ACCOUNT_CD 
    	 , RT.ACCOUNT_NM
		 , RT.ENGINE_TP_CD		AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE			AS "DATE"
		 , QTY
		 , SELECT_SEQ	
	  FROM RT	 
	 ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD, BASE_DATE
    ;
    COMMIT;
    DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
   
	ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N' AND v_EXISTS_NUM = 0
	THEN  
    OPEN pRESULT FOR
	WITH RT AS (
        SELECT IH.ANCS_CD 	AS ITEM_CD
			 , IH.ANCS_NM 	AS ITEM_NM
			 , AH.ANCS_CD 	AS ACCOUNT_CD
			 , AH.ANCS_NM 	AS ACCOUNT_NM
			 , BASE_DATE
			 , RT.ENGINE_TP_CD
			 , NULL 		AS ACCRY
			 , NULL 		AS SELECT_SEQ
			 , SUM(QTY) 	AS QTY 
			 , p_VER_CD	 	AS VER_CD
		  FROM TB_BF_RT RT 
		 INNER JOIN TEMP_ITEM_HIER2 IH 
		 	ON IH.DESC_CD = RT.ITEM_CD
		 INNER JOIN TEMP_ACCT_HIER2 AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
		 WHERE 1=1 
		   AND VER_CD = p_VER_CD
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
		   AND IH.ANCS_CD = p_ITEM
		   AND AH.ANCS_CD LIKE p_SALES||'%'
		 GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, BASE_DATE, RT.ENGINE_TP_CD
)				 
    SELECT p_VER_CD  		AS VER_CD
    	 , RT.ITEM_CD
    	 , RT.ITEM_NM
    	 , RT.ACCOUNT_CD 
    	 , RT.ACCOUNT_NM
		 , RT.ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE		AS "DATE"
		 , QTY
		 , SELECT_SEQ	
	  FROM RT
	ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
    ;
    COMMIT;
    DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
    
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y' AND v_EXISTS_NUM = 0
	THEN  
    OPEN pRESULT FOR
	WITH RT AS (
        SELECT IH.ANCS_CD 	AS ITEM_CD
			 , IH.ANCS_NM 	AS ITEM_NM
			 , AH.ANCS_CD 	AS ACCOUNT_CD
			 , AH.ANCS_NM 	AS ACCOUNT_NM
			 , BASE_DATE
			 , 'FCST'		AS ENGINE_TP_CD
			 , NULL 		AS ACCRY
			 , '1' 			AS SELECT_SEQ
			 , SUM(QTY) 	AS QTY 
			 , p_VER_CD 	AS VER_CD
		  FROM TB_BF_RT RT 
		 INNER JOIN TEMP_ITEM_HIER2 IH 
		 	ON IH.DESC_CD = RT.ITEM_CD
		 INNER JOIN TEMP_ACCT_HIER2 AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
		 INNER JOIN (SELECT ITEM_CD
		 				  , ACCOUNT_CD
		 				  , ENGINE_TP_CD
		 			   FROM TB_BF_RT_ACCRCY
 		 			  WHERE VER_CD = p_VER_CD
 		 			    AND SELECT_SEQ = 1) AC
 		    ON RT.ITEM_CD = AC.ITEM_CD 
 		   AND RT.ACCOUNT_CD = AC.ACCOUNT_CD 
 		   AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
		 WHERE 1=1 
		   AND VER_CD = p_VER_CD
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
		   AND IH.ANCS_CD = p_ITEM
		   AND AH.ANCS_CD LIKE p_SALES||'%'
		 GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, BASE_DATE
	)				 
    SELECT p_VER_CD  		AS VER_CD
    	 , RT.ITEM_CD
    	 , RT.ITEM_NM
    	 , RT.ACCOUNT_CD 
    	 , RT.ACCOUNT_NM
		 , RT.ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE		AS "DATE"
		 , QTY
		 , SELECT_SEQ	
	  FROM RT
 	 ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
	;
	COMMIT;
    DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
   
    ELSE   
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT B.ITEM_CD
        	 , B.ITEM_NM
             , B.ACCOUNT_CD
             , B.ACCOUNT_NM
             , B.BASE_DATE
             , B.ENGINE_TP_CD	
             , CASE p_ACCURACY WHEN 'MAPE'   THEN MAPE
                               WHEN 'MAE'	 THEN MAE
                               WHEN 'MAE_P'  THEN MAE_P
                               WHEN 'RMSE'	 THEN RMSE 
                               WHEN 'RMSE_P' THEN RMSE_P
                               WHEN 'WAPE'	 THEN WAPE
                               WHEN 'MAPE_W' THEN MAPE_W
                               ELSE NULL END AS ACCRY
			 , SELECT_SEQ
             , QTY 
             , A.VER_CD 
          FROM (SELECT IH.DESC_CD 	AS ITEM_CD
					 , IH.DESC_NM 	AS ITEM_NM
					 , AH.DESC_CD 	AS ACCOUNT_CD
					 , AH.DESC_NM 	AS ACCOUNT_NM
					 , BASE_DATE
					 , SUM(QTY) 	AS QTY
					 , ENGINE_TP_CD 
				  FROM TB_BF_RT RT 
				 INNER JOIN TEMP_ITEM_HIER2 IH 
				 	ON IH.DESC_CD = RT.ITEM_CD
				 INNER JOIN TEMP_ACCT_HIER2 AH 
				 	ON AH.DESC_CD = RT.ACCOUNT_CD
				 WHERE 1=1 
				   AND VER_CD = p_VER_CD 
				   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
				   AND IH.ANCS_CD = p_ITEM
				   AND AH.ANCS_CD LIKE p_SALES||'%'
				 GROUP BY IH.DESC_CD, IH.DESC_NM, AH.DESC_CD, AH.DESC_NM, BASE_DATE, ENGINE_TP_CD
				) B
           LEFT JOIN (SELECT /*+ INDEX(AC IDX_TB_BF_RT_ACCRCY_T_01) */
				             ENGINE_TP_CD
           	 			   , ITEM_CD
           	 			   , ACCOUNT_CD
           	 			   , MAPE
           	 			   , MAE
           	 			   , MAE_P
           	 			   , RMSE
           	 			   , RMSE_P
           	 			   , MAPE_W
           	 			   , WAPE
           	 			   , SELECT_SEQ
           	 			   , VER_CD
           	 			FROM TB_BF_RT_ACCRCY
           	 		   WHERE VER_CD = p_VER_CD
           	 		) A 
   	 			ON (A.ITEM_CD = B.ITEM_CD 
	           AND A.ACCOUNT_CD = B.ACCOUNT_CD 
	           AND A.ENGINE_TP_CD = B.ENGINE_TP_CD)
			 WHERE CASE WHEN p_BEST_SELECT_YN = 'Y' THEN SELECT_SEQ ELSE 1 END = 1
    )
    SELECT p_VER_CD 		AS VER_CD
    	 , RT.ITEM_CD
    	 , RT.ITEM_NM
    	 , RT.ACCOUNT_CD 
    	 , RT.ACCOUNT_NM
		 , RT.ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE		AS "DATE"
		 , SUM(RT.QTY)		AS QTY
		 , SELECT_SEQ	
	  FROM RT
	GROUP BY RT.VER_CD
		   , RT.ITEM_CD 
		   , RT.ITEM_NM
		   , RT.ACCOUNT_CD 
		   , RT.ACCOUNT_NM
		   , RT.BASE_DATE
		   , RT.ENGINE_TP_CD
		   , RT.ACCRY
		   , SELECT_SEQ	 
	ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
    ;
    COMMIT;
    DELETE FROM TEMP_ITEM_HIER2;
    DELETE FROM TEMP_ACCT_HIER2;
    COMMIT;
   
    END IF;
END;