CREATE OR REPLACE PROCEDURE DWSCM."SP_ASDS_RP_MM_INV_PLN_ACC_Q02" (
	P_VER_ID			IN VARCHAR2 := NULL, /*실적월*/	
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
* Purpose : 재고계획 준수율 (월간) (Grid 2)
* Notes   :
*********************************************************************************
* History :
* 2023-11-09 YJS CREATE
*********************************************************************************
* Execute :
DECLARE
	pRESULT SYS_REFCURSOR;
BEGIN
	SP_ASDS_RP_MM_INV_PLN_ACC_Q02(202310, '', '', '', '', '', '', '', '', pRESULT);
	DBMS_SQL.RETURN_RESULT(pRESULT);
END;
*********************************************************************************/
	
	v_LOWER NUMBER := NVL(P_LOWER, 0);
	v_UPPER NUMBER := NVL(P_UPPER, 100);
	
BEGIN
	
	
	OPEN pRESULT FOR
	WITH INV AS (
		SELECT A.IO_YYYYMM
			 , A.GDS_NUM
			 , A.WHS_COD
			 , CASE WHEN ABS(DMND_M00 - ACT_M00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M00			    		  
			 , CASE WHEN ABS(DMND_M01 - ACT_M01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M01				
			 , CASE WHEN ABS(DMND_M02 - ACT_M02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M02	
			 , CASE WHEN ABS(DMND_M03 - ACT_M03) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M03 - ACT_M03)/(ACT_M03 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M03 - ACT_M03)/(ACT_M03 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M03				
			 , CASE WHEN ABS(DMND_M04 - ACT_M04) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M04 - ACT_M04)/(ACT_M04 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M04 - ACT_M04)/(ACT_M04 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M04				
			 , CASE WHEN ABS(DMND_M05 - ACT_M05) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M05 - ACT_M05)/(ACT_M05 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M05 - ACT_M05)/(ACT_M05 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M05				
			 , CASE WHEN ABS(DMND_M06 - ACT_M06) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M06 - ACT_M06)/(ACT_M06 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M06 - ACT_M06)/(ACT_M06 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M06				
			 , CASE WHEN ABS(DMND_M07 - ACT_M07) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M07 - ACT_M07)/(ACT_M07 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M07 - ACT_M07)/(ACT_M07 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M07				
			 , CASE WHEN ABS(DMND_M08 - ACT_M08) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M08 - ACT_M08)/(ACT_M08 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_M08 - ACT_M08)/(ACT_M08 + 0.0001))*100,1)
							   ELSE 0 END) END AS INV_ACC_M08				
			 , CASE WHEN ABS(DMND_M09 - ACT_M09) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M09 - ACT_M09)/(ACT_M09 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_M09 - ACT_M09)/(ACT_M09 + 0.0001))*100,1) 
							   ELSE 0 END) END AS INV_ACC_M09				
			 , CASE WHEN ABS(DMND_M10 - ACT_M10) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M10 - ACT_M10)/(ACT_M10 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_M10 - ACT_M10)/(ACT_M10 + 0.0001))*100,1) 
							   ELSE 0 END) END AS INV_ACC_M10				
			 , CASE WHEN ABS(DMND_M11 - ACT_M11) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M11 - ACT_M11)/(ACT_M11 + 0.0001))	>= 0 THEN ROUND((1-ABS(DMND_M11 - ACT_M11)/(ACT_M11 + 0.0001))*100,1) 	 
							   ELSE 0 END) END AS INV_ACC_M11
			 , NVL(SFST_INV, 0) 	AS SFST_INV
			 , NVL(TARGET_INV, 0)   AS TARGET_INV
			 , NVL(END_INV, 0) 	    AS END_INV
			 , NVL(INV_TURN, 0)     AS INV_TURN				   
		  FROM (SELECT A.IO_YYYYMM
					 , A.GDS_NUM					 
					 , A.WHS_COD
					 , A.M00 AS DMND_M00
					 , A.M01 AS DMND_M01
					 , A.M02 AS DMND_M02
					 , A.M03 AS DMND_M03
					 , A.M04 AS DMND_M04
					 , A.M05 AS DMND_M05
					 , A.M06 AS DMND_M06
					 , A.M07 AS DMND_M07
					 , A.M08 AS DMND_M08
					 , A.M09 AS DMND_M09
					 , A.M10 AS DMND_M10
					 , A.M11 AS DMND_M11
					 , B.M00 AS ACT_M00
					 , B.M01 AS ACT_M01
					 , B.M02 AS ACT_M02
					 , B.M03 AS ACT_M03
					 , B.M04 AS ACT_M04
					 , B.M05 AS ACT_M05
					 , B.M06 AS ACT_M06
					 , B.M07 AS ACT_M07
					 , B.M08 AS ACT_M08
					 , B.M09 AS ACT_M09
					 , B.M10 AS ACT_M10
					 , B.M11 AS ACT_M11
				 FROM (SELECT IO_YYYYMM
				 	 		, A.GDS_NUM
				 	 		, WHS_COD
				 	 		, M00
							, M01
							, M02
							, M03
							, M04
							, M05
							, M06
							, M07
							, M08
							, M09
							, M10
							, M11
				 	     FROM MONGDSINVPLN A
				 	    INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
				 	       ON A.GDS_NUM = B.GDS_NUM 
				 	    WHERE IO_YYYYMM = P_VER_ID
				 	      AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
				 	      AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
    				 	  AND INV_PLN_DIV = 45) A
				INNER JOIN (SELECT IO_YYYYMM
					 	 		 , A.GDS_NUM
					 	 		 , WHS_COD
								 , M00
								 , M01
								 , M02
								 , M03
								 , M04
								 , M05
							 	 , M06
						 		 , M07
								 , M08
								 , M09
								 , M10
								 , M11					 	 		 
					 	      FROM MONGDSINVPLN A
	 				 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 				
					 	     WHERE 1=1
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 15) B			 	        
				   ON A.IO_YYYYMM = B.IO_YYYYMM
				  AND A.GDS_NUM = B.GDS_NUM
				  AND A.WHS_COD = B.WHS_COD) A
				LEFT JOIN (SELECT IO_YYYYMM
								 , A.GDS_NUM
								 , WHS_COD
								 , M00 AS SFST_INV
							  FROM MONGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_YYYYMM = P_VER_ID
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 51) B
				  ON A.IO_YYYYMM = B.IO_YYYYMM
				 AND A.GDS_NUM = B.GDS_NUM
				 AND A.WHS_COD = B.WHS_COD
				LEFT JOIN (SELECT IO_YYYYMM
								 , A.GDS_NUM
								 , WHS_COD
								 , M00 AS TARGET_INV
							  FROM MONGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_YYYYMM = P_VER_ID
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 53) C
				  ON A.IO_YYYYMM = C.IO_YYYYMM
				 AND A.GDS_NUM = C.GDS_NUM
				 AND A.WHS_COD = C.WHS_COD
				LEFT JOIN (SELECT IO_YYYYMM
								 , A.GDS_NUM
								 , WHS_COD
								 , M00 AS END_INV
							  FROM MONGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_YYYYMM = P_VER_ID
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 45) D
				  ON A.IO_YYYYMM = D.IO_YYYYMM
				 AND A.GDS_NUM = D.GDS_NUM
				 AND A.WHS_COD = D.WHS_COD 
				LEFT JOIN (SELECT IO_YYYYMM
								 , A.GDS_NUM
								 , WHS_COD
								 , M00 AS INV_TURN
							  FROM MONGDSINVPLN A
							 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM 
					 	     WHERE IO_YYYYMM = P_VER_ID
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 46) E 
				  ON A.IO_YYYYMM = E.IO_YYYYMM
				 AND A.GDS_NUM = E.GDS_NUM
				 AND A.WHS_COD = E.WHS_COD  	  
	)
	, RLS AS (
		SELECT IO_YYYYMM
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_M00 - ACT_M00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_M00			    		  
			 , CASE WHEN ABS(DMND_M01 - ACT_M01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_M01				
			 , CASE WHEN ABS(DMND_M02 - ACT_M02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001)) >=  0 THEN ROUND((1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001))*100,1)
							   ELSE 0 END) END AS RLS_ACC_M02						
		  FROM (SELECT A.IO_YYYYMM
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.M00 AS DMND_M00
					 , A.M01 AS DMND_M01
					 , A.M02 AS DMND_M02
					 , B.M00 AS ACT_M00
					 , B.M01 AS ACT_M01
					 , B.M02 AS ACT_M02	 
				 FROM (SELECT IO_YYYYMM
				 	 		, A.GDS_NUM
				 	 		, WHS_COD
				 	 		, M00
				 	 		, M01
				 	 		, M02				 	 		
				 	     FROM MONGDSINVPLN A
 				 	    INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
 				 	       ON A.GDS_NUM = B.GDS_NUM
				 	    WHERE IO_YYYYMM = P_VER_ID
				 	      AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
				 	      AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
				 	      AND INV_PLN_DIV = 35) A 				
				INNER JOIN (SELECT IO_YYYYMM
					 	 		 , A.GDS_NUM
					 	 		 , WHS_COD
					 	 		 , M00
					 	 		 , M01
					 	 		 , M02
					 	      FROM MONGDSINVPLN A
					 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	        ON A.GDS_NUM = B.GDS_NUM
					 	     WHERE IO_YYYYMM = P_VER_ID
					 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	       AND INV_PLN_DIV = 09) B			 	     
				   ON A.IO_YYYYMM = B.IO_YYYYMM
				  AND A.GDS_NUM = B.GDS_NUM
				  AND A.WHS_COD = B.WHS_COD)
	) 
	, ORD AS (
		SELECT IO_YYYYMM
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_M00 - ACT_M00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_M00			    		  
			 , CASE WHEN ABS(DMND_M01 - ACT_M01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_M01				
			 , CASE WHEN ABS(DMND_M02 - ACT_M02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001))*100,1)
							   ELSE 0 END) END AS ORD_ACC_M02					
		  FROM (SELECT A.IO_YYYYMM
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.M00 AS DMND_M00
					 , A.M01 AS DMND_M01
					 , A.M02 AS DMND_M02
					 , B.M00 AS ACT_M00
					 , B.M01 AS ACT_M01
					 , B.M02 AS ACT_M02	 
				  FROM (SELECT IO_YYYYMM
				 	 		 , A.GDS_NUM
				 	 		 , WHS_COD
				 	 		 , M00
				 	 		 , M01
				 	 		 , M02
				 	      FROM MONGDSINVPLN A
				 	     INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
				 	        ON A.GDS_NUM = B.GDS_NUM
				 	     WHERE IO_YYYYMM = P_VER_ID
				 	       AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
				 	       AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
				 	       AND INV_PLN_DIV = 56) A
			     INNER JOIN (SELECT IO_YYYYMM
					 	 		  , A.GDS_NUM
					 	 		  , WHS_COD
					 	 		  , M00
					 	 		  , M01
					 	 		  , M02
					 	       FROM MONGDSINVPLN A
					 	      INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
					 	         ON A.GDS_NUM = B.GDS_NUM 
					 	      WHERE IO_YYYYMM = P_VER_ID
					 	        AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
					 	        AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
					 	        AND INV_PLN_DIV = 05) B
				    ON A.IO_YYYYMM = B.IO_YYYYMM
				   AND A.GDS_NUM = B.GDS_NUM
				   AND A.WHS_COD = B.WHS_COD
				)
	)
	, STCK AS (
		SELECT IO_YYYYMM
			 , GDS_NUM
			 , WHS_COD
			 , CASE WHEN ABS(DMND_M00 - ACT_M00) = 0 THEN 100
				    ELSE (CASE WHEN (1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M00 - ACT_M00)/(ACT_M00 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_M00			    		  
			 , CASE WHEN ABS(DMND_M01 - ACT_M01) = 0 THEN 100
					ELSE (CASE WHEN (1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M01 - ACT_M01)/(ACT_M01 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_M01				
			 , CASE WHEN ABS(DMND_M02 - ACT_M02) = 0 THEN 100 
					ELSE (CASE WHEN (1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001)) >= 0 THEN ROUND((1-ABS(DMND_M02 - ACT_M02)/(ACT_M02 + 0.0001))*100,1)
							   ELSE 0 END) END AS STCK_ACC_M02							
		  FROM (SELECT A.IO_YYYYMM
					 , A.GDS_NUM
					 , A.WHS_COD
					 , A.M00 AS DMND_M00
					 , A.M01 AS DMND_M01
					 , A.M02 AS DMND_M02
					 , B.M00 AS ACT_M00
					 , B.M01 AS ACT_M01
					 , B.M02 AS ACT_M02	 
				  FROM (SELECT IO_YYYYMM
							 , A.GDS_NUM
							 , WHS_COD
							 , SUM(M00) AS M00
	 						 , SUM(M01) AS M01
							 , SUM(M02) AS M02
						  FROM MONGDSINVPLN A
						 INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
						    ON A.GDS_NUM = B.GDS_NUM 
						 WHERE IO_YYYYMM = P_VER_ID
						   AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
						   AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
						   AND INV_PLN_DIV IN (33, 34)
					 	 GROUP BY IO_YYYYMM, A.GDS_NUM, WHS_COD) A
				 INNER JOIN (SELECT IO_YYYYMM
								  , A.GDS_NUM
								  , WHS_COD
								  , SUM(M00) AS M00
		 						  , SUM(M01) AS M01
								  , SUM(M02) AS M02
							   FROM MONGDSINVPLN A
							  INNER JOIN (SELECT LVL04_CD AS DIV_COD, LVL05_CD AS GDS_NUM FROM TB_DPD_ITEM_HIERACHY2) B 
							     ON A.GDS_NUM = B.GDS_NUM
							  WHERE IO_YYYYMM = P_VER_ID
							    AND DIV_COD LIKE '%'|| P_ITEM_DIV_CD ||'%'
							    AND WHS_COD IN (SELECT T20.LOCAT_CD
				                           FROM TB_CM_LOC_MGMT T10
				                          INNER JOIN TB_CM_LOC_DTL T20
				                             ON T10.LOCAT_ID = T20.ID
				                          INNER JOIN TB_CM_LOC_MST T30
				                             ON T20.LOCAT_MST_ID = T30.ID
				                          INNER JOIN TB_AD_COMN_CODE T40
				                             ON T30.LOCAT_TP_ID = T40.ID
				                          WHERE T40.COMN_CD_NM = 'CDC'
				                            AND T20.LOCAT_CD LIKE '%'|| P_DC_CD ||'%')
							    AND INV_PLN_DIV IN (03, 04)
							  GROUP BY IO_YYYYMM, A.GDS_NUM, WHS_COD) B
					ON A.IO_YYYYMM = B.IO_YYYYMM
				   AND A.GDS_NUM = B.GDS_NUM
				   AND A.WHS_COD = B.WHS_COD
				)
	)
	, AVG_TABLE AS (
		SELECT A.IO_YYYYMM
			 , A.GDS_NUM
			 , A.WHS_COD
			 , INV_AVG
			 , RLS_AVG
			 , ORD_AVG
			 , STCK_AVG
		  FROM (SELECT IO_YYYYMM
					 , GDS_NUM
					 , WHS_COD
					 , ROUND(AVG(MM), 1) AS INV_AVG
				  FROM INV
			   UNPIVOT (MM FOR AVG IN (INV_ACC_M00, INV_ACC_M01, INV_ACC_M02))
			     GROUP BY IO_YYYYMM, GDS_NUM, WHS_COD) A
		 INNER JOIN (SELECT IO_YYYYMM
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS RLS_AVG
					   FROM RLS
				    UNPIVOT (MM FOR AVG IN (RLS_ACC_M00, RLS_ACC_M01, RLS_ACC_M02))
				      GROUP BY IO_YYYYMM, GDS_NUM, WHS_COD) B
		    ON A.IO_YYYYMM = B.IO_YYYYMM
		   AND A.GDS_NUM = B.GDS_NUM
		   AND A.WHS_COD = B.WHS_COD
		 INNER JOIN (SELECT IO_YYYYMM
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS ORD_AVG
					   FROM ORD
				    UNPIVOT (MM FOR AVG IN (ORD_ACC_M00, ORD_ACC_M01, ORD_ACC_M02))
				      GROUP BY IO_YYYYMM, GDS_NUM, WHS_COD) C
		    ON A.IO_YYYYMM = C.IO_YYYYMM
		   AND A.GDS_NUM = C.GDS_NUM
		   AND A.WHS_COD = C.WHS_COD
		 INNER JOIN (SELECT IO_YYYYMM
						  , GDS_NUM
						  , WHS_COD
						  , ROUND(AVG(MM), 1) AS STCK_AVG
					   FROM STCK
				    UNPIVOT (MM FOR AVG IN (STCK_ACC_M00, STCK_ACC_M01, STCK_ACC_M02))
				      GROUP BY IO_YYYYMM, GDS_NUM, WHS_COD) D
		    ON A.IO_YYYYMM = D.IO_YYYYMM
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
		 , A.INV_ACC_M00
		 , B.RLS_ACC_M00
		 , C.ORD_ACC_M00
		 , D.STCK_ACC_M00
		 , A.INV_ACC_M01
		 , B.RLS_ACC_M01
		 , C.ORD_ACC_M01
		 , D.STCK_ACC_M01
		 , A.INV_ACC_M02
		 , B.RLS_ACC_M02
		 , C.ORD_ACC_M02
		 , D.STCK_ACC_M02
		 , A.INV_ACC_M03
		 , A.INV_ACC_M04
		 , A.INV_ACC_M05
		 , A.INV_ACC_M06
		 , A.INV_ACC_M07
		 , A.INV_ACC_M08
		 , A.INV_ACC_M09
		 , A.INV_ACC_M10
		 , A.INV_ACC_M11
	  FROM INV A
	 INNER JOIN RLS B
	    ON A.WHS_COD = B.WHS_COD
	   AND A.GDS_NUM = B.GDS_NUM
	   AND A.IO_YYYYMM = B.IO_YYYYMM
	 INNER JOIN ORD C
	    ON A.WHS_COD = C.WHS_COD
	   AND A.GDS_NUM = C.GDS_NUM
	   AND A.IO_YYYYMM = C.IO_YYYYMM
	 INNER JOIN STCK D
	    ON A.WHS_COD = D.WHS_COD
	   AND A.GDS_NUM = D.GDS_NUM
	   AND A.IO_YYYYMM = D.IO_YYYYMM
	 INNER JOIN AVG_TABLE E
	    ON A.WHS_COD = E.WHS_COD
	   AND A.GDS_NUM = E.GDS_NUM
	   AND A.IO_YYYYMM = E.IO_YYYYMM
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