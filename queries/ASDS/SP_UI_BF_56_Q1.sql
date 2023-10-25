CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_56_Q1" (
    P_S_DATE            DATE
  , P_E_DATE            DATE
  , P_FACTOR_CD         VARCHAR2 := ''
  , P_FACTOR_DESCRIP    VARCHAR2 := ''
  , P_FACTOR_SET        VARCHAR2 := ''
  , P_ITEM_CD			VARCHAR2 
  , P_ACCOUNT_CD		VARCHAR2 
  , pRESULT             OUT SYS_REFCURSOR
) IS
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_56_Q1
   * Purpose : 인자 분석 그리드 조회
   * Notes :
   **************************************************************************/
    QUERY VARCHAR2(32767) := ''; 
	QUERY2 VARCHAR2(32767) := '';
	a VARCHAR2(20);
	b VARCHAR2(200);
	c VARCHAR2(50);

BEGIN
    -- DATE FACTOR STATISTICS
	EXECUTE IMMEDIATE 'TRUNCATE TABLE TEMP_FACTOR_INFO';   
	
	/* 분석 대상 일자별 인자명 선택 */
    FOR FCTR_INFO IN (
        SELECT COL_NM AS COL
             , FACTOR_CD AS FCTR
             , DESCRIP
          FROM TB_BF_FACTOR_MGMT
         WHERE COALESCE(DEL_YN, 'Y') = 'N'
           AND ACTV_YN = 'Y'
           AND COL_NM IN (
            SELECT COLUMN_NAME
              FROM ALL_TAB_COLS
             WHERE TABLE_NAME = 'TB_BF_DATE_FACTOR'
           )
        )
    LOOP
    /* 임시 테이블 인자 저장 */
	QUERY := '
			INSERT INTO TEMP_FACTOR_INFO 
            SELECT '''|| FCTR_INFO.COL ||''' "FACTOR_COL"
				 , '''|| FCTR_INFO.COL ||''' "FACTOR_CD"
                 , '''|| FCTR_INFO.DESCRIP ||''' "DESCRIP"
                 , COUNT(DF.'|| FCTR_INFO.COL ||') "COUNT"
                 , AVG(DF.'|| FCTR_INFO.COL ||') "AVG"
                 , COALESCE(STDDEV(DF.'|| FCTR_INFO.COL ||'), 0) "STDEV"
                 , MIN(DF.'|| FCTR_INFO.COL ||') "MIN"
                 , MAX(DF.'|| FCTR_INFO.COL ||') "MAX"
                 , MAX(MD.'|| FCTR_INFO.COL ||') "MODE"
                 , COALESCE(STDDEV(DF.'|| FCTR_INFO.COL ||'), 0) / (CASE WHEN AVG(DF.'|| FCTR_INFO.COL ||') = 0 THEN 1 ELSE AVG(DF.'|| FCTR_INFO.COL ||') END) "COV"
              FROM (SELECT AVG('|| FCTR_INFO.COL ||') '|| FCTR_INFO.COL ||'
              			 , MIN(BASE_DATE) BASE_DATE
         			 FROM TB_BF_DATE_FACTOR D
          		    INNER JOIN TB_CM_CALENDAR C ON D.BASE_DATE = C.DAT
      			    WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
      			    GROUP BY DP_WK) DF
                   INNER JOIN (
                    SELECT ' || FCTR_INFO.COL || '
                         , CNT
                      FROM (
                        SELECT ' || FCTR_INFO.COL || '
                             , COUNT(1) CNT
                             , ROW_NUMBER() OVER (ORDER BY COUNT(1) DESC) RID
                          FROM (SELECT AVG('|| FCTR_INFO.COL ||') '|| FCTR_INFO.COL ||'
			              			 , MIN(BASE_DATE) BASE_DATE
		              			 FROM TB_BF_DATE_FACTOR D
		              		 	INNER JOIN TB_CM_CALENDAR C ON D.BASE_DATE = C.DAT
	              			 	WHERE BASE_DATE BETWEEN '''|| P_S_DATE ||''' AND '''|| P_E_DATE ||'''
	              			  	GROUP BY DP_WK)
                         WHERE BASE_DATE BETWEEN '''|| P_S_DATE ||''' AND '''|| P_E_DATE ||'''
						   AND ' || FCTR_INFO.COL || ' is not null
                         GROUP BY ' || FCTR_INFO.COL || '
                      ) MD
                     WHERE RID = 1
                   ) MD
                ON 1=1
             WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
           ';
    	EXECUTE IMMEDIATE QUERY;
    	COMMIT;
    END LOOP; 

    -- SALES_FACTOR STATISTICS
    /* 분석 대상 일자별 인자명 선택 */
    FOR FCTR_INFO2 IN (
        SELECT COL_NM AS COL
             , FACTOR_CD AS FCTR
             , DESCRIP
          FROM TB_BF_FACTOR_MGMT
         WHERE COALESCE(DEL_YN, 'Y') = 'N'
           AND ACTV_YN = 'Y'
           AND COL_NM IN (
            SELECT COLUMN_NAME
              FROM ALL_TAB_COLS
             WHERE TABLE_NAME = 'TB_BF_SALES_FACTOR'
           )
    )
    LOOP
	/* 임시 테이블 인자 저장 */    
    QUERY2 := '
			INSERT INTO TEMP_FACTOR_INFO 
            SELECT ''' || FCTR_INFO2.COL || '''    AS "FACTOR_COL"
				 , ''' || FCTR_INFO2.COL || '''    AS "FACTOR_CD"
                 , ''' || FCTR_INFO2.DESCRIP || '''    AS "DESCRIP"
                 , COUNT(DF.' || FCTR_INFO2.COL || ') AS "COUNT"
                 , AVG(DF.'   || FCTR_INFO2.COL || ') AS "AVG"
                 , COALESCE(STDDEV(DF.' || FCTR_INFO2.COL || '), 0) AS "STDEV"
                 , MIN(DF.'   || FCTR_INFO2.COL || ') AS "MIN"
                 , MAX(DF.'   || FCTR_INFO2.COL || ') AS "MAX"
                 , MAX(MD.'   || FCTR_INFO2.COL || ') AS "MODE"
                 , COALESCE(STDDEV(DF.' || FCTR_INFO2.COL || '), 0) / (CASE WHEN AVG(DF.' || FCTR_INFO2.COL || ') = 0 THEN 1 ELSE AVG(DF.' || FCTR_INFO2.COL || ') END) AS "COV"
              FROM (SELECT AVG(NVL('|| FCTR_INFO2.COL ||', 0)) 	AS '|| FCTR_INFO2.COL ||'
              			 , MIN(DAT) 				AS BASE_DATE
          			  FROM (SELECT '|| FCTR_INFO2.COL ||'
								 , BASE_DATE 
          			   		  FROM TB_BF_SALES_FACTOR TBSF
							 INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH
								ON TBSF.ITEM_CD = IH.DESCENDANT_CD
							 INNER JOIN TB_DPD_SALES_HIER_CLOSURE SH
								ON TBSF.ACCOUNT_CD = SH.DESCENDANT_CD
      			 	 		 WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
							   AND IH.ANCESTER_CD = '''|| P_ITEM_CD ||''' AND SH.ANCESTER_CD = '''|| P_ACCOUNT_CD ||''') TBSF
					  RIGHT JOIN (SELECT DAT, DP_WK FROM TB_CM_CALENDAR WHERE DAT BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || ''') CAL 
					  	 ON TBSF.BASE_DATE = CAL.DAT
      			 	 GROUP BY DP_WK) DF
                   INNER JOIN (
                    SELECT ' || FCTR_INFO2.COL || '
                         , CNT
                      FROM (
                        SELECT ' || FCTR_INFO2.COL || '
                             , COUNT(1) CNT
                             , ROW_NUMBER() OVER (ORDER BY COUNT(1) DESC) RID
                          FROM (SELECT AVG(NVL('|| FCTR_INFO2.COL ||', 0)) 	AS '|| FCTR_INFO2.COL ||'
			              			 , MIN(DAT) 				AS BASE_DATE
		              			  FROM (SELECT '|| FCTR_INFO2.COL ||'
											 , BASE_DATE 
		              			   		  FROM TB_BF_SALES_FACTOR TBSF
										 INNER JOIN TB_DPD_ITEM_HIER_CLOSURE IH
											ON TBSF.ITEM_CD = IH.DESCENDANT_CD
										 INNER JOIN TB_DPD_SALES_HIER_CLOSURE SH
											ON TBSF.ACCOUNT_CD = SH.DESCENDANT_CD
	              			 	 		 WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
										   AND IH.ANCESTER_CD = '''|| P_ITEM_CD ||''' AND SH.ANCESTER_CD = '''|| P_ACCOUNT_CD ||''') TBSF
								  RIGHT JOIN (SELECT DAT, DP_WK FROM TB_CM_CALENDAR WHERE DAT BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || ''') CAL 
								  	 ON TBSF.BASE_DATE = CAL.DAT
	              			 	 GROUP BY DP_WK) 
                         WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
						   AND ' || FCTR_INFO2.COL || ' is not null
                         GROUP BY ' || FCTR_INFO2.COL || '
                      ) MD
                     WHERE RID = 1
                   ) MD
                ON 1=1
             WHERE BASE_DATE BETWEEN ''' || P_S_DATE || ''' AND ''' || P_E_DATE || '''
           ';
         EXECUTE IMMEDIATE QUERY2;
         COMMIT;
    END LOOP;

    -- NULL LINE TO HANDLE FINAL UNION
