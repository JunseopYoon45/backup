CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_M_Q1" 
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
    pRESULT             OUT SYS_REFCURSOR
)IS 
    p_ACCURACY          VARCHAR2(30);
    v_SRC_TP			VARCHAR2(5) := NULL;
BEGIN
    SELECT RULE_01 INTO p_ACCURACY
      FROM DWSCMDEV.TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND (PROCESS_NO = '990000' OR PROCESS_NO = '990')
       ;

	v_SRC_TP := NVL(p_SRC_TP,'');
      
    OPEN pRESULT FOR
	WITH ITEM_HIER AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.ANCESTER_CD 	AS ANCS_CD
              ,IL.ITEM_LV_NM 	AS ANCS_NM
         FROM TB_DPD_ITEM_HIER_CLOSURE IH
              INNER JOIN
              TB_CM_ITEM_LEVEL_MGMT IL
           ON IH.ANCESTER_ID = IL.ID
              INNER JOIN
              TB_CM_ITEM_MST IM
           ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                OR p_ITEM IS NULL
               )
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.ANCESTER_CD 	AS ANCS_CD
              ,CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
         FROM TB_DPD_ITEM_HIER_CLOSURE IH
              INNER JOIN
              TB_CM_ITEM_MST IT
           ON IH.ANCESTER_ID = IT.ID 
        WHERE 1=1
           AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                OR p_ITEM IS NULL
               )
          AND IH.LEAF_YN = 'Y'
          AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
          AND IT.ATTR_03 LIKE v_SRC_TP||'%'
    	)
    , ACCT_HIER AS (
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,SL.SALES_LV_NM 	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_SALES_LEVEL_MGMT SL 
           ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_SALES_LV
           AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_SALES), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                OR p_SALES IS NULL
               )
           AND SH.LEAF_YN = 'Y' 
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,AM.ACCOUNT_NM	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_ACCOUNT_MST AM 
           ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_SALES), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                OR p_SALES IS NULL
               )
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
    )    
    , RT AS (
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
			 , CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN NULL ELSE A.SELECT_SEQ END SELECT_SEQ
             , QTY 
             , B.VER_CD 
--          FROM TB_BF_RT B
          FROM (SELECT VER_CD
					 , IH.ANCS_CD AS ITEM_CD
					 , IH.ANCS_NM AS ITEM_NM
					 , AH.ANCS_CD AS ACCOUNT_CD
					 , AH.ANCS_NM AS ACCOUNT_NM
					 , BASE_DATE
					 , SUM(QTY) AS QTY
					 , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD 
				FROM TB_BF_RT_M RT
				INNER JOIN ITEM_HIER IH ON IH.DESC_CD = RT.ITEM_CD
				INNER JOIN ACCT_HIER AH ON AH.DESC_CD = RT.ACCOUNT_CD
				GROUP BY VER_CD, IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, BASE_DATE, ENGINE_TP_CD) B
          LEFT OUTER JOIN TB_BF_RT_ACCRCY_M A
            ON A.ITEM_CD = B.ITEM_CD 
           AND A.ACCOUNT_CD=B.ACCOUNT_CD 
           AND A.VER_CD = B.VER_CD 
           AND A.ENGINE_TP_CD = B.ENGINE_TP_CD		  		   		  
         WHERE B.VER_CD = p_VER_CD 
           AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
           AND  (  REGEXP_LIKE (UPPER(B.ACCOUNT_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_SALES), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                    OR 
                      p_SALES IS NULL
                    )
           AND  ( REGEXP_LIKE (UPPER(B.ITEM_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                  OR 
                   p_ITEM IS NULL
                )  
           AND CASE WHEN p_BEST_SELECT_YN = 'Y' THEN A.SELECT_SEQ ELSE 1 END = 1
    )
    SELECT RT.VER_CD
    	,  RT.ITEM_CD
    	,  RT.ITEM_NM
    	,  RT.ACCOUNT_CD 
    	,  RT.ACCOUNT_NM
		,  RT.ENGINE_TP_CD		AS ENGINE_TP_CD 
		,  RT.ACCRY
		,  RT.BASE_DATE			AS "DATE"
		,  SUM(RT.QTY)			AS QTY
		,  SELECT_SEQ	
	  FROM RT
	GROUP BY RT.VER_CD
		  ,  RT.ITEM_CD 
		  ,  RT.ITEM_NM
		  ,  RT.ACCOUNT_CD 
		  ,  RT.ACCOUNT_NM
		  ,  RT.BASE_DATE
		  ,  RT.ENGINE_TP_CD
		  ,  RT.ACCRY
		  ,  SELECT_SEQ	 
	ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
    ;
END
;