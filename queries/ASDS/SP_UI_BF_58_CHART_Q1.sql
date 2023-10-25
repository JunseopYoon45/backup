CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_58_CHART_Q1" (
      p_ITEM_CD		VARCHAR2
    , p_ACCOUNT_CD	VARCHAR2
    , p_S_DATE		date
    , p_E_DATE		date
    , p_ITEM_LV_ID	VARCHAR2
    , p_ACCT_LV_ID	VARCHAR2
    , p_SUM			VARCHAR2 := 'Y'
    , pRESULT         OUT SYS_REFCURSOR
)IS
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_58_CHART_Q1
   * Purpose : 실적 분석 차트 조회
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
/*
		History (date / writer / comment)
		-- 2023.03.10 / Joonseo Oh / WK52 JOIN에서 DP_WK JOIN으로 변경 (판매실적보정과 동일)
							   	   / 판매실적보정 DRAG를 위해 ID까지 조회
	    -- 2023.07.03 / Junseop Yoon / 소분류 조회 시 해당하는 품목을 조회하는 옵션 추가 (p_SUM) 
 */
v_EXISTS_NUM INT :=0;

BEGIN

    IF (p_SUM = 'Y') THEN
    OPEN pRESULT FOR
    WITH IDS AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.DESCENDANT_NM AS DESC_NM
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
           AND IL.LV_MGMT_ID = p_ITEM_LV_ID
           AND IH.LEAF_YN = 'Y'
           AND ANCESTER_CD = p_ITEM_CD  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.DESCENDANT_NM AS DESC_NM
              ,IH.ANCESTER_CD 	AS ANCS_CD
              ,CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
         FROM TB_DPD_ITEM_HIER_CLOSURE IH
              INNER JOIN
              TB_CM_ITEM_MST IT
           ON IH.ANCESTER_ID = IT.ID 
        WHERE 1=1
          AND IH.LEAF_YN = 'Y'
          AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV_ID) THEN 0 ELSE 1 END
          AND ANCESTER_CD = p_ITEM_CD  
    )
    , ADS AS (
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.DESCENDANT_NM AS DESC_NM
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,SL.SALES_LV_NM 	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_SALES_LEVEL_MGMT SL 
           ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_ACCT_LV_ID
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_ACCOUNT_CD||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.DESCENDANT_NM AS DESC_NM
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,AM.ACCOUNT_NM	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_ACCOUNT_MST AM 
           ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_ACCT_LV_ID) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_ACCOUNT_CD||'%'  
	)
	, LEAF_RAW_DATA AS (
			--SELECT  /*+ INDEX(S IDX_IDX_ACTUAL_SALES_T_01) */
            SELECT  /*+ FULL(SA) */
		 			  SA.BASE_DATE     	AS BASE_DATE
					, I.ANCS_CD      	AS PA_ITEM_CD
					, A.ANCS_CD   		AS PA_ACCOUNT_CD
					, I.DESC_CD         AS ITEM_CD
					, I.DESC_NM			AS ITEM_NM
					, A.DESC_CD         AS ACCOUNT_CD
					, A.DESC_NM		 	AS ACCOUNT_NM
					, CASE WHEN SA.CORRECTION_YN = 'Y'
					  	THEN SA.QTY_CORRECTION
						ELSE SA.QTY END AS QTY
					, SA.QTY 			AS QTY_ACTUAL
					, CASE WHEN SA.CORRECTION_YN = 'Y'
					  	THEN SA.AMT_CORRECTION
						ELSE SA.AMT END AS AMT
					, SA.AMT			AS AMT_ACTUAL
					, (SELECT MIN(SA.BASE_DATE) OVER(PARTITION BY I.ANCS_CD, A.ANCS_CD, CA.DP_WK ORDER BY SA.BASE_DATE) FROM DUAL) AS MIN_DATE --SCALAR SUBQUERY
	                , SA.ID
	                , NVL(R.CONF_CD, 'NN') AS CORRECTION_COMMENT
	                , SA.MODIFY_BY
	                , SA.MODIFY_DTTM
			FROM TB_CM_ACTUAL_SALES SA
			INNER JOIN ADS A
				ON A.DESC_ID = SA.ACCOUNT_ID
			INNER JOIN IDS I
				ON I.DESC_ID = SA.ITEM_MST_ID
			INNER JOIN TB_CM_CALENDAR CA
				ON SA.BASE_DATE = CA.DAT
	        LEFT OUTER JOIN TB_CM_COMM_CONFIG R
	            ON SA.CORRECTION_COMMENT_ID = R.ID
			WHERE SA.BASE_DATE BETWEEN p_S_DATE AND p_E_DATE
		), 
	    BASE_CAL AS (
			SELECT DAT
	             , YYYY
	             , QTR
	             , CONCAT(CONCAT(YYYY, ' '), QTR_NM) AS YYYYQTR
				 , YYYYMM
	             , MM
				 , DOW
				 , WK52
				 , DP_WK
	             , CAST(TO_CHAR(dat, 'IW') AS VARCHAR(2)) AS ISO_WK
			FROM TB_CM_CALENDAR
			WHERE DAT BETWEEN p_S_DATE AND p_E_DATE
		),
		MON_DATE AS (
            SELECT
                   AA.PA_ACCOUNT_CD
				 , AA.ACCOUNT_NM
				 , AA.ACCOUNT_ID
				 , BB.PA_ITEM_CD
				 , BB.ITEM_NM
				 , BB.ITEM_ID
				 , AA.DAT
				 , AA.YYYY
				 , AA.QTR
				 , AA.YYYYQTR
				 , AA.YYYYMM
				 , AA.MM
				 , AA.DOW
				 , AA.WK52
				 , AA.DP_WK
				 , AA.ISO_WK
			FROM (SELECT 
			             A.ANCS_CD 	AS PA_ACCOUNT_CD
				       , MIN(A.ANCS_NM) ACCOUNT_NM
				       , MIN(A.DESC_ID) ACCOUNT_ID
			           , MIN(DAT) DAT
				       , MIN(YYYY) YYYY
				       , MIN(QTR) QTR
				       , MIN(CONCAT(CONCAT(YYYY, ' '), QTR_NM)) AS YYYYQTR
				       , MIN(YYYYMM) YYYYMM
				       , MIN(MM) MM
				       , MIN(DOW) DOW
				       , MIN(WK52) WK52
				       , DP_WK
				       , MIN(CAST(TO_CHAR(DAT, 'IW') AS VARCHAR(2))) AS ISO_WK
				    FROM TB_CM_CALENDAR CA 
					CROSS JOIN ADS A
        			WHERE DAT BETWEEN p_S_DATE AND p_E_DATE
				   GROUP BY A.ANCS_CD, DP_WK) AA,
                  (SELECT 
				         I.ANCS_CD 	AS PA_ITEM_CD
				       , MIN(I.ANCS_NM) ITEM_NM
				       , MIN(I.DESC_ID) ITEM_ID
			           , MIN(DAT) DAT
				       , MIN(YYYY) YYYY
				       , MIN(QTR) QTR
				       , MIN(CONCAT(CONCAT(YYYY, ' '), QTR_NM)) AS YYYYQTR
				       , MIN(YYYYMM) YYYYMM
				       , MIN(MM) MM
				       , MIN(DOW) DOW
				       , MIN(WK52) WK52
				       , DP_WK
				       , MIN(CAST(TO_CHAR(DAT, 'IW') AS VARCHAR(2))) AS ISO_WK
				    FROM TB_CM_CALENDAR CA 
			        CROSS JOIN IDS I
          			WHERE DAT BETWEEN p_S_DATE AND p_E_DATE
				   GROUP BY I.ANCS_CD, DP_WK) BB
			WHERE 1=1
			  AND AA.DAT       = BB.DAT
			  AND AA.YYYY      = BB.YYYY
			  AND AA.QTR       = BB.QTR
			  AND AA.YYYYQTR   = BB.YYYYQTR
			  AND AA.YYYYMM    = BB.YYYYMM
			  AND AA.MM        = BB.MM
			  AND AA.DOW       = BB.DOW
			  AND AA.WK52      = BB.WK52
			  AND AA.DP_WK     = BB.DP_WK
			  AND AA.ISO_WK    = BB.ISO_WK
		),

		SALES AS (
		SELECT MD.PA_ACCOUNT_CD 		AS ACCOUNT_CD
	    	   , MIN(MD.ACCOUNT_NM) 	AS ACCOUNT_NM
	           , MD.PA_ITEM_CD   		AS ITEM_CD
	           , MIN(MD.ITEM_NM) 		AS ITEM_NM
	           , MD.DAT 				AS BASE_DATE
	           , NVL(SUM(LRD.QTY), 0)   AS QTY
	           , NVL(SUM(LRD.QTY_ACTUAL), 0)   AS QTY_ACTUAL
	           , NVL(SUM(LRD.AMT), 0)	AS AMT
	           , MIN(MD.YYYY) 		    AS YYYY
	           , MIN(MD.YYYYQTR) 		AS YYYYQTR
	           , MIN(MD.QTR)     		AS QTR
	           , MIN(MD.MM)      		AS MM
	           , MIN(MD.DOW)     		AS DOW
	           , MIN(MD.DP_WK)     		AS DP_WK
	           , MIN(MD.WK52)    		AS WK52
	           , MIN(MD.YYYYMM)  		AS YYYYMM
	           , MIN(MD.ISO_WK)  		AS ISO_WK
	           , MIN(LRD.MIN_DATE)		   AS MIN_DATE
	    FROM LEAF_RAW_DATA LRD
	    INNER JOIN BASE_CAL CA
	    	ON LRD.BASE_DATE = CA.DAT
	    RIGHT JOIN MON_DATE MD 
	    	ON CA.DP_WK = MD.DP_WK 
	      		AND LRD.PA_ACCOUNT_CD = MD.PA_ACCOUNT_CD 
	      		AND LRD.PA_ITEM_CD = MD.PA_ITEM_CD
	    GROUP BY MD.PA_ACCOUNT_CD, MD.PA_ITEM_CD, MD.DAT
	    )
	    SELECT * FROM SALES
	    ORDER BY 1, 3, 5
	    ;
	COMMIT;

	ELSE
	OPEN pRESULT FOR
	WITH IDS AS (
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.DESCENDANT_NM AS DESC_NM
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
           AND IL.LV_MGMT_ID = p_ITEM_LV_ID
           AND IH.LEAF_YN = 'Y'
           AND ANCESTER_CD = p_ITEM_CD  
         UNION ALL
        SELECT IH.DESCENDANT_ID AS DESC_ID
              ,IH.DESCENDANT_CD AS DESC_CD
              ,IH.DESCENDANT_NM AS DESC_NM
              ,IH.ANCESTER_CD 	AS ANCS_CD
              ,CAST(IT.ITEM_NM 	AS VARCHAR2(255)) AS ANCS_NM
         FROM TB_DPD_ITEM_HIER_CLOSURE IH
              INNER JOIN
              TB_CM_ITEM_MST IT
           ON IH.ANCESTER_ID = IT.ID 
        WHERE 1=1
          AND IH.LEAF_YN = 'Y'
          AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV_ID) THEN 0 ELSE 1 END
          AND ANCESTER_CD = p_ITEM_CD  
    )
    , ADS AS (
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.DESCENDANT_NM AS DESC_NM
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,SL.SALES_LV_NM 	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_SALES_LEVEL_MGMT SL 
           ON SH.ANCESTER_ID = SL.ID 
         WHERE 1=1
           AND SL.LV_MGMT_ID = p_ACCT_LV_ID
           AND SH.LEAF_YN = 'Y' 
           AND ANCESTER_CD LIKE p_ACCOUNT_CD||'%'  
         UNION ALL
        SELECT SH.DESCENDANT_ID AS DESC_ID
              ,SH.DESCENDANT_CD AS DESC_CD
              ,SH.DESCENDANT_NM AS DESC_NM
              ,SH.ANCESTER_CD 	AS ANCS_CD
              ,AM.ACCOUNT_NM	AS ANCS_NM
         FROM TB_DPD_SALES_HIER_CLOSURE SH
              INNER JOIN 
              TB_DP_ACCOUNT_MST AM 
           ON SH.ANCESTER_ID = AM.ID
         WHERE 1=1
           AND SH.LEAF_YN = 'Y'
           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_ACCT_LV_ID) THEN 0 ELSE 1 END
           AND ANCESTER_CD LIKE p_ACCOUNT_CD||'%'  
		)
		, LEAF_RAW_DATA AS (
		   SELECT /*+ INDEX(S IDX_IDX_ACTUAL_SALES_T_01) */
           --SELECT 
		  		  SA.BASE_DATE     	AS BASE_DATE
		   		, I.ANCS_CD 		AS PA_ITEM_CD
				, A.ANCS_CD   		AS PA_ACCOUNT_CD
				, I.DESC_CD         AS ITEM_CD
				, I.DESC_NM			AS ITEM_NM
				, A.DESC_CD      	AS ACCOUNT_CD
				, A.DESC_NM 		AS ACCOUNT_NM
				, CASE WHEN SA.CORRECTION_YN = 'Y'
				  	THEN SA.QTY_CORRECTION
					ELSE SA.QTY END AS QTY
				, SA.QTY 			AS QTY_ACTUAL
				, CASE WHEN SA.CORRECTION_YN = 'Y'
				  	THEN SA.AMT_CORRECTION
					ELSE SA.AMT END AS AMT
				, SA.AMT			AS AMT_ACTUAL
				, CA.DP_WK
	            , SA.ID
	            , NVL(R.CONF_CD, 'NN') AS CORRECTION_COMMENT
	            , SA.MODIFY_BY
	            , SA.MODIFY_DTTM
		FROM TB_CM_ACTUAL_SALES SA
		INNER JOIN IDS I
			ON I.DESC_ID = SA.ITEM_MST_ID
		INNER JOIN ADS A
			ON A.DESC_ID = SA.ACCOUNT_ID
		INNER JOIN TB_CM_CALENDAR CA
			ON SA.BASE_DATE = CA.DAT
	    LEFT OUTER JOIN TB_CM_COMM_CONFIG R
	        ON SA.CORRECTION_COMMENT_ID = R.ID
			WHERE SA.BASE_DATE BETWEEN p_S_DATE AND p_E_DATE
	   ) 
	   , BASE_CAL AS (
			SELECT DAT
	             , YYYY
	             , QTR
	             , CONCAT(CONCAT(YYYY, ' '), QTR_NM) AS YYYYQTR
				 , YYYYMM
	             , MM
				 , DOW
				 , WK52
				 , DP_WK
	             , CAST(TO_CHAR(dat, 'IW') AS VARCHAR(2)) AS ISO_WK
			FROM TB_CM_CALENDAR
			WHERE DAT BETWEEN p_S_DATE AND p_E_DATE
		) 
		, MON_DATE AS (
			SELECT /*+ LEADING(A, I, CA) */
                   MIN(A.DESC_NM) ACCOUNT_NM
				 , MIN(A.DESC_ID) ACCOUNT_ID
				 , A.ANCS_CD AS ACCOUNT_CD
				 , MIN(I.DESC_NM) ITEM_NM
				 , MIN(I.DESC_ID) ITEM_ID
				 , I.DESC_CD AS ITEM_CD
				 , MIN(DAT) BASE_DATE
				 , MIN(YYYY) YYYY
				 , MIN(QTR) QTR
				 , MIN(CONCAT(CONCAT(YYYY, ' '), QTR_NM)) AS YYYYQTR
				 , MIN(YYYYMM) YYYYMM
				 , MIN(MM) MM
				 , MIN(DOW) DOW
				 , MIN(WK52) WK52
				 , DP_WK
				 , MIN(CAST(TO_CHAR(dat, 'IW') AS VARCHAR(2))) AS ISO_WK
			FROM TB_CM_CALENDAR CA
			CROSS JOIN ADS A
			CROSS JOIN IDS I
			WHERE DAT BETWEEN p_S_DATE AND p_E_DATE
			GROUP BY A.ANCS_CD, I.DESC_CD, DP_WK
		) 
		,
		SALES AS (
		SELECT MD.ACCOUNT_CD 		AS ACCOUNT_CD
	    	   , MD.ACCOUNT_NM 		AS ACCOUNT_NM
	           , MD.ITEM_CD   		AS ITEM_CD
	           , MD.ITEM_NM 		AS ITEM_NM
	           , MD.BASE_DATE 					AS BASE_DATE
	           , NVL(SUM(LRD.QTY), 0)   		AS QTY
	           , NVL(SUM(LRD.QTY_ACTUAL), 0)    AS QTY_ACTUAL
	           , NVL(SUM(LRD.AMT), 0)			AS AMT
	           , MIN(MD.YYYY)   	AS YYYY
	           , MIN(MD.YYYYQTR)	AS YYYYQTR
	           , MIN(MD.QTR) 		AS QTR
	           , MIN(MD.MM)	 		AS MM
	           , MIN(MD.DOW) 		AS DOW
	           , MIN(MD.DP_WK) 		AS DP_WK
	           , MIN(MD.WK52) 		AS WK52
	           , MIN(MD.YYYYMM) 	AS YYYYMM
	           , MIN(MD.ISO_WK) 	AS ISO_WK
	    FROM LEAF_RAW_DATA LRD
	    RIGHT JOIN MON_DATE MD 
	    	ON LRD.DP_WK = MD.DP_WK AND LRD.ITEM_CD = MD.ITEM_CD AND LRD.PA_ACCOUNT_CD = MD.ACCOUNT_CD
	    GROUP BY MD.ACCOUNT_CD, MD.ACCOUNT_NM, MD.ITEM_CD, MD.ITEM_NM, MD.BASE_DATE
	    )
	    SELECT * FROM SALES ORDER BY 1 DESC, 3, 5;

	END IF;

    COMMIT;

END;