--     QUERY := QUERY || '
--            SELECT NULL "FACTOR_COL"
--				 , NULL "FACTOR_CD"                                  
--                 , NULL "DESCRIP"                                                                        
--                 , NULL "COUNT"                                          
--                 , NULL "AVG"                                            
--                 , NULL "STDEV"                                          
--                 , NULL "MIN"                                            
--                 , NULL "MAX"                                            
--                 , NULL "MODE"                                       
--                 , NULL "COV"
--              FROM DUAL                                        
--             WHERE 1=0                                                      
--             ORDER BY FACTOR_CD
--           ';

    -- RUN THE DYNAMIC QUERY
--    OPEN pRESULT FOR QUERY;
    OPEN pRESULT 
     FOR SELECT * FROM TEMP_FACTOR_INFO WHERE MAX = 1 ORDER BY 1;    
   
    EXCEPTION WHEN OTHERS THEN
		ROLLBACK;
	
		a := SQLCODE;
		b := SQLERRM;
		c := SYS.dbms_utility.format_error_backtrace;
	
		BEGIN
			INSERT INTO TB_SCM100M_ERR_LOG(ERR_FILE, ERR_CODE, ERR_MSG, ERR_LINE, ERR_DTTM)
			SELECT 'SP_UI_BF_56_MA_Q1', a, b, c, SYSDATE FROM DUAL;
		
			COMMIT;
		END;
END;