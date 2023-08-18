CREATE OR REPLACE PROCEDURE DWSCM.SP_UI_BF_16_RT_S3_M
(	 p_VER_CD					VARCHAR2
	,p_USER_ID					VARCHAR2
	,p_SELECT_CRITERIA			VARCHAR2 
	,p_BUKT_CD					VARCHAR2 := 'PW'
	,p_PROCESS_NO				INT
	,p_RT_ROLLBACK_FLAG		    OUT VARCHAR2
	,p_RT_MSG					OUT VARCHAR2
)
IS

p_ERR_STATUS INT :=0;
p_ERR_MSG VARCHAR2(4000):='';
p_TARGET_FROM_DATE DATE :='';
p_TARGET_TO_DATE DATE :='';
p_STD_WK VARCHAR2(30) := '';
p_EXISTS_NUM VARCHAR2(2) := '';
p_DOW_DEPT INT :=0;
v_BUKT_CD VARCHAR2(10) := 'M';

BEGIN

    SELECT CASE WHEN EXISTS ( SELECT *
                                FROM TB_BF_CONTROL_BOARD_VER_DTL
                               WHERE VER_CD = p_VER_CD
                                 AND PROCESS_NO < p_PROCESS_NO
                                 AND STATUS = 'Ready'
                                 AND DESCRIP NOT LIKE '%Learning' ) THEN '1' ELSE '0' END 
           INTO p_EXISTS_NUM
      FROM DUAL;

    IF (p_EXISTS_NUM='1')
    THEN
       P_ERR_MSG := 'Please complete the previous process first.'; 
	   RAISE_APPLICATION_ERROR(-20001, P_ERR_MSG);         
    END IF;

    SELECT CASE WHEN EXISTS ( SELECT *
                                FROM TB_BF_CONTROL_BOARD_VER_DTL
                               WHERE VER_CD = p_VER_CD
                                 AND PROCESS_NO = 1000000
                                 AND STATUS = 'Completed' ) THEN '1' ELSE '0' END 
           INTO p_EXISTS_NUM
      FROM DUAL;

    IF (p_EXISTS_NUM='1')
	THEN
	   P_ERR_MSG := 'This version is aleady closed.';
	   RAISE_APPLICATION_ERROR(-20001, P_ERR_MSG);
	END	IF;


	IF (v_BUKT_CD IS NULL OR v_BUKT_CD NOT IN ('M', 'PW', 'W'))
	THEN
		SELECT POLICY_VAL
		  	   INTO 
		  	   v_BUKT_CD
	 	  FROM TB_DP_PLAN_POLICY 
		 WHERE PLAN_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_PLAN_TYPE' AND DEFAT_VAL = 'Y' AND ACTV_YN = 'Y')		
	  	   AND POLICY_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'DP_POLICY' AND CONF_CD = 'B' AND ACTV_YN = 'Y');	
	END IF;

    SELECT MIN(BASE_DATE)
         , MAX(BASE_DATE)   
           INTO
           p_TARGET_FROM_DATE
         , p_TARGET_TO_DATE
      FROM TB_BF_RT_MA
     WHERE VER_CD = p_VER_CD
     ;

	-- DOW 바뀔 경우 대비
	--p_DOW_DEPT INT :=0;
	 --SELECT p_DOW_DEPT = DATEPART(DW, MIN(DAT)) 
	 -- FROM TB_CM_CALENDAR
	 --WHERE DP_WK = (SELECT DP_WK FROM TB_CM_CALENDAR WHERE DAT = p_TARGET_FROM_DATE)
	 --;
	 --SELECT p_DOW_DEPT = p_DOW_DEPT - DATEPART(DW, p_TARGET_FROM_DATE) 
	 --;
	 --SET p_TARGET_FROM_DATE = DATEADD(DAY, p_DOW_DEPT, p_TARGET_FROM_DATE )
	 --SET p_TARGET_TO_DATE =   DATEADD(DAY, p_DOW_DEPT, p_TARGET_TO_DATE );	
/*************************************************************************************************************
	-- Change Version Data
*************************************************************************************************************/
	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	   SET RUN_STRT_DATE = SYSDATE
	 WHERE VER_CD = p_VER_CD
	   AND PROCESS_NO = p_PROCESS_NO 
    ;
/*************************************************************************************************************
	-- Delete same version Data
*************************************************************************************************************/
	DELETE FROM TB_BF_RT_FINAL_MA
	  WHERE VER_CD = p_VER_CD
	  ;
	COMMIT;
