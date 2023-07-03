CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_55_Q1_TEST"(
     p_VER_CD         VARCHAR2
	,p_FROM_DATE	  DATE := NULL
	,p_TO_DATE		  DATE := NULL
	,p_ITEM_LV		  VARCHAR2 := NULL -- id 로 넘어옴
	,p_ITEM_CD		  VARCHAR2 := NULL
	,p_SALES_LV	      VARCHAR2 := NULL
	,p_ACCT_CD		  VARCHAR2 := NULL
	,p_GRADE		  VARCHAR2 :='N'
	,p_ITEM_ATTR1	  VARCHAR2 := NULL
	,p_ITEM_ATTR2	  VARCHAR2 := NULL
	,p_ITEM_ATTR3	  VARCHAR2 := NULL
	,p_ACCT_ATTR1	  VARCHAR2 := NULL
	,p_ACCT_ATTR2	  VARCHAR2 := NULL
	,p_ACCT_ATTR3	  VARCHAR2 := NULL
--	,p_SUM			  VARCHAR2 := 'Y'
    ,pRESULT          OUT SYS_REFCURSOR
)IS 

v_TO_DATE date:='';
v_BUCKET VARCHAR2(2);
v_EXISTS_NUM INT :=0;
p_SUM VARCHAR2(10) := 'N';

