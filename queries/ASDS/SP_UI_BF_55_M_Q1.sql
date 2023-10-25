CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_55_M_Q1" (
     p_VER_CD         VARCHAR2
	,p_ITEM_LV		  VARCHAR2 := NULL -- id 로 넘어옴
	,p_ITEM_CD		  VARCHAR2 := NULL
	,p_SALES_LV	      VARCHAR2 := NULL
	,p_SALES_CD		  VARCHAR2 := NULL
	,p_SRC_TP		  VARCHAR2 
	,p_SUM			  VARCHAR2 := 'Y'	
    ,pRESULT          OUT SYS_REFCURSOR
)IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_55_M_Q1
   * Purpose : 월 예측정확도 조회
   * Notes : 국내 - 1개월 정확도, 해외 - 3개월 정확도
   * 		 소싱 전체 선택 시 1개월까지는 국내 + 해외 실적, 예측값 비교
   * 		 2개월 부터는 해외 실적과 예측값 비교
   * 	M20180115092445697M411878346346N	ITEM_ALL	상품전체
		N20180115092528519N506441512113N	LEVEL1		대분류
		N20180115092559329M499525073971N	LEVEL2		중분류
		FA5FEBBCADDED90DE053DD0A10AC8DB5	LEVEL3		소분류
		M20180115092627169N446701842271O	ITEM		상품선택
		N20180115092712856O251735022591O	ALL			채널전체
		FE00001E54F88F3FE053DD0A10AC762B	CENTER		센터
		N20180115092710840N520475678180O	CHANNEL		채널선택
   **************************************************************************/
/*
DECLARE
	pRESULT SYS_REFCURSOR;
BEGIN
--	DWSCM.SP_UI_BF_55_M_Q1('BFM-20230901-01', 'M20180115092627169N446701842271O', '57451', 'N20180115092710840N520475678180O', '01_POS', 'KR', 'N', pRESULT);
	DWSCM.SP_UI_BF_55_M_Q1('BFM-20230901-01', 'FA5FEBBCADDED90DE053DD0A10AC8DB5', 'AC01', 'N20180115092710840N520475678180O', '', 'KR', 'N', pRESULT);
	DBMS_SQL.RETURN_RESULT(pRESULT);
END;
 */
	v_BUCKET 		VARCHAR2(2);
	v_EXISTS_NUM 	INT :=0;
	p_FROM_DATE 	DATE := NULL;
	p_TO_DATE_KR 	DATE := NULL;
	p_TO_DATE_FR 	DATE := NULL;
	v_SRC_TP		VARCHAR2(10) := NVL(p_SRC_TP, '');

