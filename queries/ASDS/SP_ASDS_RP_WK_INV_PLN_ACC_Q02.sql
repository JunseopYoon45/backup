CREATE OR REPLACE PROCEDURE DWSCM."SP_ASDS_RP_WK_INV_PLN_ACC_Q02" (
	P_VER_ID			IN VARCHAR2 := NULL, /*실적주*/	
	P_DC_CD				IN VARCHAR2 := NULL, /*물류센터*/	
	P_ITEM_DIV_CD		IN VARCHAR2 := NULL, /*소분류*/
	P_MD_EMP_ID       	IN VARCHAR2 := NULL, /*MD*/	
	P_PO_EMP_ID			IN VARCHAR2 := NULL, /*발주담당자*/
	P_PO_SBJ_CD 		IN VARCHAR2 := NULL, /*부서*/
	P_HMP_EMP_CD       	IN VARCHAR2 := NULL, /*발주팀*/ 
	P_LOWER				IN NUMBER   := NULL, /*재고계획 준수율 하한선*/
	P_UPPER				IN NUMBER   := NULL, /*재고계획 준수율 상한선*/
	pRESULT				OUT SYS_REFCURSOR
)
IS
/********************************************************************************
* Name    : SP_ASDS_RP_MM_INV_PLN_ACC_Q02
* Purpose : 재고계획 준수율 (주간) (Grid 2)
* Notes   :
*********************************************************************************
* History :
* 2023-11-10 YJS CREATE
*********************************************************************************
* Execute :
DECLARE
	pRESULT SYS_REFCURSOR;
BEGIN
	SP_ASDS_RP_WK_INV_PLN_ACC_Q02('2023-10-23', '', '', '', '', '', '', '', '', pRESULT);
	DBMS_SQL.RETURN_RESULT(pRESULT);
END;
*********************************************************************************/
	
	v_LOWER NUMBER := NVL(P_LOWER, 0);
	v_UPPER NUMBER := NVL(P_UPPER, 100);
	