BEGIN

    v_TO_DATE := p_TO_DATE;
    SELECT TARGET_BUKT_CD INTO v_BUCKET 
      FROM TB_BF_CONTROL_BOARD_VER_DTL WHERE 1=1 AND VER_CD = p_VER_CD AND ENGINE_TP_CD IS NOT NULL AND ROWNUM=1;

    IF (v_BUCKET = 'M' AND p_SUM = 'Y')
    THEN
        OPEN pRESULT FOR
        WITH ITEM_HIER AS (
                SELECT IH.DESCENDANT_ID AS DESC_ID
                      ,IH.DESCENDANT_CD AS DESC_CD
                      ,IH.ANCESTER_CD AS ANCS_CD
                      ,IL.ITEM_LV_NM AS ANCS_NM
                      ,IM.ATTR_05 AS GRADE
                 FROM TB_DPD_ITEM_HIER_CLOSURE IH
                      INNER JOIN
                      tb_cm_item_level_mgmt IL
                   ON IH.ANCESTER_ID = IL.ID
                      INNER JOIN
                      TB_CM_ITEM_MST IM
                   ON IH.DESCENDANT_CD = IM.ITEM_CD
                 WHERE 1=1
                   AND IL.lv_mgmt_id = p_ITEM_LV
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ITEM_CD IS NULL
                       )
                   AND IH.LEAF_YN = 'Y'
                 UNION ALL
                SELECT IH.DESCENDANT_ID AS DESC_ID
                      ,IH.DESCENDANT_CD AS DESC_CD
                      ,IH.ANCESTER_CD AS ANCS_CD
                      ,CAST(IT.ITEM_NM AS VARCHAR2(255)) AS ANCS_NM
                      ,IT.ATTR_05
                 FROM TB_DPD_ITEM_HIER_CLOSURE IH
                      INNER JOIN
                      TB_CM_ITEM_MST IT
                   ON IH.ANCESTER_ID = IT.ID 
                WHERE 1=1
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ITEM_CD IS NULL
                       )
                  AND IH.LEAF_YN = 'Y'
                  AND 1 = CASE WHEN EXISTS (SELECT 1 FROM tb_cm_item_level_mgmt WHERE lv_mgmt_id = p_ITEM_LV) THEN 0 ELSE 1 END
        )
        , ACCT_HIER AS (
                SELECT SH.DESCENDANT_ID AS DESC_ID
                      ,SH.DESCENDANT_CD AS DESC_CD
                      ,SH.ANCESTER_CD AS ANCS_CD
                      ,SL.SALES_LV_NM AS ANCS_NM
                 FROM TB_DPD_SALES_HIER_CLOSURE SH
                      INNER JOIN 
                      TB_DP_SALES_LEVEL_MGMT SL 
                   ON SH.ANCESTER_ID = SL.ID 
                 WHERE 1=1
                   AND SL.LV_MGMT_ID = p_SALES_LV
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ACCT_CD IS NULL
                       )
                   AND SH.LEAF_YN = 'Y' 
                 UNION ALL
                SELECT SH.DESCENDANT_ID
                      ,SH.DESCENDANT_CD
                      ,SH.ANCESTER_CD
                      ,AM.ACCOUNT_NM
                 FROM TB_DPD_SALES_HIER_CLOSURE SH
                      INNER JOIN 
                      TB_DP_ACCOUNT_MST AM 
                   ON SH.ANCESTER_ID = AM.ID
                 WHERE 1=1
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ACCT_CD IS NULL
                       )
                   AND SH.LEAF_YN = 'Y'
                   AND 1 = CASE WHEN EXISTS (SELECT 1 FROM tb_dp_sales_level_mgmt WHERE lv_mgmt_id = p_SALES_LV) THEN 0 ELSE 1 END
        )
        , ACT_SALES AS (
            SELECT AM.ACCOUNT_CD
                    , AM.ACCOUNT_NM
                    , IM.ITEM_CD
                    , IM.ITEM_NM
                    , TO_CHAR(S.BASE_DATE,'YYYY-MM') BASE_DATE
                    , SUM(S.QTY) QTY
--                FROM TB_CM_ACTUAL_SALES S
                FROM TB_CM_ACTUAL_SALES S
                INNER JOIN ACCT_HIER AH ON AH.DESC_ID = S.ACCOUNT_ID
                INNER JOIN ITEM_HIER IH ON IH.DESC_ID = S.ITEM_MST_ID
                INNER JOIN TB_DP_ACCOUNT_MST AM ON S.ACCOUNT_ID=AM.ID
                INNER JOIN TB_CM_ITEM_MST	  IM ON S.ITEM_MST_ID=IM.ID
                WHERE S.BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
                GROUP BY AM.ACCOUNT_CD, AM.ACCOUNT_NM, IM.ITEM_CD, IM.ITEM_NM, TO_CHAR(S.BASE_DATE,'YYYY-MM')
        )
        , FINAL AS (
            SELECT F.VER_CD
                 , F.ITEM_CD
                 , F.ACCOUNT_CD
                 , TO_CHAR(F.BASE_DATE,'YYYY-MM') BASE_DATE
                 , SUM(F.QTY) QTY
                 , MIN(F.BEST_ENGINE_TP_CD) ENGINE_TP_CD
              FROM TB_BF_RT_FINAL F
             WHERE F.VER_CD = p_VER_CD AND BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
             GROUP BY F.VER_CD, ITEM_CD, ACCOUNT_CD, TO_CHAR(F.BASE_DATE,'YYYY-MM')
        ),
        WAPE AS (
            select A.ITEM_CD
                 , IH.ANCS_CD ITEM_LV_CD
                 , IH.ANCS_NM ITEM_LV_NM
                 , A.ACCOUNT_CD
                 , AH.ANCS_CD ACCT_LV_CD
                 , AH.ANCS_NM ACCT_LV_NM
                 , A.BASE_DATE
                 -- 예측
                 , A.QTY PREDICT
                 -- 실적
                 , B.QTY ACT_SALES
                 -- 개별정확도
                 , CASE WHEN B.QTY = 0 THEN 0 ELSE (CASE WHEN (1-ABS(A.QTY-B.QTY)/B.QTY) >= 0 THEN (1-ABS(A.QTY-B.QTY)/B.QTY)*100 ELSE 0 END) END WAPE
                 , IH.GRADE
                 , CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN A.ENGINE_TP_CD ELSE NULL END ENGINE_TP_CD
				 , CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN S.QTY_COV ELSE NULL END COV
				 , CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN S.QTY_RANK * 100 ELSE NULL END QTY_RANK
              from FINAL A
             LEFT JOIN ACT_SALES B ON A.ITEM_CD=B.ITEM_CD AND A.ACCOUNT_CD=B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE
             INNER JOIN TB_BF_SALES_STATS S ON A.ITEM_CD=S.ITEM_CD AND A.ACCOUNT_CD=S.ACCOUNT_CD
             INNER JOIN ACCT_HIER AH ON AH.DESC_CD = A.ACCOUNT_CD
             INNER JOIN ITEM_HIER IH ON IH.DESC_CD = A.ITEM_CD
        )