/*************************************************************************************************************
	-- Get Forecast , Accuracy ...
*************************************************************************************************************/	
    INSERT INTO TB_BF_RT_FINAL_MA(	 
         ID					
		,VER_CD				
		,ITEM_CD			
		,ACCOUNT_CD			
		,BASE_DATE			
		,BEST_ENGINE_TP_CD	
		,QTY				
		,CREATE_BY			
		,CREATE_DTTM		
		,MODIFY_BY			
		,MODIFY_DTTM			
	)
	WITH AC AS (
		SELECT ITEM_CD
			,  ACCOUNT_CD
			,  ENGINE_TP_CD 
			,  ROW_NUMBER () OVER (PARTITION BY ITEM_CD, ACCOUNT_CD ORDER BY SELECT_SEQ ASC) AS SELECT_SEQ
		  FROM TB_BF_RT_ACCRCY_MA
		 WHERE VER_CD = p_VER_CD
	),  
    CA AS (
	    SELECT MIN(DAT)				AS FROM_DATE
			 , MAX(DAT)				AS TO_DATE
			 , MIN(YYYYMM)			AS YYYYMM
			 , COUNT(DAT)			AS DAT_CNT
		  FROM TB_CM_CALENDAR	
	     WHERE DAT BETWEEN p_TARGET_FROM_DATE AND p_TARGET_TO_DATE 
	  GROUP BY YYYY
			 , CASE WHEN v_BUKT_CD IN ('M', 'PW') THEN MM    ELSE '1' END
			 , CASE WHEN v_BUKT_CD IN ('PW', 'W') THEN TO_CHAR(DP_WK) ELSE '1' END 
	), 
    RT AS (	SELECT ITEM_CD
				 , ACCOUNT_CD
				 --, DATEADD(DAY, p_DOW_DEPT, BASE_DATE)	AS FROM_DATE
                 , BASE_DATE + p_DOW_DEPT	AS FROM_DATE
				 --, COALESCE(DATEADD(DAY, -1, LEAD(DATEADD(DAY, p_DOW_DEPT, BASE_DATE),1) OVER (PARTITION BY ENGINE_TP_CD, ITEM_CD, ACCOUNT_CD ORDER BY BASE_DATE ASC)), p_TARGET_TO_DATE)	AS TO_DATE
                 , COALESCE(LEAD(BASE_DATE+p_DOW_DEPT,1) OVER (PARTITION BY ENGINE_TP_CD, ITEM_CD, ACCOUNT_CD ORDER BY BASE_DATE ASC)-1, p_TARGET_TO_DATE)	AS TO_DATE
                 , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD
				 , QTY 
			  FROM TB_BF_RT_MA 
			 WHERE VER_CD = p_VER_CD
	)	
	SELECT TO_SINGLE_BYTE(SYS_GUID())   AS ID					
		 , p_VER_CD			            AS VER_CD				
		 , ITEM_CD				        AS ITEM_CD			
		 , ACCOUNT_CD			        AS ACCOUNT_CD			
		 , BASE_DATE			        AS BASE_DATE			
		 , ENGINE_TP_CD			        AS BEST_ENGINE_TP_CD	
		 , QTY 					        AS QTY				
		 , p_USER_ID			        AS CREATE_BY			
		 , SYSDATE  			        AS CREATE_DTTM		
		 , NULL					        AS MODIFY_BY			
		 , NULL 				        AS MODIFY_DTTM			
	  FROM (
		SELECT RT.ITEM_CD
			 , RT.ACCOUNT_CD
			 , CA.FROM_DATE		 BASE_DATE 
			 , RT.ENGINE_TP_CD
--			 , RT.QTY															  AS BF_QTY_ORG
			 --, RT.QTY * CA.DAT_CNT / (DATEDIFF(DAY, RT.FROM_DATE, RT.TO_DATE)+1)  AS QTY
             , ROUND(RT.QTY * CA.DAT_CNT / (RT.TO_DATE-RT.FROM_DATE+1))  AS QTY
			 , DENSE_RANK() OVER (PARTITION BY RT.ITEM_CD, RT.ACCOUNT_CD, RT.FROM_DATE ORDER BY AC.SELECT_SEQ)	AS RW
		  FROM RT
			   INNER JOIN
			   AC
			ON RT.ITEM_CD = AC.ITEM_CD
		   AND RT.ACCOUNT_CD = AC.ACCOUNT_CD
		   AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
			   INNER JOIN
			   CA
			ON CA.FROM_DATE BETWEEN RT.FROM_DATE AND RT.TO_DATE
		) M
	WHERE RW = 1
    ;