BEGIN

	SELECT MAX(TARGET_FROM_DATE)
		 , MAX(TARGET_FROM_DATE)
		 , ADD_MONTHS(MAX(TARGET_FROM_DATE), 2)
	  INTO p_FROM_DATE
	  	 , p_TO_DATE_KR
	  	 , p_TO_DATE_FR
	  FROM TB_BF_CONTROL_BOARD_VER_DTL 
	 WHERE VER_CD = p_VER_CD;
	
    SELECT TARGET_BUKT_CD INTO v_BUCKET 
      FROM TB_BF_CONTROL_BOARD_VER_DTL WHERE 1=1 AND VER_CD = p_VER_CD AND ENGINE_TP_CD IS NOT NULL AND ROWNUM=1;

	SELECT CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 1 ELSE 0 END INTO v_EXISTS_NUM
    FROM DUAL;   	
   
    COMMIT;
	
    IF p_SUM = 'Y'
    THEN
    OPEN pRESULT FOR
    WITH IDS AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
             , IM.ATTR_03		AS SRC_TP
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM_CD  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
             , IT.ATTR_03		AS SRC_TP
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM_CD
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
           AND ANCESTER_CD LIKE p_SALES_CD||'%'
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
           AND ANCESTER_CD LIKE p_SALES_CD||'%'
    )
    , CAL AS (
        SELECT MIN(DAT)          AS FROM_DATE
             , MAX(DAT)          AS TO_DATE
             , MIN(YYYYMM)       AS YYYYMM
             , COUNT(DAT)        AS DAT_CNT
          FROM TB_CM_CALENDAR    
         WHERE DAT BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)
         GROUP BY YYYY, MM, TO_CHAR(DP_WK)
	)
    , ACT_SALES AS (
    	SELECT BASE_DATE
    		 , ITEM_CD
    		 , ACCOUNT_CD
    		 , SUM(QTY) AS QTY
    	  FROM (
    	   SELECT *
    	     FROM (
	        SELECT BASE_DATE
	 	 		 , IH.ANCS_CD 	AS ITEM_CD
	             , AH.ANCS_CD 	AS ACCOUNT_CD
	 	 		 , SUM(QTY) 	AS QTY
	 	 	 FROM TB_CM_ACTUAL_SALES_M_HIST S
			INNER JOIN ADS AH 
	           ON AH.DESC_ID = S.ACCOUNT_ID
	        INNER JOIN IDS IH 
	           ON IH.DESC_ID = S.ITEM_MST_ID
	 	 	WHERE VER_CD = p_VER_CD 
	 	 	  AND BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_KR)
	 	 	  AND SRC_TP = 'KR'
	 	 	  AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
                  	       WHEN v_SRC_TP = 'KR' THEN 1
                     	   ELSE 0 END 
	        GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE
	        )
	        UNION ALL
	        SELECT *
	          FROM (
	        SELECT BASE_DATE
	 	 		 , IH.ANCS_CD 	AS ITEM_CD
	             , AH.ANCS_CD 	AS ACCOUNT_CD
	 	 		 , SUM(QTY) 	AS QTY
	 	 	 FROM TB_CM_ACTUAL_SALES_M_HIST S
			INNER JOIN ADS AH 
	           ON AH.DESC_ID = S.ACCOUNT_ID
	        INNER JOIN IDS IH 
	           ON IH.DESC_ID = S.ITEM_MST_ID
	 	 	WHERE VER_CD = p_VER_CD 
	 	 	  AND BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)  
	 	 	  AND SRC_TP = 'FR'
	 	 	  AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
                  	       WHEN v_SRC_TP = 'FR' THEN 1
                     	   ELSE 0 END 
	        GROUP BY IH.ANCS_CD, AH.ANCS_CD, BASE_DATE
	        )
        )
       GROUP BY BASE_DATE, ITEM_CD, ACCOUNT_CD
    ) 
    , FINAL AS (
    	SELECT VER_CD
			 , ITEM_CD
			 , ITEM_NM
			 , ACCOUNT_CD
			 , ACCOUNT_NM
			 , BASE_DATE
			 , SUM(QTY) AS QTY 
			 , ENGINE_TP_CD
		  FROM (
		SELECT *
		  FROM (
	        SELECT p_VER_CD    AS VER_CD
	             , IH.ANCS_CD  AS ITEM_CD
	             , IH.ANCS_NM  AS ITEM_NM
	             , AH.ANCS_CD  AS ACCOUNT_CD
	             , AH.ANCS_NM  AS ACCOUNT_NM
	             , F.BASE_DATE AS BASE_DATE 
	             , SUM(F.QTY) 				AS QTY
	             , NULL AS ENGINE_TP_CD
	          FROM TB_BF_RT_FINAL_M F
	         INNER JOIN IDS IH 
	         	ON F.ITEM_CD = IH.DESC_CD
	         INNER JOIN ADS AH 
	         	ON F.ACCOUNT_CD = AH.DESC_CD
	         WHERE F.VER_CD = p_VER_CD 
	           AND F.BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_KR)
	           AND SRC_TP = 'KR'
	           AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
	                  	    WHEN v_SRC_TP = 'KR' THEN 1
	                     	ELSE 0 END 
	         GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, F.BASE_DATE
	         )
         UNION ALL
         SELECT *
           FROM (
	         SELECT p_VER_CD    AS VER_CD
	             , IH.ANCS_CD  AS ITEM_CD
	             , IH.ANCS_NM  AS ITEM_NM
	             , AH.ANCS_CD  AS ACCOUNT_CD
	             , AH.ANCS_NM  AS ACCOUNT_NM
	             , F.BASE_DATE AS BASE_DATE 
	             , SUM(F.QTY) 				AS QTY
	             , NULL AS ENGINE_TP_CD
	          FROM TB_BF_RT_FINAL_M F
	         INNER JOIN IDS IH 
	         	ON F.ITEM_CD = IH.DESC_CD
	         INNER JOIN ADS AH 
	         	ON F.ACCOUNT_CD = AH.DESC_CD
	         WHERE F.VER_CD = p_VER_CD 
	           AND F.BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)
	           AND SRC_TP = 'FR'
	           AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
	                  	    WHEN v_SRC_TP = 'FR' THEN 1
	                     	ELSE 0 END 
	         GROUP BY IH.ANCS_CD, IH.ANCS_NM, AH.ANCS_CD, AH.ANCS_NM, F.BASE_DATE
	         )
         )
         GROUP BY VER_CD, ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE, ENGINE_TP_CD
    ) 
    , WAPE AS (
        SELECT A.ITEM_CD
             , A.ITEM_CD 	AS ITEM_LV_CD
             , A.ITEM_NM 	AS ITEM_LV_NM
             , A.ACCOUNT_CD
             , A.ACCOUNT_CD AS ACCT_LV_CD
             , A.ACCOUNT_NM AS ACCT_LV_NM
             , A.BASE_DATE
             -- 예측
             , A.QTY PREDICT
             -- 실적
--             , B.QTY ACT_SALES
             , CASE WHEN A.BASE_DATE <= TRUNC(SYSDATE, 'MM') THEN NVL(B.QTY, 0)
             		ELSE NULL END ACT_SALES
             -- 개별정확도
             , CASE WHEN ABS(A.QTY - NVL(B.QTY, 0)) = 0 THEN 100 
             		ELSE (CASE WHEN (1-ABS(A.QTY-B.QTY)/B.QTY) >= 0 THEN (1-ABS(A.QTY-B.QTY)/B.QTY)*100 ELSE 0 END) END WAPE
			 , NULL 		AS ENGINE_TP_CD
			 , CASE WHEN A.BASE_DATE <= TRUNC(SYSDATE, 'MM') THEN ABS(A.QTY - NVL(B.QTY, 0)) 
             		ELSE ABS(A.QTY - B.QTY) END AS ERR
          FROM FINAL A
          LEFT JOIN ACT_SALES B 
          	ON A.ITEM_CD = B.ITEM_CD 
           AND A.ACCOUNT_CD = B.ACCOUNT_CD 
           AND A.BASE_DATE = B.BASE_DATE
    )
    , WAPE2 AS (
    	SELECT A.ITEM_LV_CD
    		 , A.ITEM_LV_NM
    		 , A.ACCT_LV_CD
    		 , A.ACCT_LV_NM
    		 , BASE_DATE
    		 , PREDICT
    		 , ACT_SALES
    		 , WAPE
    		 , ENGINE_TP_CD
    		 , ACCRY
    	FROM WAPE A
    	INNER JOIN (SELECT ITEM_LV_CD
    					 , ITEM_LV_NM
    					 , ACCT_LV_CD
    					 , ACCT_LV_NM
    					 , CASE WHEN SUM(PREDICT - ACT_SALES) = 0 THEN '100%'
                                WHEN (1 - SUM(ERR) / (SUM(ACT_SALES) + 0.00001)) * 100 <= 0 THEN '0%'                    
                                ELSE RTRIM(TO_CHAR(ROUND(100 - (SUM(ERR)  / (SUM(ACT_SALES) + 0.00001)) * 100, 1)), TO_CHAR(0, 'D')) ||'%' END ACCRY
					  FROM WAPE
				     GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM) B
			ON A.ITEM_LV_CD = B.ITEM_LV_CD AND A.ITEM_LV_NM = B.ITEM_LV_NM AND A.ACCT_LV_CD = B.ACCT_LV_CD AND A.ACCT_LV_NM = B.ACCT_LV_NM
    )
    , RT_ACCRY AS (
		SELECT ITEM_LV_CD				  AS ITEM
			 , ITEM_LV_NM				  AS ITEM_NM
			 , ACCT_LV_CD				  AS SALES
			 , ACCT_LV_NM				  AS ACCT_NM
			 , NULL 				 	  AS ENGINE_TP_CD
			 , 'ACT_SALES_QTY' 			  AS CATEGORY
			 , ACCRY 			 		  AS TOTAL_ACCRY
			 , BASE_DATE 				  AS "DATE"
			 , CAST(FLOOR(SUM(ACT_SALES)) AS VARCHAR2(1000)) ACCRY
			 , 1						  AS ORDER_VAL
		  FROM WAPE2
		 GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, ACCRY, BASE_DATE
		 UNION 
		SELECT ITEM_LV_CD				AS ITEM
			 , ITEM_LV_NM				AS ITEM_NM
			 , ACCT_LV_CD				AS SALES
			 , ACCT_LV_NM				AS ACCT_NM
 			 , NULL 				 	AS ENGINE_TP_CD
			 , 'BF_QTY'				    AS CATEGORY
			 , ACCRY 			 		AS TOTAL_ACCRY
			 , BASE_DATE 			    AS "DATE"
			 , CAST(FLOOR(SUM(PREDICT)) AS VARCHAR2(1000)) ACCRY
			 , 2					    AS ORDER_VAL
		  FROM WAPE2
		 GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, ACCRY, BASE_DATE
		 UNION
		SELECT ITEM_LV_CD			 AS ITEM
			 , ITEM_LV_NM			 AS ITEM_NM
			 , ACCT_LV_CD 			 AS SALES
			 , ACCT_LV_NM 			 AS ACCT_NM
 			 , NULL 		   	     AS ENGINE_TP_CD		 
			 , 'DMND_PRDICT_ACCURCY' AS CATEGORY
			 , ACCRY 			 	 AS TOTAL_ACCRY
			 , BASE_DATE 		     AS "DATE"
			 , CASE WHEN SUM(PREDICT - ACT_SALES) = 0 THEN '100%'
              		WHEN SUM(ACT_SALES) IS NULL THEN NULL
                    WHEN (1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / (SUM(ACT_SALES) + 0.00001)) * 100 <= 0 THEN '0%'
                    ELSE RTRIM(TO_CHAR(ROUND((1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / (SUM(ACT_SALES) + 0.00001)) * 100, 1)), TO_CHAR(0, 'D')) || '%' END ACCRY
			 , 3					 AS ORDER_VAL
		FROM WAPE2
		GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, ACCRY, BASE_DATE
    )
    SELECT * FROM RT_ACCRY
     ORDER BY ITEM, SALES, "DATE", ORDER_VAL;
    
    COMMIT;    
   
    ELSE
    OPEN pRESULT FOR
    WITH IDS AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , IL.ITEM_LV_NM 	AS ANCS_NM
             , IM.ATTR_03		AS SRC_TP
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_LEVEL_MGMT IL 
         	ON IH.ANCESTER_ID = IL.ID
         INNER JOIN TB_CM_ITEM_MST IM 
         	ON IH.DESCENDANT_CD = IM.ITEM_CD
         WHERE 1=1
           AND IL.LV_MGMT_ID = p_ITEM_LV
           AND IH.LEAF_YN = 'Y'
           AND IM.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM_CD  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
             , IH.DESCENDANT_CD AS DESC_CD
             , IH.DESCENDANT_NM AS DESC_NM
             , IH.ANCESTER_CD 	AS ANCS_CD
             , CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
             , IT.ATTR_03		AS SRC_TP
          FROM TB_DPD_ITEM_HIER_CLOSURE IH
         INNER JOIN TB_CM_ITEM_MST IT 
        	ON IH.ANCESTER_ID = IT.ID 
         WHERE 1=1
           AND IH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
           AND IT.ATTR_03 LIKE v_SRC_TP||'%'
           AND ANCESTER_CD = p_ITEM_CD
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
           AND ANCESTER_CD LIKE p_SALES_CD||'%'
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
           AND ANCESTER_CD LIKE p_SALES_CD||'%'
    )
	, CAL AS (
        SELECT MIN(DAT)			AS FROM_DATE
             , MAX(DAT)         AS TO_DATE
             , MIN(YYYYMM)      AS YYYYMM
             , COUNT(DAT)       AS DAT_CNT
          FROM TB_CM_CALENDAR
         WHERE DAT BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)
         GROUP BY YYYY, DP_WK, TO_CHAR(DP_WK)
	)
    , ACT_SALES AS (
    	SELECT BASE_DATE
    		 , ITEM_CD
    		 , ACCOUNT_CD
    		 , SUM(QTY) AS QTY
    	  FROM (
	        SELECT BASE_DATE
	 	 		 , IH.DESC_CD 	AS ITEM_CD
	             , AH.DESC_CD 	AS ACCOUNT_CD
	 	 		 , SUM(QTY) 	AS QTY
	 	 	 FROM TB_CM_ACTUAL_SALES_M_HIST S 
			INNER JOIN ADS AH 
	           ON AH.DESC_ID = S.ACCOUNT_ID
	        INNER JOIN IDS IH 
	           ON IH.DESC_ID = S.ITEM_MST_ID
	 	 	WHERE VER_CD = p_VER_CD 
	 	 	  AND BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_KR)         
	 	 	  AND SRC_TP = 'KR'
	 	 	  AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
                  	       WHEN v_SRC_TP = 'KR' THEN 1
                     	   ELSE 0 END 
	        GROUP BY IH.DESC_CD, AH.DESC_CD, BASE_DATE
	        UNION ALL
	        SELECT BASE_DATE
	 	 		 , IH.DESC_CD 	AS ITEM_CD
	             , AH.DESC_CD 	AS ACCOUNT_CD
	 	 		 , SUM(QTY) 	AS QTY
	 	 	 FROM TB_CM_ACTUAL_SALES_M_HIST S 
			INNER JOIN ADS AH 
	           ON AH.DESC_ID = S.ACCOUNT_ID
	        INNER JOIN IDS IH 
	           ON IH.DESC_ID = S.ITEM_MST_ID
	 	 	WHERE VER_CD = p_VER_CD 
	 	 	  AND BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)
	 	 	  AND SRC_TP = 'FR'
	 	 	  AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
                  	       WHEN v_SRC_TP = 'FR' THEN 1
                     	   ELSE 0 END 
	        GROUP BY IH.DESC_CD, AH.DESC_CD, BASE_DATE
	        )
	        GROUP BY ITEM_CD, ACCOUNT_CD, BASE_DATE
    ) 
	, FINAL AS (
		SELECT VER_CD
			 , ITEM_CD
			 , ITEM_NM
			 , ACCOUNT_CD
			 , ACCOUNT_NM
			 , BASE_DATE
			 , SUM(QTY) AS QTY 
			 , ENGINE_TP_CD
		  FROM (
	        SELECT p_VER_CD 				AS VER_CD
	             , IH.DESC_CD 				AS ITEM_CD
	             , IH.DESC_NM				AS ITEM_NM
	             , AH.DESC_CD 				AS ACCOUNT_CD
	             , AH.DESC_NM 				AS ACCOUNT_NM    
	             , F.BASE_DATE 				AS BASE_DATE
	             , SUM(F.QTY) 				AS QTY
	             , MIN(F.BEST_ENGINE_TP_CD) AS ENGINE_TP_CD
	          FROM TB_BF_RT_FINAL_M F
	         INNER JOIN IDS IH 
	         	ON F.ITEM_CD = IH.DESC_CD
	         INNER JOIN ADS AH 
	         	ON F.ACCOUNT_CD = AH.DESC_CD
	         WHERE F.VER_CD = p_VER_CD 
	           AND F.BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_KR)
	           AND SRC_TP = 'KR'
	           AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
	                  	    WHEN v_SRC_TP = 'KR' THEN 1
	                     	ELSE 0 END 
	         GROUP BY IH.DESC_CD, IH.DESC_NM, AH.DESC_CD, AH.DESC_NM, F.BASE_DATE
	         UNION ALL
	        SELECT p_VER_CD 				AS VER_CD
	             , IH.DESC_CD 				AS ITEM_CD
	             , IH.DESC_NM				AS ITEM_NM
	             , AH.DESC_CD 				AS ACCOUNT_CD
	             , AH.DESC_NM 				AS ACCOUNT_NM    
	             , F.BASE_DATE 				AS BASE_DATE
	             , SUM(F.QTY) 				AS QTY
	             , MIN(F.BEST_ENGINE_TP_CD) AS ENGINE_TP_CD
	          FROM TB_BF_RT_FINAL_M F
	         INNER JOIN IDS IH 
	         	ON F.ITEM_CD = IH.DESC_CD
	         INNER JOIN ADS AH 
	         	ON F.ACCOUNT_CD = AH.DESC_CD
	         WHERE F.VER_CD = p_VER_CD 
	           AND F.BASE_DATE BETWEEN p_FROM_DATE AND LAST_DAY(p_TO_DATE_FR)
	           AND SRC_TP = 'FR'
	           AND 1 = CASE WHEN v_SRC_TP IS NULL THEN 1
	                  	    WHEN v_SRC_TP = 'FR' THEN 1
	                     	ELSE 0 END 
	         GROUP BY IH.DESC_CD, IH.DESC_NM, AH.DESC_CD, AH.DESC_NM, F.BASE_DATE
         )
         GROUP BY VER_CD, ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE, ENGINE_TP_CD
    ) 
    , WAPE AS (
        SELECT A.ITEM_CD
             , A.ITEM_NM
             , A.ACCOUNT_CD
             , A.ACCOUNT_NM
             , A.BASE_DATE
             -- 예측
             , A.QTY PREDICT
             -- 실적
             , CASE WHEN A.BASE_DATE <= TRUNC(SYSDATE, 'MM') THEN NVL(B.QTY, 0)
             		ELSE NULL END ACT_SALES             
             -- 개별정확도
             , CASE WHEN ABS(A.QTY - NVL(B.QTY, 0)) = 0 THEN 100 
             		ELSE (CASE WHEN (1-ABS(A.QTY-B.QTY)/(B.QTY + 0.00001)) >= 0 THEN (1-ABS(A.QTY-B.QTY)/(B.QTY + 0.00001))*100 ELSE 0 END) END WAPE
			 , A.ENGINE_TP_CD
			 , CASE WHEN A.BASE_DATE <= TRUNC(SYSDATE, 'MM') THEN ABS(A.QTY - NVL(B.QTY, 0)) 
             		ELSE ABS(A.QTY - B.QTY) END AS ERR
          FROM FINAL A
          LEFT JOIN ACT_SALES B 
          	ON A.ITEM_CD = B.ITEM_CD
           AND A.ACCOUNT_CD = B.ACCOUNT_CD
           AND A.BASE_DATE = B.BASE_DATE
    )
    , WAPE2 AS (
    	SELECT A.ITEM_CD
    		 , A.ITEM_NM
    		 , A.ACCOUNT_CD
    		 , A.ACCOUNT_NM
    		 , BASE_DATE
    		 , PREDICT
    		 , ACT_SALES
    		 , WAPE
    		 , ENGINE_TP_CD
    		 , ACCRY
    	FROM WAPE A
    	INNER JOIN (SELECT ITEM_CD
    					 , ITEM_NM
    					 , ACCOUNT_CD
    					 , ACCOUNT_NM
    					 , CASE WHEN SUM(PREDICT - ACT_SALES) = 0 THEN '100%'
                                WHEN (1 - SUM(ERR) / (SUM(ACT_SALES) + 0.00001)) * 100 <= 0 THEN '0%'                    
                                ELSE RTRIM(TO_CHAR(ROUND(100 - (SUM(ERR)  / (SUM(ACT_SALES) + 0.00001)) * 100, 1)), TO_CHAR(0, 'D')) ||'%' END ACCRY
					  FROM WAPE
				     GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM) B
			ON A.ITEM_CD = B.ITEM_CD AND A.ITEM_NM = B.ITEM_NM AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
    )    
 	, RT_ACCRY AS (
		SELECT ITEM_CD 					  AS ITEM
			 , ITEM_NM
			 , ACCOUNT_CD 				  AS SALES
			 , ACCOUNT_NM 			 	  AS ACCT_NM
			 , MIN(ENGINE_TP_CD)		  AS ENGINE_TP_CD
			 , 'ACT_SALES_QTY' 			  AS CATEGORY
			 , ACCRY 			 		  AS TOTAL_ACCRY
			 , BASE_DATE 				  AS "DATE"
			 , CAST(FLOOR(SUM(ACT_SALES)) AS VARCHAR2(1000)) AS ACCRY
			 , 1 						  AS ORDER_VAL
		  FROM WAPE2
		 GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, ACCRY, BASE_DATE
		 UNION 
		SELECT ITEM_CD 					AS ITEM
			 , ITEM_NM 
			 , ACCOUNT_CD 				AS SALES
			 , ACCOUNT_NM 				AS ACCT_NM
			 , MIN(ENGINE_TP_CD) 		AS ENGINE_TP_CD
			 , 'BF_QTY' 				AS CATEGORY
			 , ACCRY 			 		AS TOTAL_ACCRY
			 , BASE_DATE 				AS "DATE"
			 , CAST(FLOOR(SUM(PREDICT)) AS VARCHAR2(1000)) ACCRY
			 , 2 						AS ORDER_VAL
		  FROM WAPE2
		 GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, ACCRY, BASE_DATE
		 UNION
		SELECT ITEM_CD 				 AS ITEM
			 , ITEM_NM 				 AS ITEM_NM
			 , ACCOUNT_CD 			 AS SALES
			 , ACCOUNT_NM 			 AS ACCT_NM
			 , MIN(ENGINE_TP_CD) 	 AS ENGINE_TP_CD
			 , 'DMND_PRDICT_ACCURCY' AS CATEGORY
			 , ACCRY 			 	 AS TOTAL_ACCRY
			 , BASE_DATE 			 AS "DATE"
			 , CASE WHEN SUM(PREDICT - ACT_SALES) = 0 THEN '100%'
              		WHEN SUM(ACT_SALES) IS NULL THEN NULL
                    WHEN (1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / (SUM(ACT_SALES) + 0.00001)) * 100 <= 0 THEN '0%'
                    ELSE RTRIM(TO_CHAR(ROUND((1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / (SUM(ACT_SALES) + 0.00001)) * 100, 1)), TO_CHAR(0, 'D')) || '%' END ACCRY
			 , 3 					 AS ORDER_VAL
		  FROM WAPE2
		 GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, ACCRY, BASE_DATE
    )
    SELECT * FROM RT_ACCRY
     ORDER BY ITEM, SALES, "DATE", ORDER_VAL;
    
    COMMIT;
    
    END IF;

END;