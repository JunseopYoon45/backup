CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_MA_Q1" 
(
    p_VER_CD            VARCHAR2,
    p_ITEM              VARCHAR2,
    p_ITEM_LV			VARCHAR2,
    p_FROM_DATE         DATE,
    p_TO_DATE           DATE,
    p_USERNAME          VARCHAR2,
    p_BEST_SELECT_YN    CHAR,
    p_SUM				VARCHAR2 := 'Y',
    pRESULT             OUT SYS_REFCURSOR
)IS 
    p_ACCURACY          VARCHAR2(30);
BEGIN
    SELECT RULE_01 INTO p_ACCURACY
      FROM TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND (PROCESS_NO = '990000' OR PROCESS_NO = '990')
       ;
      
    DELETE FROM TEMP_ITEM_HIER2;  
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
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND LENGTH(IH.DESCENDANT_CD) = 4
           AND IH.LEAF_YN = 'N'
           AND ANCESTER_CD LIKE p_ITEM||'%'  
	);
    
    IF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'Y'
    THEN
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT B.ITEM_CD
        	 , B.ITEM_NM
             , B.BASE_DATE
 			 , 'FCST' AS ENGINE_TP_CD
			 , NULL AS ACCRY
             , '1' AS  SELECT_SEQ
             , SUM(QTY) QTY 
             , B.VER_CD 
          FROM (
          	SELECT IH.ANCS_CD AS ITEM_CD
          		 , IH.ANCS_NM AS ITEM_NM
          		 , IH.DESC_CD AS ITEM_DESC
	  			 , BASE_DATE
	  			 , QTY
				 , RT.ENGINE_TP_CD
				 , VER_CD
			  FROM TB_BF_RT_MA RT
			 INNER JOIN TEMP_ITEM_HIER2 IH 
			 	ON IH.DESC_CD = RT.ITEM_CD
			 INNER JOIN (SELECT ITEM_CD
			 				  , ENGINE_TP_CD
			 		   	   FROM TB_BF_RT_ACCRCY_MA
			 			  WHERE VER_CD = p_VER_CD
			 			    AND SELECT_SEQ = 1) AC 
			 	ON RT.ITEM_CD = AC.ITEM_CD
			   AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
			 WHERE 1=1
			   AND VER_CD = p_VER_CD
			   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
	           AND IH.ANCS_CD = p_ITEM
			  ) B
		GROUP BY B.ITEM_CD, B.ITEM_NM, B.BASE_DATE, B.VER_CD
    )
    SELECT VER_CD
    	 , ITEM_CD
    	 , ITEM_NM 		AS ITEM_NM
		 , ENGINE_TP_CD	 
		 , ACCRY
		 , BASE_DATE	AS "DATE"
		 , SUM(QTY) 	AS QTY
		 , SELECT_SEQ	
	  FROM RT	 
	 GROUP BY VER_CD, ITEM_CD, ITEM_NM, ENGINE_TP_CD, ACCRY, BASE_DATE, SELECT_SEQ
	 ORDER BY ITEM_CD, ENGINE_TP_CD, BASE_DATE
    ;
    COMMIT;
   
    ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N'
    THEN
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT IH.ANCS_CD 	AS ITEM_CD
      		 , IH.ANCS_NM 	AS ITEM_NM
  			 , BASE_DATE
  			 , ENGINE_TP_CD
  			 , NULL AS ACCRY
  			 , NULL AS SELECT_SEQ
  			 , SUM(QTY) 	AS QTY
			 , VER_CD
		  FROM TB_BF_RT_MA RT
		 INNER JOIN TEMP_ITEM_HIER2 IH 
		    ON IH.DESC_CD = RT.ITEM_CD
		 WHERE 1=1
		   AND VER_CD = p_VER_CD
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
           AND IH.ANCS_CD = p_ITEM
         GROUP BY IH.ANCS_CD, IH.ANCS_NM, BASE_DATE, ENGINE_TP_CD, VER_CD
    )
    SELECT VER_CD
    	 , ITEM_CD
    	 , ITEM_NM 		AS ITEM_NM
		 , ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , ACCRY
		 , BASE_DATE	AS "DATE"
		 , SUM(QTY) 	AS QTY
		 , SELECT_SEQ	
	  FROM RT	 
	 GROUP BY VER_CD, ITEM_CD, ITEM_NM, ENGINE_TP_CD, ACCRY, BASE_DATE, SELECT_SEQ
	 ORDER BY ITEM_CD, ENGINE_TP_CD, BASE_DATE
    ;
    COMMIT;
   
	ELSE
    OPEN pRESULT FOR
    WITH RT AS (
        SELECT B.ITEM_CD
        	 , B.ITEM_NM
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
             , A.SELECT_SEQ
             , QTY 
             , A.VER_CD 
          FROM (
          	SELECT IH.DESC_CD AS ITEM_CD
          		 , IH.DESC_NM AS ITEM_NM
	  			 , BASE_DATE
	  			 , QTY
				 , ENGINE_TP_CD 
			  FROM TB_BF_RT_MA RT
			 INNER JOIN TEMP_ITEM_HIER2 IH 
			 	ON IH.DESC_CD = RT.ITEM_CD
			 WHERE VER_CD = p_VER_CD
			   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
	           AND IH.ANCS_CD = p_ITEM
			  ) B
	      LEFT JOIN TB_BF_RT_ACCRCY_MA A
	        ON A.ITEM_CD = B.ITEM_CD 
	       AND A.ENGINE_TP_CD = B.ENGINE_TP_CD		  		   		  
	       AND A.VER_CD = p_VER_CD
	     WHERE CASE WHEN p_BEST_SELECT_YN = 'Y' THEN SELECT_SEQ ELSE 1 END = 1
    )
    SELECT VER_CD
    	 , ITEM_CD
    	 , ITEM_NM 		AS ITEM_NM
		 , ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , ACCRY
		 , BASE_DATE	AS "DATE"
		 , QTY
		 , SELECT_SEQ	
	  FROM RT	 
	 ORDER BY ITEM_CD, ENGINE_TP_CD, BASE_DATE
    ;
   COMMIT;
   END IF;
END
;