CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_00_MONTHLY" (
		p_VER_CD  			VARCHAR2
	  , P_RT_ROLLBACK_FLAG	OUT VARCHAR2   
      , P_RT_MSG			OUT VARCHAR2
)
IS
	p_FROM_DATE 	 	DATE;
	p_TO_DATE 		 	DATE;
	p_TARGET_FROM_DATE  DATE;
	v_VER_CD 		 	VARCHAR2(100);
	out1 			 	VARCHAR2(100);
    out2 			 	VARCHAR2(100);

BEGIN
	SELECT MAX(TARGET_FROM_DATE)
		 , MAX(TARGET_TO_DATE)
		 , ADD_MONTHS(TRUNC(MAX(TARGET_FROM_DATE),'MM'), 1) 
		 , REPLACE(MAX(VER_CD), 'BF-', 'BFM-')
		   INTO
	 	   p_FROM_DATE
	     , p_TO_DATE
	     , p_TARGET_FROM_DATE
	     , v_VER_CD
	FROM TB_BF_CONTROL_BOARD_VER_DTL
	WHERE VER_CD = p_VER_CD;	

	INSERT INTO TB_BF_CONTROL_BOARD_VER_DTL (
		SELECT RAWTOHEX(SYS_GUID()) 	AS ID
			 , v_VER_CD		 			AS VER_CD
			 , PROCESS_NO
			 , ENGINE_TP_CD
			 , STATUS
			 , RUN_STRT_DATE
			 , RUN_END_DATE
			 , DESCRIP
			 , RULE_01
			 , INPUT_HORIZ
			 , INPUT_BUKT_CD
			 , TARGET_HORIZ
			 , REPLACE(TARGET_BUKT_CD, 'W', 'M')			AS TARGET_BUKT_CD
			 , INPUT_FROM_DATE 							 	AS INPUT_FROM_DATE
			 , p_TARGET_FROM_DATE - 1 						AS INPUT_TO_DATE
			 , p_TARGET_FROM_DATE 							AS TARGET_FROM_DATE
			 , LAST_DAY(TARGET_TO_DATE)		 			 	AS TARGET_TO_DATE
			 , SALES_LV_CD
			 , ITEM_LV_CD
			 , ATTR_01
			 , ATTR_02
			 , ATTR_03
			 , ATTR_04
			 , ATTR_05
			 , ATTR_06
			 , ATTR_07
			 , ATTR_08
			 , ATTR_09
			 , ATTR_10
			 , 'admin'  AS CREATE_BY
			 , SYSDATE  AS CREATE_DTTM
			 , NULL 	AS MODIFY_BY
			 , NULL 	AS MODIFY_DTTM
			 , SHARD_NO
			 , VAL_TP
		  FROM TB_BF_CONTROL_BOARD_VER_DTL tbcbvd
		 WHERE VER_CD=p_VER_CD
	);

	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	SET STATUS = 'Ready'
	WHERE PROCESS_NO IN (990000, 1000000) AND VER_CD = v_VER_CD;

	INSERT INTO TB_BF_RT_M
	WITH RT AS (
		SELECT BASE_DATE + 0	AS FROM_DATE
		     , COALESCE(LEAD(BASE_DATE+0,1) OVER (PARTITION BY ENGINE_TP_CD, ITEM_CD, ACCOUNT_CD ORDER BY BASE_DATE ASC)-1, p_TO_DATE ) AS TO_DATE
		     , ITEM_CD
		     , ACCOUNT_CD
		     , ENGINE_TP_CD
		     , QTY
		 FROM TB_BF_RT
		WHERE VER_CD = p_VER_CD
	) 
	, CAL AS (
	    SELECT MIN(DAT)				AS FROM_DATE
			 , MAX(DAT)				AS TO_DATE
			 , COUNT(DAT)			AS DAT_CNT
			 , MM
		  FROM TB_CM_CALENDAR	
	     WHERE DAT BETWEEN p_FROM_DATE AND p_TO_DATE
	  GROUP BY YYYY, MM, TO_CHAR(DP_WK)
	)
	, PW_RT AS (
			SELECT CAL.FROM_DATE AS BASE_DATE
				 , ITEM_CD
				 , ACCOUNT_CD
				 , ENGINE_TP_CD
				 , CAL.MM
			 	 , ROUND(RT.QTY * CAL.DAT_CNT / (RT.TO_DATE-RT.FROM_DATE+1))  AS QTY
		 	  FROM RT 
			 INNER JOIN CAL ON CAL.FROM_DATE BETWEEN RT.FROM_DATE AND RT.TO_DATE
	) 
	, M_RT AS (
		SELECT MIN(BASE_DATE) AS BASE_DATE
			 , ITEM_CD
			 , ACCOUNT_CD
			 , ENGINE_TP_CD
			 , SUM(QTY) AS QTY
		FROM PW_RT
		WHERE BASE_DATE >= p_TARGET_FROM_DATE
		GROUP BY ITEM_CD, ACCOUNT_CD, ENGINE_TP_CD, MM
	) SELECT RAWTOHEX(SYS_GUID()) 			  AS ID
		   , ENGINE_TP_CD
		   , REPLACE(p_VER_CD, 'BF-', 'BFM-') AS VER_CD
		   , ITEM_CD
		   , ACCOUNT_CD
		   , BASE_DATE
		   , QTY
		   , 'admin' AS CREATE_BY
		   , SYSDATE AS CREATE_DTTM
		   , NULL	 AS MODIFY_BY
		   , NULL 	 AS MODIFY_DTTM
		FROM M_RT;
	
	COMMIT;

	MERGE INTO TB_BF_RT_HISTORY_M TGT
        USING (
            SELECT ID
                 , CASE WHEN ENGINE_TP_CD like 'ZAUTO%' then 'ZAUTO' else ENGINE_TP_CD END ENGINE_TP_CD
                 , ITEM_CD
                 , ACCOUNT_CD
                 , BASE_DATE
                 , QTY
                 , VER_CD
                 , 'SYS' AS USER_ID
                 , SYSDATE AS DTTM
              FROM TB_BF_RT_M
             WHERE VER_CD = v_VER_CD
        ) SRC
        ON (TGT.ITEM_CD = SRC.ITEM_CD
        AND TGT.ACCOUNT_CD = SRC.ACCOUNT_CD
        AND TGT.BASE_DATE = SRC.BASE_DATE
        AND CASE WHEN TGT.ENGINE_TP_CD like 'ZAUTO%' THEN 'ZAUTO' ELSE TGT.ENGINE_TP_CD END = SRC.ENGINE_TP_CD)
        WHEN MATCHED THEN
            UPDATE
               SET TGT.QTY = SRC.QTY
                 , TGT.VER_CD = SRC.VER_CD
                 , TGT.MODIFY_BY = SRC.USER_ID
                 , TGT.MODIFY_DTTM = SRC.DTTM
        WHEN NOT MATCHED THEN
            INSERT (
                ID
              , ENGINE_TP_CD
              , VER_CD
              , ITEM_CD
              , ACCOUNT_CD
              , BASE_DATE
              , QTY
              , CREATE_BY
              , CREATE_DTTM
            )
            VALUES (
                SRC.ID
              , SRC.ENGINE_TP_CD
              , SRC.VER_CD
              , SRC.ITEM_CD
              , SRC.ACCOUNT_CD
              , SRC.BASE_DATE
              , SRC.QTY
              , SRC.USER_ID
              , SRC.DTTM
            )
        ;

    COMMIT;
       
    BEGIN
        SP_UI_BF_16_RT_S2_M(v_VER_CD, 'System', 'WAPE', 990000, out1, out2);
        SP_UI_BF_16_RT_S3_M(v_VER_CD, 'System', 'WAPE', NULL, 1000000, out1, out2);
    END;
   
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