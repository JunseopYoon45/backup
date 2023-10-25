CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_00_MONTHLY" (
		P_RT_ROLLBACK_FLAG	OUT VARCHAR2   
      , P_RT_MSG			OUT VARCHAR2 
)
IS
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_00_MONTHLY
   * Purpose : 주 단위 예측 결과를 월 단위로 집계
   * Notes :
   **************************************************************************/
	p_VER_CD			VARCHAR2(100);
	p_FROM_DATE 	 	DATE;
	p_TO_DATE 		 	DATE;
	p_TARGET_FROM_DATE  DATE;
	v_VER_CD 		 	VARCHAR2(100);
	t_VER_CD			VARCHAR2(100);
	out1 			 	VARCHAR2(100);
    out2 			 	VARCHAR2(100);
    a VARCHAR2(20);
	b VARCHAR2(200);
	c VARCHAR2(50);

BEGIN
	/* 가장 최근 버전코드 */
	SELECT MAX(VER_CD)
	  INTO p_VER_CD
	  FROM TB_BF_CONTROL_BOARD_VER_DTL 
	 WHERE VER_CD LIKE 'BF-%'
--	   AND EXTRACT(MONTH FROM RUN_STRT_DATE) = EXTRACT(MONTH FROM SYSDATE)  -- 매월 말일에 수행할 경우
	   AND EXTRACT(MONTH FROM RUN_STRT_DATE) = EXTRACT(MONTH FROM ADD_MONTHS(SYSDATE, -1))  -- 매월 1일에 수행할 경우
	;
	 
	SELECT VER_CD
      INTO t_VER_CD
      FROM (
        SELECT VER_CD
          FROM TB_BF_CONTROL_BOARD_VER_DTL
         WHERE ROWNUM < 2 AND VER_CD LIKE 'BFM-%'
         ORDER BY VER_CD DESC
           );
    /* 해당 월의 1일로 버전코드 명명 */
    SELECT CASE WHEN SUBSTR(t_VER_CD,5,8) != TO_CHAR(TRUNC(SYSDATE, 'MM'), 'YYYYMMDD')
                     THEN 'BFM-' || TO_CHAR(TRUNC(SYSDATE, 'MM'), 'YYYYMMDD') || '-01'
                WHEN SUBSTR(t_VER_CD,5,8) = TO_CHAR(TRUNC(SYSDATE, 'MM'), 'YYYYMMDD')
                     THEN 'BFM-' || TO_CHAR(TRUNC(SYSDATE, 'MM'), 'YYYYMMDD') || '-' || TO_CHAR(TO_NUMBER(SUBSTR(t_VER_CD, 14, 2)) + 1, 'fm00')
                END AS VER_CD
      INTO v_VER_CD
      FROM DUAL;

	SELECT MAX(TARGET_FROM_DATE)
		 , MAX(TARGET_TO_DATE)
		 , ADD_MONTHS(TRUNC(MAX(TARGET_FROM_DATE),'MM'), 1) 
		   INTO
	 	   p_FROM_DATE
	     , p_TO_DATE
	     , p_TARGET_FROM_DATE
	FROM TB_BF_CONTROL_BOARD_VER_DTL
	WHERE VER_CD = p_VER_CD;

	/* 월 예측 버전 생성 */
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
		  FROM TB_BF_CONTROL_BOARD_VER_DTL
		 WHERE VER_CD=p_VER_CD
	);

	COMMIT;

	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	SET INPUT_TO_DATE = NULL,
		TARGET_FROM_DATE = NULL
	WHERE VER_CD = v_VER_CD AND PROCESS_NO IN (1, 990000, 1000000);

	COMMIT;

	UPDATE TB_BF_CONTROL_BOARD_VER_DTL
	SET STATUS = 'Ready'
	WHERE PROCESS_NO IN (990000, 1000000) AND VER_CD = v_VER_CD;

	COMMIT;

	/* 월 예측 결과 생성(PARTIAL WEEK 적용) */
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
--		  AND REGEXP_INSTR(ITEM_CD,'[^0-9]') = 0 
		  AND LENGTH(ITEM_CD) > 4
		  AND ENGINE_TP_CD != 'ZAUTO'
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
	/* PARTIAL WEEK 적용 */
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
		   , v_VER_CD AS VER_CD
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
	
	/* 월 단위 예측 히스토리 생성 */
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
	    /* 월 단위 예측 정확도 계산 */
        SP_UI_BF_16_RT_S2_M(v_VER_CD, 'System', 'WAPE', 990000, out1, out2);
        /* 월 단위 예측값 결정 */
        SP_UI_BF_16_RT_S3_M(v_VER_CD, 'System', 'WAPE', 'PW', 1000000, out1, out2);
        /* 월 단위 품목 시즌지수 생성 */
        SP_UI_BF_00_SEASONAL_INDEX_M(v_VER_CD, out1, out2);
        /* 월 단위 소분류 시즌지수 생성 */
        SP_UI_BF_00_CATE_SEASONAL_INDEX_M(v_VER_CD, out1, out2);
    END;
   
   	COMMIT;
   
	EXCEPTION WHEN OTHERS THEN
		ROLLBACK;
	
		a := SQLCODE;
		b := SQLERRM;
		c := SYS.dbms_utility.format_error_backtrace;
	
		BEGIN
			INSERT INTO TB_SCM100M_ERR_LOG(ERR_FILE, ERR_CODE, ERR_MSG, ERR_LINE, ERR_DTTM)
			SELECT 'SP_UI_BF_00_MONTHLY', a, b, c, SYSDATE FROM DUAL;
		
			COMMIT;
		END;         
END;