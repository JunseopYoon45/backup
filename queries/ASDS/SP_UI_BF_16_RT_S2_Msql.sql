CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_16_RT_S2_M" (
      p_VER_CD VARCHAR2
    , p_USER_ID VARCHAR2
    , p_SELECT_CRITERIA VARCHAR2
    , p_PROCESS_NO INT
    , P_RT_ROLLBACK_FLAG			OUT VARCHAR2   
    , P_RT_MSG						OUT VARCHAR2
)
IS

P_ERR_STATUS INT := 0;
P_ERR_MSG VARCHAR2(4000) :='';
p_TARGET_BUKT_CD		VARCHAR2(50);
p_TARGET_TO_DATE		DATE;
p_TARGET_FROM_DATE	    DATE;
p_ACCURACY_WK			INT;
p_VER_CNT			    INT;
p_ZIO_SELECTION_CRI	    VARCHAR2(250);

BEGIN

    -- Change Version Data
--	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	UPDATE TEMP_DTL
	   SET RUN_STRT_DATE = SYSDATE
	 WHERE VER_CD = p_VER_CD
	   AND PROCESS_NO = p_PROCESS_NO 
    ;

    -- Get Config Data
	SELECT 
         --COALESCE(ATTR_01, TO_CHAR(4))
           TO_CHAR(4)
		 , COALESCE(ATTR_03, TO_CHAR(8))
		 , COALESCE(ATTR_02, 'RMSE')
           INTO
           p_ACCURACY_WK
         , p_VER_CNT
         , p_ZIO_SELECTION_CRI
	  FROM TB_CM_COMM_CONFIG 
	 WHERE CONF_CD = p_SELECT_CRITERIA
	   AND CONF_GRP_CD = 'BF_SELECT_CRITERIA'
	   AND ACTV_YN = 'Y'
    ;

    SELECT DISTINCT TARGET_BUKT_CD
				  , INPUT_TO_DATE
				  , (
                     SELECT FROM_DATE
                       FROM (
                         SELECT LEAD(MIN(DAT),p_ACCURACY_WK) OVER(ORDER BY CASE WHEN TARGET_BUKT_CD='M' THEN YYYYMM ELSE TO_CHAR(DP_WK) END  DESC) as "FROM_DATE"
                           FROM TB_CM_CALENDAR 
                          WHERE DAT BETWEEN CASE WHEN TARGET_BUKT_CD='M' THEN ADD_MONTHS(INPUT_TO_DATE+1, p_ACCURACY_WK*-1) ELSE (INPUT_TO_DATE+1)-p_ACCURACY_WK*7 END
                            AND INPUT_TO_DATE+1
                       GROUP BY CASE WHEN TARGET_BUKT_CD='M' THEN YYYYMM ELSE TO_CHAR(DP_WK) END 
                       )
                     WHERE ROWNUM=1
                  )
                    INTO
                    p_TARGET_BUKT_CD
                  , p_TARGET_TO_DATE
                  , p_TARGET_FROM_DATE
