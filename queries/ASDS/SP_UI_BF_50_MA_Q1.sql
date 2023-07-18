CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_MA_Q1" 
(
    p_VER_CD            VARCHAR2, 
    p_ITEM              VARCHAR2,
    p_FROM_DATE         DATE,
    p_TO_DATE           DATE,
    p_USERNAME          VARCHAR2,
    p_BEST_SELECT_YN    CHAR,
    pRESULT             OUT SYS_REFCURSOR
)IS 
    p_ACCURACY          VARCHAR2(30);
BEGIN
    SELECT RULE_01 INTO p_ACCURACY
      FROM DWSCMDEV.TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND (PROCESS_NO = '990000' OR PROCESS_NO = '990')
       ;

    OPEN pRESULT FOR
    WITH RT AS (
        SELECT B.ITEM_CD
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
             , B.VER_CD 
          FROM (
          	SELECT ID 
	  			 , VER_CD
	  			 , ITEM_CD
	  			 , BASE_DATE
	  			 , QTY
				 , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD FROM TB_BF_RT_MA) B
	          LEFT OUTER JOIN TB_BF_RT_ACCRCY_MA A
	            ON A.ITEM_CD = B.ITEM_CD 
	           AND A.VER_CD = B.VER_CD 
	           AND A.ENGINE_TP_CD = B.ENGINE_TP_CD		  		   		  
	         WHERE B.VER_CD = p_VER_CD 
	           AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
	           AND  ( REGEXP_LIKE (UPPER(B.ITEM_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
	                  OR 
	                   p_ITEM IS NULL
	                )  
	           AND CASE WHEN p_BEST_SELECT_YN = 'Y' THEN A.SELECT_SEQ ELSE 1 END = 1
    )
    SELECT RT.VER_CD
    	 , RT.ITEM_CD
    	 , IH.LVL04_NM 		AS ITEM_NM
		 , RT.ENGINE_TP_CD	AS ENGINE_TP_CD 
		 , RT.ACCRY
		 , RT.BASE_DATE		AS "DATE"
		 , SUM(RT.QTY)		AS QTY
		 , SELECT_SEQ	
	  FROM RT
     INNER JOIN TB_DPD_ITEM_HIERACHY2 IH ON RT.ITEM_CD = IH.LVL04_CD
	 GROUP BY RT.VER_CD
		    , RT.ITEM_CD 
		    , IH.LVL04_NM
		    , RT.BASE_DATE
		    , RT.ENGINE_TP_CD
		    , RT.ACCRY
		    , SELECT_SEQ	 
	 ORDER BY RT.ITEM_CD
    ;
END
;