--           SELECT 'N' GRADE
--                , ITEM_LV_CD ITEM
--                , ITEM_LV_NM ITEM_NM
--                , ACCT_LV_CD SALES
--                , ACCT_LV_NM ACCT_NM
--                , BASE_DATE AS "DATE"
--                --, SUM(ACT_SALES)
--                , CASE WHEN SUM(ACT_SALES) = 0 THEN 0 
--							WHEN SUM(WAPE*ACT_SALES)/SUM(ACT_SALES)<0 THEN 0
--							ELSE SUM(WAPE*ACT_SALES)/SUM(ACT_SALES) END ACCRY
--            FROM WAPE
--            GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
--            ORDER BY ITEM_LV_CD, ACCT_LV_CD, BASE_DATE
--            ;
        , RT_ACCRY AS (
				SELECT 'N' AS GRADE
						, ITEM_LV_CD ITEM
						, ITEM_LV_NM ITEM_NM
						, ACCT_LV_CD SALES
						, ACCT_LV_NM ACCT_NM
						, MIN(ENGINE_TP_CD) ENGINE_TP_CD
						, MIN(COV) COV
						, MIN(QTY_RANK) QTY_RANK
						, 'ACT_SALES_QTY' AS CATEGORY
						--, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
						, BASE_DATE AS "DATE"
						, CAST(FLOOR(SUM(ACT_SALES)) AS VARCHAR2(10)) ACCRY
						, 1 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
				UNION 
				SELECT 'N' AS GRADE
						, ITEM_LV_CD ITEM
						, ITEM_LV_NM ITEM_NM
						, ACCT_LV_CD SALES
						, ACCT_LV_NM ACCT_NM
						, MIN(ENGINE_TP_CD) ENGINE_TP_CD
						, MIN(COV) COV
						, MIN(QTY_RANK) QTY_RANK
						, 'BF_QTY' AS CATEGORY
						--, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
						, BASE_DATE AS "DATE"
						, CAST(FLOOR(SUM(PREDICT)) AS VARCHAR2(10)) ACCRY
						, 2 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
				UNION
				SELECT 'N' AS GRADE
						, ITEM_LV_CD ITEM
						, ITEM_LV_NM ITEM_NM
						, ACCT_LV_CD SALES
						, ACCT_LV_NM ACCT_NM
						, MIN(ENGINE_TP_CD) ENGINE_TP_CD
						, MIN(COV) COV
						, MIN(QTY_RANK) QTY_RANK
						, 'DMND_PRDICT_ACCURCY' AS CATEGORY
						--, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
						, BASE_DATE AS "DATE"
						, CASE WHEN SUM(ACT_SALES) = 0 THEN '0%'
					 		   WHEN SUM(ACT_SALES) IS NULL THEN NULL
					           WHEN (1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100 <= 0 THEN '0%'
					           ELSE RTRIM(TO_CHAR(ROUND((1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100, 1)), TO_CHAR(0, 'D')) || '%' END ACCRY
						, 3 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
        )
        SELECT * FROM RT_ACCRY
        ORDER BY GRADE, ITEM, SALES, "DATE", ORDER_VAL;
    ELSIF (v_BUCKET = 'W' AND p_SUM = 'N')
    	THEN
    	OPEN pRESULT FOR
    	WITH ITEM_HIER AS (
	    SELECT IH.DESCENDANT_ID AS DESC_ID
	          ,IH.DESCENDANT_CD AS DESC_CD
	          ,IH.ANCESTER_CD AS ANCS_CD
	          ,IL.ITEM_LV_NM AS ANCS_NM
	          ,IM.ATTR_05 AS GRADE
	     FROM TB_DPD_ITEM_HIER_CLOSURE IH
	          INNER JOIN
	          TB_CM_ITEM_LEVEL_MGMT IL
	       ON IH.ANCESTER_ID = IL.ID
	          INNER JOIN
	          TB_CM_ITEM_MST IM
	       ON IH.DESCENDANT_CD = IM.ITEM_CD
	     WHERE 1=1
	       AND IL.LV_MGMT_ID = p_ITEM_LV
	       AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                OR p_ITEM_CD IS NULL
               )
	       AND IH.LEAF_YN = 'Y'
	     UNION ALL
	    SELECT IH.DESCENDANT_ID AS DESC_ID
	          ,IH.DESCENDANT_CD AS DESC_CD
	          ,IH.ANCESTER_CD AS ANCS_CD
	          ,CAST(IT.ITEM_NM AS VARCHAR2(255)) AS ANCS_NM
	          ,IT.ATTR_05
	     FROM TB_DPD_ITEM_HIER_CLOSURE IH
	          INNER JOIN
	          TB_CM_ITEM_MST IT
	       ON IH.ANCESTER_ID = IT.ID 
	    WHERE 1=1
	      AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
	           OR p_ITEM_CD IS NULL
	          )
	      AND IH.LEAF_YN = 'Y'
	      AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = p_ITEM_LV) THEN 0 ELSE 1 END
	    )
    , ACCT_HIER AS (
            SELECT SH.DESCENDANT_ID AS DESC_ID
                  ,SH.DESCENDANT_CD AS DESC_CD
                  ,SH.ANCESTER_CD AS ANCS_CD
                  ,SL.SALES_LV_NM AS ANCS_NM
             FROM TB_DPD_SALES_HIER_CLOSURE SH
                  INNER JOIN 
                  TB_DP_SALES_LEVEL_MGMT SL 
               ON SH.ANCESTER_ID = SL.ID 
             WHERE 1=1
               AND SL.LV_MGMT_ID = p_SALES_LV
               AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                    OR p_ACCT_CD IS NULL
                   )
               AND SH.LEAF_YN = 'Y' 
             UNION ALL
            SELECT SH.DESCENDANT_ID
                  ,SH.DESCENDANT_CD
                  ,SH.ANCESTER_CD
                  ,AM.ACCOUNT_NM
             FROM TB_DPD_SALES_HIER_CLOSURE SH
                  INNER JOIN 
                  TB_DP_ACCOUNT_MST AM 
               ON SH.ANCESTER_ID = AM.ID
             WHERE 1=1
               AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                 	OR p_ACCT_CD IS NULL    
    	           )
               AND SH.LEAF_YN = 'Y'
               AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = p_SALES_LV) THEN 0 ELSE 1 END
    ) 
    , CAL AS (
        SELECT YYYY, DP_WK, MM, MIN(DAT) MIN_DAT, MAX(DAT) MAX_DAT
          FROM TB_CM_CALENDAR
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE
         GROUP BY YYYY, DP_WK, MM
    )
    , SALES AS (
           SELECT AM.ACCOUNT_CD
                , AM.ACCOUNT_NM
                , IM.ITEM_CD
                , IM.ITEM_NM
                , S.BASE_DATE BASE_DATE
                , SUM(S.QTY) QTY
                , MIN(CL.YYYY ) YYYY
                , MIN(CL.MM   ) MM
                , MIN(CL.DP_WK) DP_WK
            FROM TB_CM_ACTUAL_SALES S
            INNER JOIN ACCT_HIER AH ON AH.DESC_ID = S.ACCOUNT_ID
            INNER JOIN ITEM_HIER IH ON IH.DESC_ID = S.ITEM_MST_ID
			INNER JOIN TB_DP_ACCOUNT_MST  AM ON S.ACCOUNT_ID=AM.ID
			INNER JOIN TB_CM_ITEM_MST	  IM ON S.ITEM_MST_ID=IM.ID
            INNER JOIN TB_CM_CALENDAR     CL ON CL.DAT = S.BASE_DATE
            WHERE S.BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
            GROUP BY AM.ACCOUNT_CD, AM.ACCOUNT_NM, IM.ITEM_CD, IM.ITEM_NM, S.BASE_DATE
    )
    , ACT_SALES AS (
        SELECT ITEM_CD
             , ITEM_NM
             , ACCOUNT_CD
             , ACCOUNT_NM
			 , B.MIN_DAT BASE_DATE
			 , SUM(QTY) QTY
          FROM SALES A
         INNER JOIN CAL B ON A.YYYY = B.YYYY AND A.MM = B.MM AND A.DP_WK = B.DP_WK
         GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, B.MIN_DAT
    ) 
    , FINAL AS (
        SELECT F.VER_CD
             , F.ITEM_CD
             , I.ITEM_NM
             , F.ACCOUNT_CD
             , A.ACCOUNT_NM
             , F.BASE_DATE BASE_DATE
             , SUM(F.QTY) QTY
             , MIN(F.BEST_ENGINE_TP_CD) ENGINE_TP_CD
          FROM TB_BF_RT_FINAL F
          INNER JOIN TB_CM_ITEM_MST I ON F.ITEM_CD = I.ITEM_CD
          INNER JOIN TB_DP_ACCOUNT_MST A ON F.ACCOUNT_CD = A.ACCOUNT_CD
         WHERE F.VER_CD = p_VER_CD AND F.BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
         GROUP BY F.VER_CD, F.ITEM_CD, ITEM_NM, F.ACCOUNT_CD, ACCOUNT_NM, F.BASE_DATE
    ) 
    ,
    WAPE AS (
        SELECT A.ITEM_CD
         	 , A.ITEM_NM
             , A.ACCOUNT_CD
             , A.ACCOUNT_NM
             , A.BASE_DATE
             -- 예측
             , A.QTY PREDICT
             -- 실적
             , B.QTY ACT_SALES
             -- 개별정확도
             , CASE WHEN B.QTY = 0 THEN 0 ELSE (CASE WHEN (1-ABS(A.QTY-B.QTY)/B.QTY) >= 0 THEN (1-ABS(A.QTY-B.QTY)/B.QTY)*100 ELSE 0 END) END WAPE
             , IH.GRADE
			 , CASE WHEN (A.ITEM_CD = IH.DESC_CD) AND (A.ACCOUNT_CD = AH.DESC_CD) THEN A.ENGINE_TP_CD ELSE NULL END ENGINE_TP_CD
			 , CASE WHEN (A.ITEM_CD = IH.DESC_CD) AND (A.ACCOUNT_CD = AH.DESC_CD) THEN S.QTY_COV ELSE NULL END COV
			 , CASE WHEN (A.ITEM_CD = IH.DESC_CD) AND (A.ACCOUNT_CD = AH.DESC_CD) THEN S.QTY_RANK * 100 ELSE NULL END QTY_RANK
         FROM FINAL A
            LEFT JOIN ACT_SALES B ON A.ITEM_CD=B.ITEM_CD AND A.ACCOUNT_CD=B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE
            LEFT JOIN TB_BF_SALES_STATS S ON A.ITEM_CD=S.ITEM_CD AND A.ACCOUNT_CD=S.ACCOUNT_CD
            --INNER JOIN TB_CM_ITEM_MST IM ON A.ITEM_CD = IM.ITEM_CD AND IM.ATTR_05 !='N'
            INNER JOIN ACCT_HIER AH ON AH.DESC_CD = A.ACCOUNT_CD
            INNER JOIN ITEM_HIER IH ON IH.DESC_CD = A.ITEM_CD
    )     
    , RT_ACCRY AS (
			SELECT 'N' AS GRADE
				 , ITEM_CD ITEM
 				 , ITEM_NM
 				 , ACCOUNT_CD SALES
 				 , ACCOUNT_NM ACCT_NM
				 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
				 , MIN(COV) COV
				 , MIN(QTY_RANK) QTY_RANK
				 , 'ACT_SALES_QTY' AS CATEGORY
				 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
				 , BASE_DATE AS "DATE"
				 , CAST(FLOOR(SUM(ACT_SALES)) AS VARCHAR2(10)) ACCRY
				 , 1 AS ORDER_VAL
			FROM WAPE
			GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE
			UNION 
			SELECT 'N' AS GRADE
				 , ITEM_CD ITEM
				 , ITEM_NM ITEM_NM
				 , ACCOUNT_CD SALES
				 , ACCOUNT_NM ACCT_NM
				 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
				 , MIN(COV) COV
				 , MIN(QTY_RANK) QTY_RANK
				 , 'BF_QTY' AS CATEGORY
				 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
				 , BASE_DATE AS "DATE"
				 , CAST(FLOOR(SUM(PREDICT)) AS VARCHAR2(10)) ACCRY
				 , 2 AS ORDER_VAL
			FROM WAPE
			GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE
			UNION
			SELECT 'N' AS GRADE
				 , ITEM_CD ITEM
				 , ITEM_NM ITEM_NM
				 , ACCOUNT_CD SALES
				 , ACCOUNT_NM ACCT_NM
				 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
				 , MIN(COV) COV
				 , MIN(QTY_RANK) QTY_RANK
				 , 'DMND_PRDICT_ACCURCY' AS CATEGORY
				 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
				 , BASE_DATE AS "DATE"
				 , CASE WHEN SUM(ACT_SALES) = 0 THEN '0%'
				 		WHEN SUM(ACT_SALES) IS NULL THEN NULL
				        WHEN (1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100 <= 0 THEN '0%'
				        ELSE RTRIM(TO_CHAR(ROUND((1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100, 1)), TO_CHAR(0, 'D')) || '%' END ACCRY
--						 	WHEN SUM(WAPE*ACT_SALES)/SUM(ACT_SALES) <= 0 THEN '0%'
--						 	ELSE CAST(ROUND(SUM(WAPE*ACT_SALES)/SUM(ACT_SALES), 1) AS VARCHAR2(10)) || '%' END ACCRY
				 , 3 AS ORDER_VAL
			FROM WAPE
			GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE
    )
    SELECT * FROM RT_ACCRY
    ORDER BY ITEM, SALES, "DATE", ORDER_VAL;
    ELSE 
        OPEN pRESULT FOR
        WITH ITEM_HIER AS (
                SELECT IH.DESCENDANT_ID AS DESC_ID
                      ,IH.DESCENDANT_CD AS DESC_CD
                      ,IH.ANCESTER_CD AS ANCS_CD
                      ,IL.ITEM_LV_NM AS ANCS_NM
                      ,IM.ATTR_05 AS GRADE
                 FROM TB_DPD_ITEM_HIER_CLOSURE IH
                      INNER JOIN
                      tb_cm_item_level_mgmt IL
                   ON IH.ANCESTER_ID = IL.ID
                      INNER JOIN
                      TB_CM_ITEM_MST IM
                   ON IH.DESCENDANT_CD = IM.ITEM_CD
                 WHERE 1=1
                   AND IL.lv_mgmt_id = p_ITEM_LV
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ITEM_CD IS NULL
                       )
                   AND IH.LEAF_YN = 'Y'
                 UNION ALL
                SELECT IH.DESCENDANT_ID AS DESC_ID
                      ,IH.DESCENDANT_CD AS DESC_CD
                      ,IH.ANCESTER_CD AS ANCS_CD
                      ,CAST(IT.ITEM_NM AS VARCHAR2(255)) AS ANCS_NM
                      ,IT.ATTR_05
                 FROM TB_DPD_ITEM_HIER_CLOSURE IH
                      INNER JOIN
                      TB_CM_ITEM_MST IT
                   ON IH.ANCESTER_ID = IT.ID 
                WHERE 1=1
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ITEM_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ITEM_CD IS NULL
                       )
                  AND IH.LEAF_YN = 'Y'
                  AND 1 = CASE WHEN EXISTS (SELECT 1 FROM tb_cm_item_level_mgmt WHERE lv_mgmt_id = p_ITEM_LV) THEN 0 ELSE 1 END
        )
        , ACCT_HIER AS (
                SELECT SH.DESCENDANT_ID AS DESC_ID
                      ,SH.DESCENDANT_CD AS DESC_CD
                      ,SH.ANCESTER_CD AS ANCS_CD
                      ,SL.SALES_LV_NM AS ANCS_NM
                 FROM TB_DPD_SALES_HIER_CLOSURE SH
                      INNER JOIN 
                      TB_DP_SALES_LEVEL_MGMT SL 
                   ON SH.ANCESTER_ID = SL.ID 
                 WHERE 1=1
                   AND SL.LV_MGMT_ID = p_SALES_LV
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ACCT_CD IS NULL
                       )
                   AND SH.LEAF_YN = 'Y' 
                 UNION ALL
                SELECT SH.DESCENDANT_ID
                      ,SH.DESCENDANT_CD
                      ,SH.ANCESTER_CD
                      ,AM.ACCOUNT_NM
                 FROM TB_DPD_SALES_HIER_CLOSURE SH
                      INNER JOIN 
                      TB_DP_ACCOUNT_MST AM 
                   ON SH.ANCESTER_ID = AM.ID
                 WHERE 1=1
                   AND ( REGEXP_LIKE (UPPER(ANCESTER_CD), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_ACCT_CD), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
                        OR p_ACCT_CD IS NULL
                       )
                   AND SH.LEAF_YN = 'Y'
                   AND 1 = CASE WHEN EXISTS (SELECT 1 FROM tb_dp_sales_level_mgmt WHERE lv_mgmt_id = p_SALES_LV) THEN 0 ELSE 1 END
        )
        , CAL AS (
            SELECT YYYY, DP_WK, MM, MIN(DAT) MIN_DAT, MAX(DAT) MAX_DAT
              FROM TB_CM_CALENDAR
             WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE
             GROUP BY YYYY, DP_WK, MM
        )
        , SALES AS (
               SELECT AM.ACCOUNT_CD
                    , AM.ACCOUNT_NM
                    , IM.ITEM_CD
                    , IM.ITEM_NM
                    , S.BASE_DATE BASE_DATE
                    , SUM(S.QTY) QTY
                    , MIN(CL.YYYY ) YYYY
                    , MIN(CL.MM   ) MM
                    , MIN(CL.DP_WK) DP_WK
--                FROM TB_CM_ACTUAL_SALES S
                FROM TB_CM_ACTUAL_SALES S
                INNER JOIN ACCT_HIER AH ON AH.DESC_ID = S.ACCOUNT_ID
                INNER JOIN ITEM_HIER IH ON IH.DESC_ID = S.ITEM_MST_ID
				INNER JOIN TB_DP_ACCOUNT_MST  AM ON S.ACCOUNT_ID=AM.ID
				INNER JOIN TB_CM_ITEM_MST	  IM ON S.ITEM_MST_ID=IM.ID
                INNER JOIN TB_CM_CALENDAR     CL ON CL.DAT = S.BASE_DATE
                WHERE S.BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
                GROUP BY AM.ACCOUNT_CD, AM.ACCOUNT_NM, IM.ITEM_CD, IM.ITEM_NM, S.BASE_DATE
        ),
        ACT_SALES AS (
            SELECT ITEM_CD
                 , ITEM_NM
                 , ACCOUNT_CD
                 , ACCOUNT_NM
				 , B.MIN_DAT BASE_DATE
				 , SUM(QTY) QTY
              FROM SALES A
             INNER JOIN CAL B ON A.YYYY = B.YYYY AND A.MM = B.MM AND A.DP_WK = B.DP_WK
             GROUP BY ITEM_CD, ITEM_NM, ACCOUNT_CD, ACCOUNT_NM, B.MIN_DAT
             --ORDER BY B.MIN_DAT
        )
        , FINAL AS (
                SELECT F.VER_CD
                     , F.ITEM_CD
                     , F.ACCOUNT_CD
                     , F.BASE_DATE BASE_DATE
                     , SUM(F.QTY) QTY
                     , MIN(F.BEST_ENGINE_TP_CD) ENGINE_TP_CD
                  FROM TB_BF_RT_FINAL F
                 WHERE F.VER_CD = p_VER_CD AND F.BASE_DATE BETWEEN p_FROM_DATE AND v_TO_DATE
                 GROUP BY F.VER_CD, ITEM_CD, ACCOUNT_CD, F.BASE_DATE
        ) 
        ,
        WAPE AS (
            SELECT A.ITEM_CD
                , IH.ANCS_CD ITEM_LV_CD
                , IH.ANCS_NM ITEM_LV_NM
                , A.ACCOUNT_CD
                , AH.ANCS_CD ACCT_LV_CD
                , AH.ANCS_NM ACCT_LV_NM
                , A.BASE_DATE
                -- 예측
                , A.QTY PREDICT
                -- 실적
                , B.QTY ACT_SALES
                -- 개별정확도
                , CASE WHEN B.QTY = 0 THEN 0 ELSE (CASE WHEN (1-ABS(A.QTY-B.QTY)/B.QTY) >= 0 THEN (1-ABS(A.QTY-B.QTY)/B.QTY)*100 ELSE 0 END) END WAPE
                , IH.GRADE
				, CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN A.ENGINE_TP_CD ELSE NULL END ENGINE_TP_CD
				, CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN S.QTY_COV ELSE NULL END COV
				, CASE WHEN (A.ITEM_CD = IH.ANCS_CD) AND (A.ACCOUNT_CD = AH.ANCS_CD) THEN S.QTY_RANK * 100 ELSE NULL END QTY_RANK
            from FINAL A
                LEFT JOIN ACT_SALES B ON A.ITEM_CD=B.ITEM_CD AND A.ACCOUNT_CD=B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE
                LEFT JOIN TB_BF_SALES_STATS S ON A.ITEM_CD=S.ITEM_CD AND A.ACCOUNT_CD=S.ACCOUNT_CD
                --INNER JOIN TB_CM_ITEM_MST IM ON A.ITEM_CD = IM.ITEM_CD AND IM.ATTR_05 !='N'
                INNER JOIN ACCT_HIER AH ON AH.DESC_CD = A.ACCOUNT_CD
                INNER JOIN ITEM_HIER IH ON IH.DESC_CD = A.ITEM_CD
        )
        , RT_ACCRY AS (
				SELECT 'N' AS GRADE
					 , ITEM_LV_CD ITEM
					 , ITEM_LV_NM ITEM_NM
					 , ACCT_LV_CD SALES
					 , ACCT_LV_NM ACCT_NM
					 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
					 , MIN(COV) COV
					 , MIN(QTY_RANK) QTY_RANK
					 , 'ACT_SALES_QTY' AS CATEGORY
					 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
					 , BASE_DATE AS "DATE"
					 , CAST(FLOOR(SUM(ACT_SALES)) AS VARCHAR2(10)) ACCRY
					 , 1 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
				UNION 
				SELECT 'N' AS GRADE
					 , ITEM_LV_CD ITEM
					 , ITEM_LV_NM ITEM_NM
					 , ACCT_LV_CD SALES
					 , ACCT_LV_NM ACCT_NM
					 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
					 , MIN(COV) COV
					 , MIN(QTY_RANK) QTY_RANK
					 , 'BF_QTY' AS CATEGORY
					 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
					 , BASE_DATE AS "DATE"
					 , CAST(FLOOR(SUM(PREDICT)) AS VARCHAR2(10)) ACCRY
					 , 2 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
				UNION
				SELECT 'N' AS GRADE
					 , ITEM_LV_CD ITEM
					 , ITEM_LV_NM ITEM_NM
					 , ACCT_LV_CD SALES
					 , ACCT_LV_NM ACCT_NM
					 , MIN(ENGINE_TP_CD) ENGINE_TP_CD
					 , MIN(COV) COV
					 , MIN(QTY_RANK) QTY_RANK
					 , 'DMND_PRDICT_ACCURCY' AS CATEGORY
					 --, DATEADD(MONTH,1,CONVERT(DATETIME,BASE_DATE+'_01'))-1 AS "DATE"
					 , BASE_DATE AS "DATE"
					 , CASE WHEN SUM(ACT_SALES) = 0 THEN '0%'
					 		WHEN SUM(ACT_SALES) IS NULL THEN NULL
					        WHEN (1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100 <= 0 THEN '0%'
					        ELSE RTRIM(TO_CHAR(ROUND((1 - ABS(SUM(ACT_SALES) - SUM(PREDICT)) / SUM(ACT_SALES)) * 100, 1)), TO_CHAR(0, 'D')) || '%' END ACCRY
--						 	WHEN SUM(WAPE*ACT_SALES)/SUM(ACT_SALES) <= 0 THEN '0%'
--						 	ELSE CAST(ROUND(SUM(WAPE*ACT_SALES)/SUM(ACT_SALES), 1) AS VARCHAR2(10)) || '%' END ACCRY
					 , 3 AS ORDER_VAL
				FROM WAPE
				GROUP BY ITEM_LV_CD, ITEM_LV_NM, ACCT_LV_CD, ACCT_LV_NM, BASE_DATE
        )
        SELECT * FROM RT_ACCRY
        ORDER BY ITEM, SALES, "DATE", ORDER_VAL;
    END IF;

END;