--               FROM TB_BF_CONTROL_BOARD_VER_DTL
               FROM TEMP_DTL
              WHERE VER_CD = p_VER_CD
                AND ENGINE_TP_CD IS NOT NULL
            ;

    -- Delete same version Data
    DELETE FROM TB_BF_RT_ACCRCY_M
      WHERE VER_CD = p_VER_CD
      ;

    -- Get Forecast & Sales
    INSERT INTO TB_BF_RT_ACCRCY_M (
         ID
        ,ENGINE_TP_CD
        ,VER_CD
        ,ITEM_CD
        ,ACCOUNT_CD
        ,MAPE
        ,MAE
        ,MAE_P
        ,RMSE
        ,RMSE_P
        ,WAPE
        ,SELECT_SEQ
        ,CREATE_BY
        ,CREATE_DTTM
        ,MODIFY_BY
        ,MODIFY_DTTM
    )
    WITH IA AS (
        SELECT ITEM_CD, ACCOUNT_CD
        	 , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD END ENGINE_TP_CD
          FROM TB_BF_RT_M
         WHERE VER_CD = p_VER_CD
      GROUP BY ITEM_CD, ACCOUNT_CD, CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD END
    )
	, IA_ONLY
	AS (
		SELECT ITEM_CD, ACCOUNT_CD
		FROM IA
		GROUP BY ITEM_CD, ACCOUNT_CD
	)
	, TARGET_IA 
	AS (
		SELECT IH.DESCENDANT_ID	AS ITEM_ID
			 , IH.DESCENDANT_CD	AS ITEM_CD
			 , IH.ANCESTER_CD	AS P_ITEM_CD
			 , SH.DESCENDANT_ID	AS ACCT_ID
			 , SH.DESCENDANT_CD	AS ACCT_CD
			 , SH.ANCESTER_CD	AS P_ACCT_CD 		
		 FROM TB_BF_ITEM_ACCOUNT_MODEL_MAP S 
			   INNER JOIN 
			   TB_DPD_ITEM_HIER_CLOSURE IH
			ON S.ITEM_CD = IH.DESCENDANT_CD
		   AND IH.LEAF_YN = 'Y' 
		   AND IH.LV_TP_CD = 'I'
		       INNER JOIN 
			   TB_DPD_SALES_HIER_CLOSURE SH
			ON S.ACCOUNT_CD = SH.DESCENDANT_CD
		   AND SH.LEAF_YN = 'Y' 
		   AND SH.LV_TP_CD = 'S'
		   	   INNER JOIN 
		   	   IA_ONLY IA
		   	ON IA.ITEM_CD = IH.ANCESTER_CD 
		   AND IA.ACCOUNT_CD = SH.ANCESTER_CD 
		WHERE ACTV_YN = 'Y' 
	)
    , RT AS (
         SELECT ITEM_CD
         	  , ACCOUNT_CD
         	  , BASE_DATE
         	  , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD END ENGINE_TP_CD
         	  , QTY
         	  , VER_CD
           FROM TB_BF_RT_HISTORY_M 
          WHERE BASE_DATE BETWEEN p_TARGET_FROM_DATE AND p_TARGET_TO_DATE
    ), 
    CALENDAR AS ( 
        SELECT DAT          
             , YYYY
             , YYYYMM
             , CASE 
                 WHEN p_TARGET_BUKT_CD = 'W' THEN TO_NUMBER(TO_CHAR(DAT,'IW'))
                 WHEN p_TARGET_BUKT_CD = 'PW' THEN TO_NUMBER(TO_CHAR(DAT,'IW'))
                 WHEN p_TARGET_BUKT_CD = 'M' THEN TO_NUMBER(YYYYMM)
               END AS BUKT
--             , CASE WHEN p_TARGET_BUKT_CD = 'W' THEN YYYY || '-' || DP_WK
--                    WHEN p_TARGET_BUKT_CD = 'M' THEN YYYYMM 
--               END AS BUKT 		 
          FROM TB_CM_CALENDAR
         WHERE DAT BETWEEN p_TARGET_FROM_DATE AND p_TARGET_TO_DATE
    ), 
    CAL AS (
        SELECT MIN(DAT)	AS STRT_DATE
            ,  MAX(DAT) AS END_DATE 
            , CASE 
                 WHEN p_TARGET_BUKT_CD = 'W' THEN MIN(YYYY) || '-' || BUKT
                 WHEN p_TARGET_BUKT_CD = 'PW' THEN MIN(YYYYMM) || '-' || BUKT
                 WHEN p_TARGET_BUKT_CD = 'M' THEN MIN(YYYYMM)
               END AS BUKT
           -- ,  BUKT
          FROM CALENDAR 
      GROUP BY BUKT 
    ), ACT_SALES AS (
    	SELECT ITEM_MST_ID, ACCOUNT_ID, BASE_DATE, QTY, AMT, QTY_CORRECTION, AMT_CORRECTION, CORRECTION_YN
    	  FROM TB_CM_ACTUAL_SALES
    	 WHERE BASE_DATE BETWEEN p_TARGET_FROM_DATE AND p_TARGET_TO_DATE
    )
    , SA_IA AS (
		SELECT P_ITEM_CD 		 
			 , P_ACCT_CD
			 , S.BASE_DATE
	    	 , SUM(NVL(CASE CORRECTION_YN WHEN 'Y' THEN QTY_CORRECTION ELSE QTY END,0 ))		AS QTY
	    	 , SUM(NVL(CASE CORRECTION_YN WHEN 'Y' THEN AMT_CORRECTION ELSE AMT END,0 ))		AS AMT 
		 FROM  ACT_SALES S 
			   INNER JOIN 
			   TARGET_IA M
			ON S.ITEM_MST_ID = M.ITEM_ID 
		   AND S.ACCOUNT_ID = M.ACCT_ID
		GROUP BY P_ITEM_CD 		 
			 , P_ACCT_CD
			 , S.BASE_DATE
	 )
	 , SA
	AS (
		SELECT M.P_ITEM_CD		AS ITEM_CD  
			 , M.P_ACCT_CD  	AS ACCOUNT_CD  
	    	 , CAL.STRT_DATE   
	    	 , CAL.END_DATE     
	    	 , SUM(COALESCE(QTY,0)) AS QTY
	    	 , SUM(COALESCE(AMT,0)) AS AMT  
	      FROM CAL 
			   CROSS JOIN 
			   TARGET_IA M			   
	           LEFT OUTER JOIN
	 		   SA_IA S
	 		ON S.BASE_DATE BETWEEN CAL.STRT_DATE AND CAL.END_DATE 
		   AND M.P_ITEM_CD = S.P_ITEM_CD
		   AND M.P_ACCT_CD = S.P_ACCT_CD
	     GROUP BY M.P_ITEM_CD
	     		, M.P_ACCT_CD
	            , CAL.STRT_DATE
	            , CAL.END_DATE     
	)
    , SA_SUM AS (
        SELECT  ITEM_CD
              , ACCOUNT_CD
              , SUM(QTY)		AS QTY
           FROM SA 
       GROUP BY ITEM_CD, ACCOUNT_CD
    ),
    SA_AVG AS (
        SELECT  ITEM_CD
              , ACCOUNT_CD
              , AVG(QTY)		AS QTY
           FROM SA 
       GROUP BY ITEM_CD, ACCOUNT_CD
    )

	-- Calculating Accuracy
    SELECT   TO_SINGLE_BYTE(SYS_GUID())	AS ID
           , IA.ENGINE_TP_CD
           , p_VER_CD
           , IA.ITEM_CD
           , IA.ACCOUNT_CD
           , MAPE	
           , MAE	
           , MAE_P
           , RMSE	
           , RMSE_P
           , WAPE
           , ROW_NUMBER() OVER (PARTITION BY IA.ITEM_CD, IA.ACCOUNT_CD 
                                    ORDER BY CASE p_SELECT_CRITERIA
                                                WHEN 'MAPE'		THEN MAPE
                                                WHEN 'WAPE'		THEN ROUND(WAPE, 3)
                                                WHEN 'MAE'		THEN MAE
                                                WHEN 'MAE_P'	THEN MAE_P
                                                WHEN 'RMSE'		THEN RMSE
                                                WHEN 'RMSE_P'	THEN RMSE_P
                                             END ASC, C.PRIORT ASC)					AS SELECT_SEQ
           , p_USER_ID	
           , SYSDATE
           , NULL
           , NULL
      FROM IA
           LEFT OUTER JOIN	 
           (
             SELECT  A.ENGINE_TP_CD 	   
                   , A.ITEM_CD
                   , A.ACCOUNT_CD
                   , AVG(ERR/SALES 	)*100										AS MAPE		
                   , AVG(ERR)													AS MAE		
                   , AVG(ERR)/AVG(SALES)*100									AS MAE_P	
                   , SQRT(AVG(ERR*ERR))											AS RMSE		
                   , SQRT(AVG(ERR*ERR))/AVG(SALES)*100							AS RMSE_P	 			
                   , CASE WHEN SUM(ERR) = 0 THEN 0 
                   		  ELSE (CASE WHEN SUM(ERR)/SUM(SALES)<=1 THEN SUM(ERR)/SUM(SALES) ELSE 1 END)  * 100
                    END		AS WAPE
              FROM (
                        SELECT RT.ITEM_CD
                            ,  RT.ACCOUNT_CD
                            ,  RT.BASE_DATE
                            ,  RT.ENGINE_TP_CD
                            ,  RT.VER_CD
                            ,  ABS(SA.QTY - RT.QTY)					AS ERR
                            ,  RT.QTY+0.00001						AS FCS
                            ,  TO_NUMBER(SA.QTY) + 0.00001			AS SALES 
                            ,  SA_AVG.QTY	+ 0.00001				AS SA_AVG
                          FROM RT
                               INNER JOIN
                               SA    
                            ON RT.ITEM_CD = SA.ITEM_CD
                           AND RT.ACCOUNT_CD = SA.ACCOUNT_CD
                           AND RT.BASE_DATE BETWEEN SA.STRT_DATE AND SA.END_DATE
                               INNER JOIN
                               SA_AVG
                            ON RT.ITEM_CD = SA_AVG.ITEM_CD
                           AND RT.ACCOUNT_CD = SA_AVG.ACCOUNT_CD

                    ) A
            GROUP BY A.ITEM_CD
                  ,  A.ACCOUNT_CD 
                  ,  A.ENGINE_TP_CD 
         ) A
      ON IA.ITEM_CD = A.ITEM_CD
     AND IA.ACCOUNT_CD = A.ACCOUNT_CD
     AND IA.ENGINE_TP_CD = A.ENGINE_TP_CD
         INNER JOIN
         TB_CM_COMM_CONFIG C
       ON IA.ENGINE_TP_CD = C.CONF_CD 
      AND C.CONF_GRP_CD = 'BF_ENGINE_TP'
         ;

    -- Change Version Data
--	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	UPDATE TEMP_DTL
	   SET RULE_01 = p_SELECT_CRITERIA
		 , STATUS = 'Completed'
		 , RUN_END_DATE = SYSDATE
	 WHERE VER_CD = p_VER_CD
	   AND PROCESS_NO = p_PROCESS_NO 
       ;

        P_RT_ROLLBACK_FLAG := 'true';
	    P_RT_MSG := 'MSG_0001';  --저장 되었습니다.

       EXCEPTION
        WHEN OTHERS THEN  
              IF(SQLCODE = -20001)
              THEN
                  P_RT_ROLLBACK_FLAG := 'false';
                  P_RT_MSG := sqlerrm;
              ELSE
                SP_COMM_RAISE_ERR();
              END IF;
END;