--    SELECT CASE WHEN EXISTS ( SELECT COLUMN_NAME
--                                FROM ALL_TAB_COLUMNS 
--                               WHERE OWNER = (SELECT USER FROM DUAL)
--                                 AND TABLE_NAME = 'TB_DP_MEASURE_DATA' 
--                                 AND COLUMN_NAME = 'BF_MEAS_QTY' ) THEN '1' ELSE '0' END
--           INTO p_EXISTS_NUM
--      FROM DUAL;
--
--    IF (p_EXISTS_NUM='1')
--	THEN
--		MERGE INTO TB_DP_MEASURE_DATA TGT
--            USING (
--                    SELECT IT.ID		ITEM_ID
--                          ,AC.ID		ACCT_ID
--                          ,BF.BASE_DATE
--                          ,BF.QTY
--                     FROM TB_BF_RT_FINAL_M BF 
--                          INNER JOIN
--                          TB_CM_ITEM_MST IT 
--                       ON BF.ITEM_CD = IT.ITEM_CD
--                       AND IT.DP_PLAN_YN = 'Y'
--                       AND COALESCE(IT.DEL_YN, 'N') = 'N'
--                          INNER JOIN 
--                          TB_DP_ACCOUNT_MST AC
--                       ON BF.ACCOUNT_CD = AC.ACCOUNT_CD
--                      AND AC.ACTV_YN = 'Y'
--                      AND COALESCE(AC.DEL_YN, 'N') = 'N'	  
--                    WHERE VER_CD = p_VER_CD  				
--                  ) SRC 
--              ON (TGT.ITEM_MST_ID = SRC.ITEM_ID
--             AND TGT.ACCOUNT_ID = SRC.ACCT_ID
--             AND TGT.BASE_dATE = SRC.BASE_DATE)
--		 WHEN MATCHED THEN
--            UPDATE SET TGT.BF_MEAS_QTY = SRC.QTY 
--		 WHEN NOT MATCHED THEN
--             INSERT (ID, ITEM_MST_ID, ACCOUNT_ID, BASE_DATE, BF_MEAS_QTY)
--             VALUES ( TO_SINGLE_BYTE(SYS_GUID())
--                     ,SRC.ITEM_ID
--                     ,SRC.ACCT_ID
--                     ,SRC.BASE_DATE
--                     ,SRC.QTY 
--                    )
--                    ;
--	END IF;
--
--    SELECT CASE WHEN EXISTS ( SELECT COLUMN_NAME
--                                FROM ALL_TAB_COLUMNS 
--                               WHERE OWNER = (SELECT USER FROM DUAL)
--                                 AND TABLE_NAME = 'TB_DP_DIMENSION_DATA' 
--                                 AND COLUMN_NAME = 'BF_MODEL' ) THEN '1' ELSE '0' END
--           INTO p_EXISTS_NUM
--      FROM DUAL;
--
--    IF (p_EXISTS_NUM='1')
--	THEN
--		MERGE	INTO TB_DP_DIMENSION_DATA TGT
--		USING	(
--                SELECT ACC.ITEM_CD
--                     , ACC.ACCOUNT_CD
--                     , ACC.ENGINE_TP_CD AS BF_MODEL
--                     , (100-ACC.WAPE) AS BF_ACCURACY
--                     , I.ID AS ITEM_MST_ID
--                     , A.ID AS ACCOUNT_ID
--                  FROM TB_BF_RT_ACCRCY_M ACC
--                       INNER JOIN TB_CM_ITEM_MST I
--                    ON ACC.ITEM_CD = I.ITEM_CD
--                    AND I.DP_PLAN_YN = 'Y'
--                    AND COALESCE(I.DEL_YN, 'N') = 'N'
--                       INNER JOIN TB_DP_ACCOUNT_MST A
--                    ON ACC.ACCOUNT_CD = A.ACCOUNT_CD
--                   AND A.ACTV_YN = 'Y'
--                   AND COALESCE(A.DEL_YN, 'N') = 'N'
--                 WHERE 1=1
--                   AND ACC.VER_CD = p_VER_CD
--                   AND ACC.SELECT_SEQ = 1
--				) SRC
--		ON		(TGT.ITEM_MST_ID = SRC.ITEM_MST_ID AND TGT.ACCOUNT_ID = SRC.ACCOUNT_ID)
--		WHEN	MATCHED THEN
--		UPDATE
--		SET		TGT.BF_MODEL	= SRC.BF_MODEL
--			,	TGT.BF_ACCURACY = SRC.BF_ACCURACY
--			,	TGT.CREATE_DTTM = SYSDATE
--			,	TGT.CREATE_BY = p_VER_CD
--		WHEN	NOT MATCHED THEN
--		INSERT (ID,ITEM_MST_ID,ACCOUNT_ID,BF_ACCURACY,BF_MODEL,CREATE_DTTM,CREATE_BY)
--		VALUES (TO_SINGLE_BYTE(SYS_GUID()),SRC.ITEM_MST_ID,SRC.ACCOUNT_ID,SRC.BF_ACCURACY,SRC.BF_MODEL,SYSDATE,p_USER_ID)
--        ;
--	END IF;

/*************************************************************************************************************
	-- Change Version Data
*************************************************************************************************************/
	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	   SET STATUS = 'Completed'
		 , RUN_END_DATE = SYSDATE
	 WHERE VER_CD = p_VER_CD
	   AND PROCESS_NO = p_PROCESS_NO 
    ;
	COMMIT;
    /* ============================================================================*/
    P_RT_ROLLBACK_FLAG := 'true';
    -- 저장되었습니다.
    -- SELECT * FROM TB_AD_LANG_PACK WHERE LANG_KEY = 'MSG_0001';
    P_RT_MSG := 'MSG_0001';  

    EXCEPTION
    WHEN OTHERS THEN
        IF(SQLCODE = -20001)
        THEN
            P_RT_ROLLBACK_FLAG := 'false';
            P_RT_MSG := sqlerrm;
        ELSE
            SP_COMM_RAISE_ERR();
            --RAISE;
        END IF;
END ;