BEGIN
	
	
	OPEN pRESULT FOR
	WITH INV AS (
		SELECT A.IO_DAY
			 , A.GDS_NUM
			 , A.WHS_COD
			 , CASE WHEN ABS(DMND_W00 - ACT_W00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_W00			    		  
			 , CASE WHEN ABS(DMND_W01 - ACT_W01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_W01				
			 , CASE WHEN ABS(DMND_W02 - ACT_W02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_W02	
			 , CASE WHEN ABS(DMND_W03 - ACT_W03) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_W03				
--			 , CASE WHEN ABS(DMND_W04 - ACT_W04) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W04 - ACT_W04)/(ACT_W04 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W04 - ACT_W04)/(ACT_W04 + 0.0001))*100,1)
--							   ELSE 0 END) END AS INV_ACC_W04				
--			 , CASE WHEN ABS(DMND_W05 - ACT_W05) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W05 - ACT_W05)/(ACT_W05 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W05 - ACT_W05)/(ACT_W05 + 0.0001))*100,1)
--							   ELSE 0 END) END AS INV_ACC_W05				
--			 , CASE WHEN ABS(DMND_W06 - ACT_W06) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W06 - ACT_W06)/(ACT_W06 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W06 - ACT_W06)/(ACT_W06 + 0.0001))*100,1)
--							   ELSE 0 END) END AS INV_ACC_W06				
--			 , CASE WHEN ABS(DMND_W07 - ACT_W07) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W07 - ACT_W07)/(ACT_W07 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W07 - ACT_W07)/(ACT_W07 + 0.0001))*100,1)
--							   ELSE 0 END) END AS INV_ACC_W07				
--			 , CASE WHEN ABS(DMND_W08 - ACT_W08) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W08 - ACT_W08)/(ACT_W08 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_W08 - ACT_W08)/(ACT_W08 + 0.0001))*100,1)
--							   ELSE 0 END) END AS INV_ACC_W08				
--			 , CASE WHEN ABS(DMND_W09 - ACT_W09) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W09 - ACT_W09)/(ACT_W09 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_W09 - ACT_W09)/(ACT_W09 + 0.0001))*100,1) 
--							   ELSE 0 END) END AS INV_ACC_W09				
--			 , CASE WHEN ABS(DMND_W10 - ACT_W10) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W10 - ACT_W10)/(ACT_W10 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_W10 - ACT_W10)/(ACT_W10 + 0.0001))*100,1) 
--							   ELSE 0 END) END AS INV_ACC_W10				
--			 , CASE WHEN ABS(DMND_W11 - ACT_W11) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W11 - ACT_W11)/(ACT_W11 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_W11 - ACT_W11)/(ACT_W11 + 0.0001))*100,1) 	 
--							   ELSE 0 END) END AS INV_ACC_W11
--			 , CASE WHEN ABS(DMND_W12 - ACT_W12) = 0 THEN 100 
--					ELSE (CASE WHEN (1-ABS(DMND_W12 - ACT_W12)/(ACT_W12 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_W12 - ACT_W12)/(ACT_W12 + 0.0001))*100,1) 	 
--							   ELSE 0 END) END AS INV_ACC_W12				   
			 , NVL(SFST_INV, 0) 	AS SFST_INV
			 , NVL(TARGET_INV, 0)   AS TARGET_INV
			 , NVL(END_INV, 0) 	    AS END_INV
			 , NVL(INV_TURN, 0)     AS INV_TURN				   
		  FROM (SELECT A.IO_DAY
					 , A.GDS_NUM					 
					 , A.WHS_COD
					 , A.W00 AS DMND_W00
					 , A.W01 AS DMND_W01
					 , A.W02 AS DMND_W02
					 , A.W03 AS DMND_W03
--					 , A.W04 AS DMND_W04
--					 , A.W05 AS DMND_W05
--					 , A.W06 AS DMND_W06
--					 , A.W07 AS DMND_W07
--					 , A.W08 AS DMND_W08
--					 , A.W09 AS DMND_W09
--					 , A.W10 AS DMND_W10
--					 , A.W11 AS DMND_W11
--					 , A.W12 AS DMND_W12
					 , B.W00 AS ACT_W00
					 , B.W01 AS ACT_W01
					 , B.W02 AS ACT_W02
					 , B.W03 AS ACT_W03
--					 , B.W04 AS ACT_W04
--					 , B.W05 AS ACT_W05
--					 , B.W06 AS ACT_W06
--					 , B.W07 AS ACT_W07
--					 , B.W08 AS ACT_W08
--					 , B.W09 AS ACT_W09
--					 , B.W10 AS ACT_W10
--					 , B.W11 AS ACT_W11
--					 , B.W12 AS ACT_W12
				 FROM (SELECT IO_DAY
				 	 		, A.GDS_NUM
				 	 		, WHS_COD
				 	 		, W00
							, W01
							, W02
							, W03
--							, W04
--							, W05
--							, W06
--							, W07
--							, W08
--							, W09
--							, W10
--							, W11
--							, W12
				 	     FROM WEEKGDSINVPLN A
				 	    INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
				 	       ON A.GDS_NUM = B.GDS_NUM 
				 	    WHERE IO_DAY = P_VER_ID
--				 	      AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--				 	      AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
				 	      AND DIV_COD = P_ITEM_DIV_CD
				 	      AND WHS_COD LIKE P_DC_CD ||'%'
--				 	      AND WHS_COD IN (SELECT T20.LOCAT_CD
--				                            FROM TB_CM_LOC_MGMT T10
--				                           INNER JOIN TB_CM_LOC_DTL T20
--				                              ON T10.LOCAT_ID = T20.ID
--				                           INNER JOIN TB_CM_LOC_MST T30
--				                              ON T20.LOCAT_MST_ID = T30.ID
--				                           INNER JOIN TB_AD_COMN_CODE T40
--				                              ON T30.LOCAT_TP_ID = T40.ID
--				                           WHERE T40.COMN_CD_NM = 'CDC'
--				                             AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
    				 	  AND INV_PLN_DIV = 45) A
				INNER JOIN (SELECT IO_DAY
					 	 		 , A.GDS_NUM
					 	 		 , WHS_COD
								 , W00
								 , W01
								 , W02
								 , W03
--								 , W04
--								 , W05
--							 	 , W06
--						 		 , W07
--								 , W08
--								 , W09
--								 , W10
--								 , W11
--								 , W12
					 	      FROM WEEKGDSINVPLN A
	 				 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 				
					 	     WHERE 1=1
					 	       AND IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 15) B			 	        
				   ON A.IO_DAY = B.IO_DAY
				  AND A.GDS_NUM = B.GDS_NUM
				  AND A.WHS_COD = B.WHS_COD) A
				 LEFT JOIN (SELECT IO_DAY
								 , A.GDS_NUM
								 , WHS_COD
								 , W00 AS SFST_INV
							  FROM WEEKGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 51) B
				   ON A.IO_DAY = B.IO_DAY
				  AND A.GDS_NUM = B.GDS_NUM
				  AND A.WHS_COD = B.WHS_COD
				 LEFT JOIN (SELECT IO_DAY
								 , A.GDS_NUM
								 , WHS_COD
								 , W00 AS TARGET_INV
							  FROM WEEKGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 53) C
				   ON A.IO_DAY = C.IO_DAY
				  AND A.GDS_NUM = C.GDS_NUM
				  AND A.WHS_COD = C.WHS_COD
				 LEFT JOIN (SELECT IO_DAY
								 , A.GDS_NUM
								 , WHS_COD
								 , W00 AS END_INV
							  FROM WEEKGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 45) D
				  ON A.IO_DAY = D.IO_DAY
				 AND A.GDS_NUM = D.GDS_NUM
				 AND A.WHS_COD = D.WHS_COD 
				LEFT JOIN (SELECT IO_DAY
								 , A.GDS_NUM
								 , WHS_COD
								 , W00 AS INV_TURN
							  FROM WEEKGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 46) E 
				  ON A.IO_DAY = E.IO_DAY
				 AND A.GDS_NUM = E.GDS_NUM
				 AND A.WHS_COD = E.WHS_COD  	  
	)
	, RLS AS (
		SELECT IO_DAY
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_W00 - ACT_W00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_W00			    		  
			 , CASE WHEN ABS(DMND_W01 - ACT_W01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_W01				
			 , CASE WHEN ABS(DMND_W02 - ACT_W02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001)) >=  0 THEN ROUND((1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_W02
			 , CASE WHEN ABS(DMND_W03 - ACT_W03) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001)) >=  0 THEN ROUND((1-ABS(DMND_W03 - ACT_W02)/(ACT_W03 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_W03				   
		  FROM (SELECT A.IO_DAY
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.W00 AS DMND_W00
					 , A.W01 AS DMND_W01
					 , A.W02 AS DMND_W02
					 , A.W03 AS DMND_W03
					 , B.W00 AS ACT_W00
					 , B.W01 AS ACT_W01
					 , B.W02 AS ACT_W02	
					 , B.W03 AS ACT_W03
				 FROM (SELECT IO_DAY
				 	 		, A.GDS_NUM
				 	 		, WHS_COD
				 	 		, W00
				 	 		, W01
				 	 		, W02
				 	 		, W03
				 	     FROM WEEKGDSINVPLN A
 				 	    INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
 				 	       ON A.GDS_NUM = B.GDS_NUM
				 	    WHERE IO_DAY = P_VER_ID
--				 	      AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--				 	      AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
				 	      AND DIV_COD = P_ITEM_DIV_CD
				 	      AND WHS_COD LIKE P_DC_CD ||'%'
--				 	      AND WHS_COD IN (SELECT T20.LOCAT_CD
--				                            FROM TB_CM_LOC_MGMT T10
--				                           INNER JOIN TB_CM_LOC_DTL T20
--				                              ON T10.LOCAT_ID = T20.ID
--				                           INNER JOIN TB_CM_LOC_MST T30
--				                              ON T20.LOCAT_MST_ID = T30.ID
--				                           INNER JOIN TB_AD_COMN_CODE T40
--				                              ON T30.LOCAT_TP_ID = T40.ID
--				                           WHERE T40.COMN_CD_NM = 'CDC'
--				                             AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
				 	      AND INV_PLN_DIV = 35) A 				
				INNER JOIN (SELECT IO_DAY
					 	 		 , A.GDS_NUM
					 	 		 , WHS_COD
					 	 		 , W00
					 	 		 , W01
					 	 		 , W02
					 	 		 , W03
					 	      FROM WEEKGDSINVPLN A
					 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM
					 	     WHERE IO_DAY = P_VER_ID
--					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	       AND DIV_COD = P_ITEM_DIV_CD
					 	       AND WHS_COD LIKE P_DC_CD ||'%'
--					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 09) B			 	     
				   ON A.IO_DAY = B.IO_DAY
				  AND A.GDS_NUM = B.GDS_NUM
				  AND A.WHS_COD = B.WHS_COD)
	) 
	, ORD AS (
		SELECT IO_DAY
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_W00 - ACT_W00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_W00			    		  
			 , CASE WHEN ABS(DMND_W01 - ACT_W01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_W01				
			 , CASE WHEN ABS(DMND_W02 - ACT_W02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_W02					
		     , CASE WHEN ABS(DMND_W03 - ACT_W03) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W03 - ACT_W02)/(ACT_W03 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_W03					   
		  FROM (SELECT A.IO_DAY
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.W00 AS DMND_W00
					 , A.W01 AS DMND_W01
					 , A.W02 AS DMND_W02
					 , A.W03 AS DMND_W03
					 , B.W00 AS ACT_W00
					 , B.W01 AS ACT_W01
					 , B.W02 AS ACT_W02	
					 , B.W03 AS ACT_W03
				  FROM (SELECT IO_DAY
				 	 		 , A.GDS_NUM
				 	 		 , WHS_COD
				 	 		 , W00
				 	 		 , W01
				 	 		 , W02
				 	 		 , W03
				 	      FROM WEEKGDSINVPLN A
				 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
				 	        ON A.GDS_NUM = B.GDS_NUM
				 	     WHERE IO_DAY = P_VER_ID
--				 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--				 	       AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
				 	       AND DIV_COD = P_ITEM_DIV_CD
				 	       AND WHS_COD LIKE P_DC_CD ||'%'
--				 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
--				                             FROM TB_CM_LOC_MGMT T10
--				                            INNER JOIN TB_CM_LOC_DTL T20
--				                               ON T10.LOCAT_ID = T20.ID
--				                            INNER JOIN TB_CM_LOC_MST T30
--				                               ON T20.LOCAT_MST_ID = T30.ID
--				                            INNER JOIN TB_AD_COMN_CODE T40
--				                               ON T30.LOCAT_TP_ID = T40.ID
--				                            WHERE T40.COMN_CD_NM = 'CDC'
--				                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
				 	       AND INV_PLN_DIV = 56) A
			     INNER JOIN (SELECT IO_DAY
					 	 		  , A.GDS_NUM
					 	 		  , WHS_COD
					 	 		  , W00
					 	 		  , W01
					 	 		  , W02
					 	 		  , W03
					 	       FROM WEEKGDSINVPLN A
					 	      INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	         ON A.GDS_NUM = B.GDS_NUM 
					 	      WHERE IO_DAY = P_VER_ID
--					 	        AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--					 	        AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
					 	        AND DIV_COD = P_ITEM_DIV_CD
					 	        AND WHS_COD LIKE P_DC_CD ||'%'
--					 	        AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	        AND INV_PLN_DIV = 05) B
				    ON A.IO_DAY = B.IO_DAY
				   AND A.GDS_NUM = B.GDS_NUM
				   AND A.WHS_COD = B.WHS_COD
				)
	)
	, STCK AS (
		SELECT IO_DAY
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_W00 - ACT_W00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W00 - ACT_W00)/(ACT_W00 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_W00			    		  
			 , CASE WHEN ABS(DMND_W01 - ACT_W01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W01 - ACT_W01)/(ACT_W01 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_W01				
			 , CASE WHEN ABS(DMND_W02 - ACT_W02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W02 - ACT_W02)/(ACT_W02 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_W02
	   		 , CASE WHEN ABS(DMND_W03 - ACT_W03) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_W03 - ACT_W03)/(ACT_W03 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_W03				   
		  FROM (SELECT A.IO_DAY
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.W00 AS DMND_W00
					 , A.W01 AS DMND_W01
					 , A.W02 AS DMND_W02
					 , A.W03 AS DMND_W03
					 , B.W00 AS ACT_W00
					 , B.W01 AS ACT_W01
					 , B.W02 AS ACT_W02
					 , B.W03 AS ACT_W03
				  FROM (SELECT IO_DAY
							 , A.GDS_NUM
							 , WHS_COD
							 , SUM(W00) AS W00
	 						 , SUM(W01) AS W01
							 , SUM(W02) AS W02
							 , SUM(W03) AS W03
						  FROM WEEKGDSINVPLN A
						 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
						    ON A.GDS_NUM = B.GDS_NUM 
						 WHERE IO_DAY = P_VER_ID
--						   AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--						   AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
						   AND DIV_COD = P_ITEM_DIV_CD
						   AND WHS_COD LIKE P_DC_CD ||'%'
--						   AND WHS_COD IN (SELECT T20.LOCAT_CD
--				                             FROM TB_CM_LOC_MGMT T10
--				                            INNER JOIN TB_CM_LOC_DTL T20
--				                               ON T10.LOCAT_ID = T20.ID
--				                            INNER JOIN TB_CM_LOC_MST T30
--				                               ON T20.LOCAT_MST_ID = T30.ID
--				                            INNER JOIN TB_AD_COMN_CODE T40
--				                               ON T30.LOCAT_TP_ID = T40.ID
--				                            WHERE T40.COMN_CD_NM = 'CDC'
--				                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
						   AND INV_PLN_DIV IN (33, 34)
					 	 GROUP BY IO_DAY, A.GDS_NUM, WHS_COD) A
				 INNER JOIN (SELECT IO_DAY
								  , A.GDS_NUM
								  , WHS_COD
								  , SUM(W00) AS W00
		 						  , SUM(W01) AS W01
								  , SUM(W02) AS W02
								  , SUM(W03) AS W03
							   FROM WEEKGDSINVPLN A
							  INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
							     ON A.GDS_NUM = B.GDS_NUM
							  WHERE IO_DAY = P_VER_ID
--							    AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
--							    AND DIV_COD LIKE P_ITEM_DIV_CD ||'%'
							    AND DIV_COD = P_ITEM_DIV_CD
							    AND WHS_COD LIKE P_DC_CD ||'%'							    
--							    AND WHS_COD IN (SELECT T20.LOCAT_CD
--					                             FROM TB_CM_LOC_MGMT T10
--					                            INNER JOIN TB_CM_LOC_DTL T20
--					                               ON T10.LOCAT_ID = T20.ID
--					                            INNER JOIN TB_CM_LOC_MST T30
--					                               ON T20.LOCAT_MST_ID = T30.ID
--					                            INNER JOIN TB_AD_COMN_CODE T40
--					                               ON T30.LOCAT_TP_ID = T40.ID
--					                            WHERE T40.COMN_CD_NM = 'CDC'
--					                              AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
							    AND INV_PLN_DIV IN (03, 04)
							  GROUP BY IO_DAY, A.GDS_NUM, WHS_COD) B
					ON A.IO_DAY = B.IO_DAY
				   AND A.GDS_NUM = B.GDS_NUM
				   AND A.WHS_COD = B.WHS_COD
				)
	)
	, AVG_TABLE AS (
		SELECT A.IO_DAY
			 , A.GDS_NUM
			 , A.WHS_COD
			 , INV_AVG
			 , RLS_AVG
			 , ORD_AVG
			 , STCK_AVG
		  FROM (SELECT IO_DAY
					 , GDS_NUM
					 , WHS_COD
					 , ROUND(AVG(MM), 1) AS INV_AVG
				  FROM INV
			   UNPIVOT (MM FOR AVG IN (INV_ACC_W00, INV_ACC_W01, INV_ACC_W02, INV_ACC_W03))
			     GROUP BY IO_DAY, GDS_NUM, WHS_COD) A
		 INNER JOIN (SELECT IO_DAY
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS RLS_AVG
					   FROM RLS
				    UNPIVOT (MM FOR AVG IN (RLS_ACC_W00, RLS_ACC_W01, RLS_ACC_W02, RLS_ACC_W03))
				      GROUP BY IO_DAY, GDS_NUM, WHS_COD) B
		    ON A.IO_DAY = B.IO_DAY
		   AND A.GDS_NUM = B.GDS_NUM
		   AND A.WHS_COD = B.WHS_COD
		 INNER JOIN (SELECT IO_DAY
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS ORD_AVG
					   FROM ORD
				    UNPIVOT (MM FOR AVG IN (ORD_ACC_W00, ORD_ACC_W01, ORD_ACC_W02, ORD_ACC_W03))
				      GROUP BY IO_DAY, GDS_NUM, WHS_COD) C
		    ON A.IO_DAY = C.IO_DAY
		   AND A.GDS_NUM = C.GDS_NUM
		   AND A.WHS_COD = C.WHS_COD
		 INNER JOIN (SELECT IO_DAY
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS STCK_AVG
					   FROM STCK
				    UNPIVOT (MM FOR AVG IN (STCK_ACC_W00, STCK_ACC_W01, STCK_ACC_W02, STCK_ACC_W03))
				      GROUP BY IO_DAY, GDS_NUM, WHS_COD) D
		    ON A.IO_DAY = D.IO_DAY
		   AND A.GDS_NUM = D.GDS_NUM
		   AND A.WHS_COD = D.WHS_COD
	)
	SELECT F.LOCAT_CD
		 , F.LOCAT_NM
		 , F.ITEM_CD
		 , F.ITEM_NM
		 , F.DMST_SRC_YN AS SRC_TP
		 , F.ITEM_LV_CD
		 , F.ITEM_LV_NM		 
		 , G.MD_MAIN_EMPID
		 , G.MD_MAIN_EMPNM
		 , G.PO_MAIN_EMPID
		 , G.PO_MAIN_EMPNM
		 , A.SFST_INV
		 , A.TARGET_INV
		 , A.END_INV
		 , A.INV_TURN
		 , E.INV_AVG
		 , E.RLS_AVG
		 , E.ORD_AVG
		 , E.STCK_AVG
		 , A.INV_ACC_W00
		 , B.RLS_ACC_W00
		 , C.ORD_ACC_W00
		 , D.STCK_ACC_W00
		 , A.INV_ACC_W01
		 , B.RLS_ACC_W01
		 , C.ORD_ACC_W01
		 , D.STCK_ACC_W01
		 , A.INV_ACC_W02
		 , B.RLS_ACC_W02
		 , C.ORD_ACC_W02
		 , D.STCK_ACC_W02
		 , A.INV_ACC_W03
		 , B.RLS_ACC_W03
		 , C.ORD_ACC_W03
		 , D.STCK_ACC_W03
--		 , A.INV_ACC_W04
--		 , A.INV_ACC_W05
--		 , A.INV_ACC_W06
--		 , A.INV_ACC_W07
--		 , A.INV_ACC_W08
--		 , A.INV_ACC_W09
--		 , A.INV_ACC_W10
--		 , A.INV_ACC_W11
--		 , A.INV_ACC_W12
	  FROM INV A
	 INNER JOIN RLS B
	    ON A.WHS_COD = B.WHS_COD
	   AND A.GDS_NUM = B.GDS_NUM
	   AND A.IO_DAY = B.IO_DAY
	 INNER JOIN ORD C
	    ON A.WHS_COD = C.WHS_COD
	   AND A.GDS_NUM = C.GDS_NUM
	   AND A.IO_DAY = C.IO_DAY
	 INNER JOIN STCK D
	    ON A.WHS_COD = D.WHS_COD
	   AND A.GDS_NUM = D.GDS_NUM
	   AND A.IO_DAY = D.IO_DAY
	 INNER JOIN AVG_TABLE E
	    ON A.WHS_COD = E.WHS_COD
	   AND A.GDS_NUM = E.GDS_NUM
	   AND A.IO_DAY = E.IO_DAY
	 INNER JOIN VW_LOCAT_ITEM_INFO_2 F
	    ON A.WHS_COD = F.LOCAT_CD
	   AND A.GDS_NUM = F.ITEM_CD
	 INNER JOIN VW_ITEM_INFO G
	    ON F.ITEM_CD = G.ITEM_CD
	   AND F.ITEM_LV_CD = G.ITEM_LV_CD
	   AND F.DMST_SRC_YN = G.KR_FR_SE
	 WHERE F.PO_SBJ_CD 	LIKE '%'|| P_PO_SBJ_CD 	 ||'%'
	   AND G.HMP_EMP_CD LIKE '%'|| P_HMP_EMP_CD  ||'%'
	   AND E.INV_AVG BETWEEN v_LOWER AND v_UPPER
	 ORDER BY E.INV_AVG DESC, ITEM_CD;
	COMMIT;
END;