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
    p_SUM				VARCHAR2 := 'Y',
    pRESULT             OUT SYS_REFCURSOR
)IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_50_M_Q1
   * Purpose : 월 단위 수요예측 결과 그리드 조회
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
    
    /* 합계 조회 O, BEST SELECT N, 소분류 이상 조건 */
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
        SELECT B.ITEM_CD
        	 , B.ITEM_NM
             , B.ACCOUNT_CD
             , B.ACCOUNT_NM
             , B.BASE_DATE
		     , 'FCST' AS ENGINE_TP_CD		
			 , NULL AS ACCRY
			 , '1' AS SELECT_SEQ
             , SUM(QTY) AS QTY 
             , B.VER_CD 
          FROM (SELECT IH.ANCS_CD AS ITEM_CD
					 , IH.ANCS_NM AS ITEM_NM
					 , IH.DESC_CD AS ITEM_DESC
					 , AH.ANCS_CD AS ACCOUNT_CD
					 , AH.ANCS_NM AS ACCOUNT_NM
					 , AH.DESC_CD AS ACCOUNT_DESC
					 , BASE_DATE
					 , QTY
					 , RT.BEST_ENGINE_TP_CD AS ENGINE_TP_CD
					 , RT.VER_CD
				  FROM TB_BF_RT_FINAL_M RT
				 INNER JOIN IDS IH 
				 	ON IH.DESC_CD = RT.ITEM_CD
				 INNER JOIN ADS AH 
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
	ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD;

    COMMIT;
   
    /* 합계 조회 O, BEST SELECT N, 소분류 이상 조건 */
	ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N' AND v_EXISTS_NUM = 1
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
			 , IH.ANCS_NM AS ITEM_NM
			 , AH.ANCS_CD AS ACCOUNT_CD
			 , AH.ANCS_NM AS ACCOUNT_NM
			 , BASE_DATE
			 , ENGINE_TP_CD 
			 , NULL AS ACCRY
			 , NULL AS SELECT_SEQ
             , SUM(QTY)   AS QTY
             , VER_CD
		  FROM TB_BF_RT_M RT 
		 INNER JOIN IDS IH 
			ON IH.DESC_CD = RT.ITEM_CD
		 INNER JOIN ADS AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD		
		 WHERE 1=1
		   AND VER_CD = p_VER_CD 
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
		   AND IH.ANCS_CD = p_ITEM
		   AND AH.ANCS_CD LIKE p_SALES||'%'
		 GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, BASE_DATE, ENGINE_TP_CD, VER_CD
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
	 ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
    ;
   COMMIT;
   
   /* 합계 조회 O, BEST SELECT N, 센터 이상 조건*/
   ELSIF p_SUM = 'Y' AND p_BEST_SELECT_YN = 'N' AND v_EXISTS_NUM = 0
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
			 , IH.ANCS_NM AS ITEM_NM
			 , AH.ANCS_CD AS ACCOUNT_CD
			 , AH.ANCS_NM AS ACCOUNT_NM
			 , BASE_DATE
			 , RT.ENGINE_TP_CD
			 , NULL 	  AS ACCRY
			 , NULL 	  AS SELECT_SEQ
			 , SUM(QTY)   AS QTY 
			 , p_VER_CD   AS VER_CD
		  FROM TB_BF_RT_M RT 
		 INNER JOIN IDS IH 
		 	ON IH.DESC_CD = RT.ITEM_CD
		 INNER JOIN ADS AH 
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
        SELECT IH.ANCS_CD 	AS ITEM_CD
			 , IH.ANCS_NM 	AS ITEM_NM
			 , AH.ANCS_CD 	AS ACCOUNT_CD
			 , AH.ANCS_NM 	AS ACCOUNT_NM
			 , BASE_DATE
			 , 'FCST' 		AS ENGINE_TP_CD
			 , NULL 		AS ACCRY
			 , '1' 			AS SELECT_SEQ
			 , SUM(QTY) 	AS QTY 
			 , p_VER_CD 	AS VER_CD
		  FROM TB_BF_RT_FINAL_M RT 
		 INNER JOIN IDS IH 
		 	ON IH.DESC_CD = RT.ITEM_CD
		 INNER JOIN ADS AH 
		 	ON AH.DESC_CD = RT.ACCOUNT_CD
		 WHERE 1=1 
		   AND VER_CD = p_VER_CD
		   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
		   AND IH.ANCS_CD = p_ITEM
		   AND AH.ANCS_CD LIKE p_SALES||'%'
		 GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, BASE_DATE
	)				 
    SELECT p_VER_CD  AS VER_CD
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
	 ORDER BY RT.ACCOUNT_CD, RT.ITEM_CD
	;
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
        SELECT /*+ FULL(A) */
		       B.ITEM_CD
        	 , B.ITEM_NM
             , B.ACCOUNT_CD
             , B.ACCOUNT_NM
             , B.BASE_DATE
             , B.ENGINE_TP_CD	
             , WAPE AS ACCRY
			 , A.SELECT_SEQ
             , QTY 
             , B.VER_CD 
          FROM (SELECT /*+ FULL(RT) */
			           VER_CD
					 , IH.DESC_CD AS ITEM_CD
					 , IH.DESC_NM AS ITEM_NM
					 , AH.DESC_CD AS ACCOUNT_CD
					 , AH.DESC_NM AS ACCOUNT_NM
					 , BASE_DATE
					 , SUM(QTY) AS QTY
					 , ENGINE_TP_CD 
				  FROM TB_BF_RT_M RT
				 INNER JOIN IDS IH 
				 	ON IH.DESC_CD = RT.ITEM_CD
				 INNER JOIN ADS AH
				 	ON AH.DESC_CD = RT.ACCOUNT_CD
				 WHERE VER_CD = p_VER_CD
				   AND BASE_DATE BETWEEN p_FROM_DATE AND p_TO_DATE
				   AND AH.ANCS_CD LIKE p_SALES||'%'
				   AND IH.ANCS_CD = p_ITEM
				 GROUP BY VER_CD, IH.DESC_CD, IH.DESC_NM, AH.DESC_CD, AH.DESC_NM, BASE_DATE, ENGINE_TP_CD
				) B
          LEFT JOIN TB_BF_RT_ACCRCY_M A
            ON A.ITEM_CD = B.ITEM_CD 
           AND A.ACCOUNT_CD = B.ACCOUNT_CD 
           AND A.VER_CD = B.VER_CD 
           AND A.ENGINE_TP_CD = B.ENGINE_TP_CD		  		   		  
         WHERE B.VER_CD = p_VER_CD
           AND CASE WHEN p_BEST_SELECT_YN = 'Y' THEN A.SELECT_SEQ ELSE 1 END = 1
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
   
	END IF;
END
;