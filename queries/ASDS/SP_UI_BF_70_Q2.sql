CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_70_Q2" (
     p_VER_CD    IN VARCHAR2
   , p_ITEM_LV	 IN VARCHAR2
   , p_ITEM_CD	 IN VARCHAR2
   , p_SALES_LV  IN VARCHAR2
   , p_SALES_CD  IN VARCHAR2
   , p_SRC_TP    IN VARCHAR2 	
   , p_ASG_ID    IN VARCHAR2	
   , p_EMP_ID    IN VARCHAR2
   , p_SUM 		 IN VARCHAR2
   , p_SALES	 IN VARCHAR2
   , p_FCST		 IN VARCHAR2
   , p_ACCRY	 IN VARCHAR2
   , pRESULT     OUT SYS_REFCURSOR
)
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_70_Q2
   * Purpose : 수요예측 결과 리스트(월) 조회
   * Notes :
   *    M20180115092445697M411878346346N	ITEM_ALL	상품전체
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
	SP_UI_BF_70_Q2('BFM-20230901-01', 'M20180115092445697M411878346346N', 'ITEM_ALL', 'N20180115092712856O251735022591O','ALL', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	SP_UI_BF_70_Q2('BFM-20230901-01', 'N20180115092528519N506441512113N', 'A', 'N20180115092712856O251735022591O','ALL', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	SP_UI_BF_70_Q2('BFM-20230901-01', 'N20180115092559329M499525073971N', 'AC', 'N20180115092712856O251735022591O','ALL', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	SP_UI_BF_70_Q2('BFM-20230901-01', 'FA5FEBBCADDED90DE053DD0A10AC8DB5', 'AC01', 'N20180115092712856O251735022591O','ALL', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	SP_UI_BF_70_Q2('BFM-20230901-01', 'M20180115092627169N446701842271O', '1001659', 'N20180115092710840N520475678180O','01_POS', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	SP_UI_BF_70_Q2('BFM-20230901-01', 'M20180115092627169N446701842271O', '1001659', 'FE00001E54F88F3FE053DD0A10AC762B','01', '', '', '', 'Y', 'Y', 'Y', 'Y', pRESULT);
	DBMS_SQL.RETURN_RESULT(pRESULT);
END;
 */

IS
	v_ASG_ID VARCHAR2(100);
	v_ASG_CD VARCHAR2(100);	
	v_EMP_NM VARCHAR2(30);
	v_MIN_BASE_DATE DATE;
	v_MAX_BASE_DATE DATE;
	v_EXISTS_NUM INT := 0;
	v_NUM INT := 0;
	
	v_SQL_DATE VARCHAR2(10000) := '';
	v_SQL_COMMON1 VARCHAR2(30000) := '';
	v_SQL_COMMON2 VARCHAR2(30000) := '';
	v_SQL_COMMON3 VARCHAR2(30000) := '';
	v_SQL_COMMON4 VARCHAR2(30000) := '';
	v_SQL_COMMON5 VARCHAR2(30000) := '';
	v_SQL_COMMON6 VARCHAR2(30000) := '';
	v_SQL VARCHAR2(30000) := '';

	v_SRC_TP VARCHAR2(10) := NVL(p_SRC_TP, '');
	v_SUM  	 VARCHAR2(10) := NVL(p_SUM, 'Y');

	v_FCST		VARCHAR2(10) := NVL(p_FCST, 'Y');
	v_SALES		VARCHAR2(10) := NVL(p_SALES, 'Y');
	v_ACCRY		VARCHAR2(10) := NVL(p_ACCRY, 'Y');

BEGIN 
	/* 가장 최근 버전 선택 */
    SELECT MAX(TARGET_FROM_DATE)
    	 , MAX(TARGET_TO_DATE)
      INTO 
      	   v_MIN_BASE_DATE
      	 , v_MAX_BASE_DATE
 	  FROM TB_BF_CONTROL_BOARD_VER_DTL
	  WHERE VER_CD = p_VER_CD;	   
	/* 동적 쿼리 생성 */
	FOR i IN (SELECT DAT AS BASE_DATE FROM TB_CM_CALENDAR WHERE DAT BETWEEN v_MIN_BASE_DATE AND v_MAX_BASE_DATE AND DD = 1 ORDER BY 1)	
	LOOP 
		v_NUM := v_NUM + 1;
		v_SQL_DATE := v_SQL_DATE || ', ''' || i.BASE_DATE || '''' || 'AS M' || LPAD(v_NUM, 2, '0') ;
	END LOOP;


	v_ASG_ID := NVL(p_ASG_ID, '04AACEB1934DDC9FE0632A0A10ACAB8F');

	SELECT CASE CONF_CD WHEN 'ORDER' THEN '발주' WHEN 'MD' THEN 'MD' ELSE NULL END INTO v_ASG_CD
	  FROM TB_CM_COMM_CONFIG  
	 WHERE CONF_ID = '04AACEB1934CDC9FE0632A0A10ACAB8F'
	   AND ACTV_YN = 'Y'
	   AND ID LIKE v_ASG_ID||'%';
	  
	IF v_ASG_CD IS NOT NULL
	THEN 
		SELECT DISTINCT EMP_NM INTO v_EMP_NM FROM TB_CM_USER_CATE WHERE ASSIGN = v_ASG_CD AND EMP_ID = p_EMP_ID AND MAIN_SUB = '정';
	ELSE
		v_EMP_NM := 'NULL';
	END IF;	  

	/* 계층 선택에 따른 숫자 부여 */    
	SELECT CASE WHEN EXISTS (SELECT 1 FROM DUAL WHERE 'M20180115092445697M411878346346N' = p_ITEM_LV) THEN 5
				WHEN EXISTS (SELECT 1 FROM DUAL WHERE 'N20180115092528519N506441512113N' = p_ITEM_LV) THEN 4
				WHEN EXISTS (SELECT 1 FROM DUAL WHERE 'N20180115092559329M499525073971N' = p_ITEM_LV) THEN 3
				WHEN EXISTS (SELECT 1 FROM DUAL WHERE 'FA5FEBBCADDED90DE053DD0A10AC8DB5' = p_ITEM_LV) THEN 2
				WHEN EXISTS (SELECT 1 FROM DUAL WHERE 'M20180115092627169N446701842271O' = p_ITEM_LV) THEN 1
				END INTO v_EXISTS_NUM
		FROM DUAL;
   
   v_SQL_COMMON1 := ' WITH IDS AS (
							SELECT A.DESC_ID
								 , A.DESC_CD
								 , A.DESC_NM
								 , A.ANCS_CD
								 , A.ANCS_NM
								 , B.LVL04_CD
								 , UMO.EMP_NM AS ORDER_EMP_NM
								 , UMM.EMP_NM AS MD_EMP_NM
	   						  FROM (
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
							           AND IL.LV_MGMT_ID = '''|| p_ITEM_LV || '''
							           AND IH.LEAF_YN = ''Y''
							           AND IM.ATTR_03 LIKE '''|| v_SRC_TP || '''||''%''
							           AND ANCESTER_CD LIKE ''' || p_ITEM_CD || '''||''%''
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
							           AND IH.LEAF_YN = ''Y''
							           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_CM_ITEM_LEVEL_MGMT WHERE LV_MGMT_ID = '''|| p_ITEM_LV || ''') THEN 0 ELSE 1 END
							           AND IT.ATTR_03 LIKE '''|| v_SRC_TP || '''||''%''
							           AND ANCESTER_CD LIKE ''' || p_ITEM_CD || '''||''%''
						       ) A
						 INNER JOIN TB_DPD_ITEM_HIERACHY2 B
						    ON A.DESC_CD = B.LVL05_CD
						 INNER JOIN (SELECT DISTINCT EMP_ID, EMP_NM, CATEGORY, ASSIGN FROM TB_CM_USER_CATE WHERE MAIN_SUB = ''정'' AND ASSIGN = ''발주'') UMO 
						    ON B.LVL04_CD = UMO.CATEGORY						                                                                      
						 INNER JOIN (SELECT DISTINCT EMP_ID, EMP_NM, CATEGORY, ASSIGN FROM TB_CM_USER_CATE WHERE MAIN_SUB = ''정'' AND ASSIGN = ''MD'') UMM
						    ON B.LVL04_CD = UMM.CATEGORY	
						 WHERE (
								    (UMO.ASSIGN LIKE '''|| v_ASG_CD ||'''||''%'' AND UMO.EMP_ID = '''|| p_EMP_ID ||''')     
								 OR (UMM.ASSIGN LIKE '''|| v_ASG_CD ||'''||''%'' AND UMM.EMP_ID = '''|| p_EMP_ID ||''')    
								 OR ('''|| v_ASG_CD ||''' IS NULL AND (UMO.EMP_ID LIKE '''|| p_EMP_ID ||'''||''%'' OR UMM.EMP_ID LIKE '''|| p_EMP_ID ||'''||''%''))
								 OR ('''|| p_EMP_ID ||''' IS NULL)
							   ) 
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
					           AND SL.LV_MGMT_ID = ''' || p_SALES_LV || '''
					           AND SH.LEAF_YN = ''Y'' 
					           AND ANCESTER_CD LIKE ''' || p_SALES_CD|| '''||''%''  
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
					           AND SH.LEAF_YN = ''Y''
					           AND 1 = CASE WHEN EXISTS (SELECT 1 FROM TB_DP_SALES_LEVEL_MGMT WHERE LV_MGMT_ID = ''' || p_SALES_LV || ''') THEN 0 ELSE 1 END
					           AND ANCESTER_CD LIKE ''' || p_SALES_CD|| '''||''%''
					    )';
					   
	v_SQL_COMMON2 := '
					 PIVOT( 
							SUM(ACT_SALES) FOR BASE_DATE IN ('|| SUBSTR(v_SQL_DATE, 2, LENGTH(v_SQL_DATE)) ||')
						  )
					';
	v_SQL_COMMON3 := '
					 PIVOT( 
							SUM(BF_QTY) FOR BASE_DATE IN ('|| SUBSTR(v_SQL_DATE, 2, LENGTH(v_SQL_DATE)) ||')
						  )
					';				
	v_SQL_COMMON4 := '
					 PIVOT( 
							SUM(WAPE) FOR BASE_DATE IN ('|| SUBSTR(v_SQL_DATE, 2, LENGTH(v_SQL_DATE)) ||')
						  )
					';			
	v_SQL_COMMON5 := '
					, SA AS (
						SELECT *
						  FROM (
						SELECT DIV_MAX
				  			 , DIV_MAX_NAM
				  			 , DIV_MID
				  			 , DIV_MID_NAM
					         , DIV_MIN
				             , DIV_MIN_NAM
				             , GDS_COD
			  				 , GDS_NAM
				             , ORDER_EMP_NAM
				             , MD_EMP_NAM
				             , SRC_COD
				             , ACCOUNT_CD
				             , ACCOUNT_NM
							 , BASE_DATE
							 , ''ACT_SALES'' AS CATEGORY
							 , 1 AS ORDER_VAL
							 , SUM(ACT_SALES) AS ACT_SALES
						  FROM AGG
						  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
						  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE
						 )
						' || v_SQL_COMMON2 || ' 
						WHERE CASE WHEN ''' || v_SALES || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_SALES || ''' IS NULL	
						)
					, RT AS (
						SELECT *
						  FROM (
						SELECT DIV_MAX
				  			 , DIV_MAX_NAM
				  			 , DIV_MID
				  			 , DIV_MID_NAM
					         , DIV_MIN
				             , DIV_MIN_NAM
				             , GDS_COD
			  				 , GDS_NAM
				             , ORDER_EMP_NAM
				             , MD_EMP_NAM
				             , SRC_COD
				             , ACCOUNT_CD
				             , ACCOUNT_NM
							 , BASE_DATE
							 , ''BF_QTY'' AS CATEGORY
							 , 2 AS ORDER_VAL
							 , SUM(BF_QTY) AS BF_QTY
						  FROM AGG
						  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
						  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE				  
						 )				 		
						' || v_SQL_COMMON3 || ' 
						WHERE CASE WHEN ''' || v_FCST || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_FCST || ''' IS NULL								
					)
					, WAPE AS (
						SELECT *
						  FROM (
						SELECT DIV_MAX
				  			 , DIV_MAX_NAM
				  			 , DIV_MID
				  			 , DIV_MID_NAM
					         , DIV_MIN
				             , DIV_MIN_NAM
				             , GDS_COD
			  				 , GDS_NAM
				             , ORDER_EMP_NAM
				             , MD_EMP_NAM
				             , SRC_COD
				             , ACCOUNT_CD
				             , ACCOUNT_NM
							 , BASE_DATE
							 , ''DMND_PRDICT_ACCURCY'' AS CATEGORY
							 , 3 AS ORDER_VAL
							 , SUM(WAPE) AS WAPE
						  FROM AGG
						  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
						  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE				  
						 )				 		
						' || v_SQL_COMMON4 || '	
						WHERE CASE WHEN ''' || v_ACCRY || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_ACCRY || ''' IS NULL	
					) 
					';			
	v_SQL_COMMON6 := '
					, ACC AS (
					SELECT DIV_MAX
			  			 , DIV_MAX_NAM
			  			 , DIV_MID
			  			 , DIV_MID_NAM
				         , DIV_MIN
			             , DIV_MIN_NAM
			             , GDS_COD
		  				 , GDS_NAM
			             , ORDER_EMP_NAM
			             , MD_EMP_NAM
			             , SRC_COD
			             , ACCOUNT_CD
			             , ACCOUNT_NM
			             , CASE WHEN SUM(ERR) = 0 THEN ''100%''
                            WHEN (1 - SUM(ERR) / (SUM(ACT_SALES) + 0.00001)) * 100 <= 0 THEN ''0%''                    
                            ELSE RTRIM(TO_CHAR(ROUND(100 - (SUM(ERR)  / (SUM(ACT_SALES) + 0.00001)) * 100, 1)), TO_CHAR(0, ''D'')) ||''%'' END AS TOTAL_ACCRY
			            FROM AGG
			            GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
					  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM
					) ';				
	/* 합계 조회 아닐 시 */			
	IF v_SUM = 'N'
	THEN
	v_SQL := ', AGG AS (
				SELECT IH.LVL02_CD      AS DIV_MAX
		  			 , IH.LVL02_NM      AS DIV_MAX_NAM
		  			 , IH.LVL03_CD      AS DIV_MID
		  			 , IH.LVL03_NM      AS DIV_MID_NAM
			         , IH.LVL04_CD		AS DIV_MIN
		             , IH.LVL04_NM 		AS DIV_MIN_NAM
		             , A.ITEM_CD        AS GDS_COD
	  				 , A.ITEM_NM        AS GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
					SELECT I.DESC_CD        AS ITEM_CD
			  			 , I.DESC_NM        AS ITEM_NM
						 , A.ANCS_CD 		AS ACCOUNT_CD
						 , A.ANCS_NM 		AS ACCOUNT_NM
 						 , I.ORDER_EMP_NM 	AS ORDER_EMP_NAM
						 , I.MD_EMP_NM		AS MD_EMP_NAM
						 , RT.BASE_DATE
						 , SUM(RT.QTY)	 	AS BF_QTY
						 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
						 		ELSE NULL END AS ACT_SALES
						 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								ELSE NULL END AS ERR
			          FROM TB_BF_RT_FINAL_M RT
			          LEFT JOIN (SELECT BASE_DATE, I.DESC_CD AS ITEM_CD, A.DESC_CD AS ACCOUNT_CD, QTY 
			         			  FROM TB_CM_ACTUAL_SALES_M_HIST SA
			         			 INNER JOIN IDS I ON SA.ITEM_MST_ID = I.DESC_ID
			         			 INNER JOIN ADS A ON SA.ACCOUNT_ID = A.DESC_ID
			         			 WHERE VER_CD = ''' || p_VER_CD || ''') SA
			            ON RT.ITEM_CD = SA.ITEM_CD
			           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
			           AND RT.BASE_DATE = SA.BASE_DATE
			         INNER JOIN IDS I ON RT.ITEM_CD = I.DESC_CD
			         INNER JOIN ADS A ON RT.ACCOUNT_CD = A.DESC_CD	
			         WHERE RT.VER_CD = ''' || p_VER_CD || '''         
			         GROUP BY I.DESC_CD, I.DESC_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE, I.ORDER_EMP_NM, I.MD_EMP_NM
			      	  ) A
			      INNER JOIN (SELECT LVL02_CD, LVL02_NM, LVL03_CD, LVL03_NM, LVL04_CD, LVL04_NM, LVL05_CD, LVL05_NM FROM TB_DPD_ITEM_HIERACHY2) IH
			         ON A.ITEM_CD = IH.LVL05_CD
			        AND A.ITEM_NM = IH.LVL05_NM			
			)
			' || v_SQL_COMMON6 || ' 
			, SA AS (
				SELECT *
				  FROM (
				SELECT DIV_MAX
		  			 , DIV_MAX_NAM
		  			 , DIV_MID
		  			 , DIV_MID_NAM
			         , DIV_MIN
		             , DIV_MIN_NAM
		             , GDS_COD
	  				 , GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , SRC_COD
		             , ACCOUNT_CD
		             , ACCOUNT_NM
					 , BASE_DATE
					 , ''ACT_SALES'' AS CATEGORY
					 , 1 AS ORDER_VAL
					 , SUM(ACT_SALES) AS ACT_SALES
				  FROM AGG
				  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
				  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE
				 )
				' || v_SQL_COMMON2 || ' 
				WHERE CASE WHEN ''' || v_SALES || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_SALES || ''' IS NULL	
				)
			, RT AS (
				SELECT *
				  FROM (
				SELECT DIV_MAX
		  			 , DIV_MAX_NAM
		  			 , DIV_MID
		  			 , DIV_MID_NAM
			         , DIV_MIN
		             , DIV_MIN_NAM
		             , GDS_COD
	  				 , GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , SRC_COD
		             , ACCOUNT_CD
		             , ACCOUNT_NM
					 , BASE_DATE
					 , ''BF_QTY'' AS CATEGORY
					 , 2 AS ORDER_VAL
					 , SUM(BF_QTY) AS BF_QTY
				  FROM AGG
				  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
				  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE				  
				 )				 		
				' || v_SQL_COMMON3 || ' 
				WHERE CASE WHEN ''' || v_FCST || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_FCST || ''' IS NULL								
			)
			, WAPE AS (
				SELECT *
				  FROM (
				SELECT DIV_MAX
		  			 , DIV_MAX_NAM
		  			 , DIV_MID
		  			 , DIV_MID_NAM
			         , DIV_MIN
		             , DIV_MIN_NAM
		             , GDS_COD
	  				 , GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , SRC_COD
		             , ACCOUNT_CD
		             , ACCOUNT_NM
					 , BASE_DATE
					 , ''DMND_PRDICT_ACCURCY'' AS CATEGORY
					 , 3 AS ORDER_VAL
					 , SUM(WAPE) AS WAPE
				  FROM AGG
				  GROUP BY DIV_MAX, DIV_MAX_NAM, DIV_MID, DIV_MID_NAM, DIV_MIN, DIV_MIN_NAM
				  		 , GDS_COD, GDS_NAM, ORDER_EMP_NAM, MD_EMP_NAM, SRC_COD, ACCOUNT_CD, ACCOUNT_NM, BASE_DATE				  
				 )				 		
				' || v_SQL_COMMON4 || '	
				WHERE CASE WHEN ''' || v_ACCRY || ''' = ''Y'' THEN 1 ELSE 2 END = 1 OR ''' || v_ACCRY || ''' IS NULL	
			) 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 	
				 , B.TOTAL_ACCRY			     
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY 1, 3, 5, 7, A.ACCOUNT_CD, ORDER_VAL';
				   
	/* 품목 전체 합계 조회 */				   
	ELSIF v_EXISTS_NUM = 5 AND v_SUM = 'Y'
	THEN 
	v_SQL := '
			, AGG AS (
				SELECT ''ALL''      AS DIV_MAX
		  			 , ''ALL''      AS DIV_MAX_NAM
		  			 , ''ALL''     	AS DIV_MID
		  			 , ''ALL''      AS DIV_MID_NAM
		  			 , ''ALL''		AS DIV_MIN
		  			 , ''ALL''		AS DIV_MIN_NAM
		  			 , ''ALL''      AS GDS_COD
		  			 , ''ALL''      AS GDS_NAM
		             , NULL			AS ORDER_EMP_NAM
		             , NULL			AS MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
						SELECT I.ANCS_CD        AS ITEM_CD
				  			 , I.ANCS_NM        AS ITEM_NM
							 , A.ANCS_CD 		AS ACCOUNT_CD
							 , A.ANCS_NM 		AS ACCOUNT_NM
							 , RT.BASE_DATE
							 , SUM(RT.QTY)	 	AS BF_QTY
							 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
							 		ELSE NULL END AS ACT_SALES
						     , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								    ELSE NULL END AS ERR
				          FROM TB_BF_RT_FINAL_M RT
				          LEFT JOIN (SELECT BASE_DATE
				          				  , I.DESC_CD AS ITEM_CD
				          				  , A.DESC_CD AS ACCOUNT_CD
				          				  , QTY 
				         			   FROM TB_CM_ACTUAL_SALES_M_HIST SA
				         			  INNER JOIN IDS I 
				         			  	 ON SA.ITEM_MST_ID = I.DESC_ID
				         			  INNER JOIN ADS A 
				         			     ON SA.ACCOUNT_ID = A.DESC_ID
				         			  WHERE VER_CD = ''' || p_VER_CD || ''') SA
				            ON RT.ITEM_CD = SA.ITEM_CD
				           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
				           AND RT.BASE_DATE = SA.BASE_DATE
				         INNER JOIN IDS I 
				         	ON RT.ITEM_CD = I.DESC_CD
				         INNER JOIN ADS A 
				         	ON RT.ACCOUNT_CD = A.DESC_CD	
				         WHERE RT.VER_CD = ''' || p_VER_CD || '''        
				         GROUP BY I.ANCS_CD, I.ANCS_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE
			      	  ) A			
			)		
			' || v_SQL_COMMON5 || '	
			' || v_SQL_COMMON6 || ' 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 			
				 , B.TOTAL_ACCRY	     
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY A.ACCOUNT_CD, ORDER_VAL';
		
	/* 대분류 합계 조회*/
	ELSIF v_EXISTS_NUM = 4 AND v_SUM = 'Y'
	THEN 
	v_SQL := '
			, AGG AS (
				SELECT A.ITEM_CD      AS DIV_MAX
		  			 , A.ITEM_NM      AS DIV_MAX_NAM
		  			 , ''ALL''     	   	AS DIV_MID
		  			 , ''ALL''      	AS DIV_MID_NAM
		  			 , ''ALL''			AS DIV_MIN
		  			 , ''ALL''			AS DIV_MIN_NAM
		  			 , ''ALL''        	AS GDS_COD
		  			 , ''ALL''        	AS GDS_NAM
		             , NULL		AS ORDER_EMP_NAM
		             , NULL		AS MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
						SELECT I.ANCS_CD        AS ITEM_CD
				  			 , I.ANCS_NM        AS ITEM_NM
							 , A.ANCS_CD 		AS ACCOUNT_CD
							 , A.ANCS_NM 		AS ACCOUNT_NM
							 , RT.BASE_DATE
							 , SUM(RT.QTY)	 	AS BF_QTY
							 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
							 		ELSE NULL END AS ACT_SALES
						     , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								    ELSE NULL END AS ERR
				          FROM TB_BF_RT_FINAL_M RT
				          LEFT JOIN (SELECT BASE_DATE
				          				  , I.DESC_CD AS ITEM_CD
				          				  , A.DESC_CD AS ACCOUNT_CD
				          				  , QTY 
				         			   FROM TB_CM_ACTUAL_SALES_M_HIST SA
				         			  INNER JOIN IDS I 
				         			  	 ON SA.ITEM_MST_ID = I.DESC_ID
				         			  INNER JOIN ADS A 
				         			     ON SA.ACCOUNT_ID = A.DESC_ID
				         			  WHERE VER_CD = ''' || p_VER_CD || ''') SA
				            ON RT.ITEM_CD = SA.ITEM_CD
				           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
				           AND RT.BASE_DATE = SA.BASE_DATE
				         INNER JOIN IDS I 
				         	ON RT.ITEM_CD = I.DESC_CD
				         INNER JOIN ADS A 
				         	ON RT.ACCOUNT_CD = A.DESC_CD	
				         WHERE RT.VER_CD = ''' || p_VER_CD || '''        
				         GROUP BY I.ANCS_CD, I.ANCS_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE
			      	  ) A			
			)		
			' || v_SQL_COMMON5 || '	
			' || v_SQL_COMMON6 || ' 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 				     
				 , B.TOTAL_ACCRY
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY 1, A.ACCOUNT_CD, ORDER_VAL';
			
	/* 중분류 합계 조회 */
	ELSIF v_EXISTS_NUM = 3 AND v_SUM = 'Y'
	THEN 
	v_SQL := '
			, AGG AS (
				SELECT IH.LVL02_CD      AS DIV_MAX
		  			 , IH.LVL02_NM      AS DIV_MAX_NAM
		  			 , A.ITEM_CD      	AS DIV_MID
		  			 , A.ITEM_NM      	AS DIV_MID_NAM
		  			 , ''ALL''			AS DIV_MIN
		  			 , ''ALL''			AS DIV_MIN_NAM
		  			 , ''ALL''        	AS GDS_COD
		  			 , ''ALL''        	AS GDS_NAM
		             , NULL		AS ORDER_EMP_NAM
		             , NULL		AS MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
						SELECT I.ANCS_CD        AS ITEM_CD
				  			 , I.ANCS_NM        AS ITEM_NM
							 , A.ANCS_CD 		AS ACCOUNT_CD
							 , A.ANCS_NM 		AS ACCOUNT_NM
							 , RT.BASE_DATE
							 , SUM(RT.QTY)	 	AS BF_QTY
							 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
							 		ELSE NULL END AS ACT_SALES
						     , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								    ELSE NULL END AS ERR
				          FROM TB_BF_RT_FINAL_M RT
				          LEFT JOIN (SELECT BASE_DATE
				          				  , I.DESC_CD AS ITEM_CD
				          				  , A.DESC_CD AS ACCOUNT_CD
				          				  , QTY 
				         			   FROM TB_CM_ACTUAL_SALES_M_HIST SA
				         			  INNER JOIN IDS I 
				         			  	 ON SA.ITEM_MST_ID = I.DESC_ID
				         			  INNER JOIN ADS A 
				         			     ON SA.ACCOUNT_ID = A.DESC_ID
				         			  WHERE VER_CD = ''' || p_VER_CD || ''') SA
				            ON RT.ITEM_CD = SA.ITEM_CD
				           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
				           AND RT.BASE_DATE = SA.BASE_DATE
				         INNER JOIN IDS I 
				         	ON RT.ITEM_CD = I.DESC_CD
				         INNER JOIN ADS A 
				         	ON RT.ACCOUNT_CD = A.DESC_CD	
				         WHERE RT.VER_CD = ''' || p_VER_CD || '''        
				         GROUP BY I.ANCS_CD, I.ANCS_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE
			      	  ) A
				   INNER JOIN (SELECT DISTINCT LVL02_CD, LVL02_NM, LVL03_CD, LVL03_NM FROM TB_DPD_ITEM_HIERACHY2) IH  
			      	 ON A.ITEM_CD = IH.LVL03_CD
			        AND A.ITEM_NM = IH.LVL03_NM			
			)		
			' || v_SQL_COMMON5 || '	
			' || v_SQL_COMMON6 || ' 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 				     
				 , B.TOTAL_ACCRY
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY 1, 3, 5, A.ACCOUNT_CD, ORDER_VAL';
	  	  
	/* 소분류 합계 조회 */
	ELSIF v_EXISTS_NUM = 2 AND v_SUM = 'Y'
	THEN 
	v_SQL := '
			, AGG AS (
				SELECT IH.LVL02_CD      AS DIV_MAX
		  			 , IH.LVL02_NM      AS DIV_MAX_NAM
		  			 , IH.LVL03_CD      	AS DIV_MID
		  			 , IH.LVL03_NM     	AS DIV_MID_NAM
		  			 , A.ITEM_CD			AS DIV_MIN
		  			 , A.ITEM_NM			AS DIV_MIN_NAM
		  			 , ''ALL''        	AS GDS_COD
		  			 , ''ALL''        	AS GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
						SELECT I.ANCS_CD        AS ITEM_CD
				  			 , I.ANCS_NM        AS ITEM_NM
							 , A.ANCS_CD 		AS ACCOUNT_CD
							 , A.ANCS_NM 		AS ACCOUNT_NM
							 , RT.BASE_DATE
							 , I.ORDER_EMP_NM   AS ORDER_EMP_NAM
							 , I.MD_EMP_NM		AS MD_EMP_NAM
							 , SUM(RT.QTY)	 	AS BF_QTY
							 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
							 		ELSE NULL END AS ACT_SALES
						     , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								    ELSE NULL END AS ERR
				          FROM TB_BF_RT_FINAL_M RT
				          LEFT JOIN (SELECT BASE_DATE
				          				  , I.DESC_CD AS ITEM_CD
				          				  , A.DESC_CD AS ACCOUNT_CD
				          				  , QTY 
				         			   FROM TB_CM_ACTUAL_SALES_M_HIST SA
				         			  INNER JOIN IDS I 
				         			  	 ON SA.ITEM_MST_ID = I.DESC_ID
				         			  INNER JOIN ADS A 
				         			     ON SA.ACCOUNT_ID = A.DESC_ID
				         			  WHERE VER_CD = ''' || p_VER_CD || ''') SA
				            ON RT.ITEM_CD = SA.ITEM_CD
				           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
				           AND RT.BASE_DATE = SA.BASE_DATE
				         INNER JOIN IDS I 
				         	ON RT.ITEM_CD = I.DESC_CD
				         INNER JOIN ADS A 
				         	ON RT.ACCOUNT_CD = A.DESC_CD	
				         WHERE RT.VER_CD = ''' || p_VER_CD || '''        
				         GROUP BY I.ANCS_CD, I.ANCS_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE, I.ORDER_EMP_NM, I.MD_EMP_NM
			      	  ) A
				   INNER JOIN (SELECT DISTINCT LVL02_CD, LVL02_NM, LVL03_CD, LVL03_NM, LVL04_CD, LVL04_NM FROM TB_DPD_ITEM_HIERACHY2) IH  
			      	 ON A.ITEM_CD = IH.LVL04_CD
			        AND A.ITEM_NM = IH.LVL04_NM			
			)		
			' || v_SQL_COMMON5 || '	
			' || v_SQL_COMMON6 || ' 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 				     
				 , B.TOTAL_ACCRY
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY 1, 3, 5, A.ACCOUNT_CD, ORDER_VAL';
		
	/* 품목 단위 조회 */
	ELSIF v_EXISTS_NUM = 1
	THEN 
	v_SQL := '
			, AGG AS (
				SELECT IH.LVL02_CD      AS DIV_MAX
		  			 , IH.LVL02_NM      AS DIV_MAX_NAM
		  			 , IH.LVL03_CD      	AS DIV_MID
		  			 , IH.LVL03_NM     	AS DIV_MID_NAM
		  			 , IH.LVL04_CD			AS DIV_MIN
		  			 , IH.LVL04_NM			AS DIV_MIN_NAM
		  			 , A.ITEM_CD        	AS GDS_COD
		  			 , A.ITEM_NM        	AS GDS_NAM
		             , ORDER_EMP_NAM
		             , MD_EMP_NAM
		             , A.ACCOUNT_CD
		             , A.ACCOUNT_NM
		             , NVL('''|| v_SRC_TP ||''', ''ALL'') 	AS SRC_COD
					 , BASE_DATE
					 , BF_QTY
					 , ACT_SALES
					 , CASE WHEN ABS(BF_QTY - ACT_SALES) = 0  THEN 100
			             	ELSE (CASE WHEN (1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001)) >= 0 
			             			   THEN ROUND((1-ABS(BF_QTY - ACT_SALES)/(ACT_SALES + 0.00001))*100, 3) ELSE 0 END) END WAPE
					 , ERR
			      FROM (    
						SELECT I.ANCS_CD        AS ITEM_CD
				  			 , I.ANCS_NM        AS ITEM_NM
							 , A.ANCS_CD 		AS ACCOUNT_CD
							 , A.ANCS_NM 		AS ACCOUNT_NM
							 , RT.BASE_DATE
							 , I.ORDER_EMP_NM   AS ORDER_EMP_NAM
							 , I.MD_EMP_NM		AS MD_EMP_NAM
							 , SUM(RT.QTY)	 	AS BF_QTY
							 , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN SUM(NVL(SA.QTY, 0))
							 		ELSE NULL END AS ACT_SALES
						     , CASE WHEN RT.BASE_DATE <= TRUNC(SYSDATE, ''MM'') THEN ABS(SUM(RT.QTY) - SUM(NVL(SA.QTY, 0)))
								    ELSE NULL END AS ERR
				          FROM TB_BF_RT_FINAL_M RT
				          LEFT JOIN (SELECT BASE_DATE
				          				  , I.DESC_CD AS ITEM_CD
				          				  , A.DESC_CD AS ACCOUNT_CD
				          				  , QTY 
				         			   FROM TB_CM_ACTUAL_SALES_M_HIST SA
				         			  INNER JOIN IDS I 
				         			  	 ON SA.ITEM_MST_ID = I.DESC_ID
				         			  INNER JOIN ADS A 
				         			     ON SA.ACCOUNT_ID = A.DESC_ID
				         			  WHERE VER_CD = ''' || p_VER_CD || ''') SA
				            ON RT.ITEM_CD = SA.ITEM_CD
				           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
				           AND RT.BASE_DATE = SA.BASE_DATE
				         INNER JOIN IDS I 
				         	ON RT.ITEM_CD = I.DESC_CD
				         INNER JOIN ADS A 
				         	ON RT.ACCOUNT_CD = A.DESC_CD	
				         WHERE RT.VER_CD = ''' || p_VER_CD || '''        
				         GROUP BY I.ANCS_CD, I.ANCS_NM, A.ANCS_CD, A.ANCS_NM, RT.BASE_DATE, I.ORDER_EMP_NM, I.MD_EMP_NM
			      	  ) A
				   INNER JOIN (SELECT LVL02_CD, LVL02_NM, LVL03_CD, LVL03_NM, LVL04_CD, LVL04_NM, LVL05_CD, LVL05_NM FROM TB_DPD_ITEM_HIERACHY2) IH  
			      	 ON A.ITEM_CD = IH.LVL05_CD
			        AND A.ITEM_NM = IH.LVL05_NM			
			)		
			' || v_SQL_COMMON5 || '	
			' || v_SQL_COMMON6 || ' 
			SELECT A.*
				 , ''' || v_MIN_BASE_DATE || ''' AS STA_DAY
				 , ''' || v_NUM || ''' AS COL_CNT 		
				 , B.TOTAL_ACCRY		     
				FROM (SELECT * FROM SA				
					   UNION ALL
  				      SELECT * FROM RT
		  			   UNION ALL
					  SELECT * FROM WAPE) A
			   INNER JOIN ACC B 
 				  ON A.DIV_MAX = B.DIV_MAX AND A.DIV_MAX_NAM = B.DIV_MAX_NAM AND A.DIV_MID = B.DIV_MID 
				 AND A.DIV_MID_NAM = B.DIV_MID_NAM AND A.GDS_COD = B.GDS_COD AND A.GDS_NAM = B.GDS_NAM
				 AND NVL(A.ORDER_EMP_NAM, 0) = NVL(B.ORDER_EMP_NAM, 0) AND NVL(A.MD_EMP_NAM, 0) = NVL(B.MD_EMP_NAM, 0) AND A.SRC_COD = B.SRC_COD
				 AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.ACCOUNT_NM = B.ACCOUNT_NM
			 ORDER BY 1, 3, 5, 7, A.ACCOUNT_CD, ORDER_VAL';

	END IF;

	v_SQL := v_SQL_COMMON1 || v_SQL;
--	DBMS_OUTPUT.PUT_LINE(v_SQL);
	OPEN pRESULT FOR v_SQL;    

END;