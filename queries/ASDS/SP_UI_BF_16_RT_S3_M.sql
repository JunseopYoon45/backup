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
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_BF_16_RT_S3_M
   * Purpose : 월 단위 예측값 결정
   * Notes :
   **************************************************************************/
	p_ERR_STATUS 		INT:=0;
	p_ERR_MSG 			VARCHAR2(4000):='';
	p_TARGET_FROM_DATE 	DATE:='';
	p_TARGET_TO_DATE 	DATE:='';
	p_STD_WK 			VARCHAR2(30):='';
	p_EXISTS_NUM 		VARCHAR2(2):='';
	p_DOW_DEPT 			INT:=0;
	v_BUKT_CD 			VARCHAR2(10):='M';
	OUT1				VARCHAR2(100); 
	OUT2				VARCHAR2(100);
    v_MA_VER_CD         VARCHAR2(50);
    a VARCHAR2(20);
	b VARCHAR2(200);
	c VARCHAR2(50);
--	v_FROM_DATE			DATE;
--	v_TO_DATE			DATE;
--	v_MIN_VER_CD 		VARCHAR2(50);
--	v_VER_COUNT 		NUMBER;
--	v_sql VARCHAR2(100);

BEGIN
    SELECT MAX(VER_CD) INTO v_MA_VER_CD
      FROM TB_BF_CONTROL_BOARD_VER_DTL V
     WHERE 1=1
       AND V.VER_CD LIKE 'BFMA-%'
       AND V.TARGET_FROM_DATE = (
                                SELECT TARGET_FROM_DATE 
                                  FROM TB_BF_CONTROL_BOARD_VER_DTL D
                                 WHERE 1=1
                                   AND D.VER_CD = p_VER_CD
                                   AND D.PROCESS_NO = 10000
                                )
    ;

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
      FROM TB_BF_RT_M
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
	DELETE FROM TB_BF_RT_FINAL_M
	  WHERE VER_CD = p_VER_CD
	  ;
	DELETE FROM TB_BF_RT_FINAL_M_ADJ
	  WHERE VER_CD = p_VER_CD
	  ;
	DELETE FROM TB_SCM102S_CATE_MONTHLY
	  WHERE VER_CD = p_VER_CD
	  ;
	COMMIT;
/*************************************************************************************************************
	-- Get Forecast , Accuracy ...
*************************************************************************************************************/	
    INSERT INTO TB_BF_RT_FINAL_M(
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
	/* 가장 높은 정확도를 기록한 품목-채널 별 엔진 코드 */
	WITH AC AS (
		SELECT ITEM_CD
			 , ACCOUNT_CD
			 , ENGINE_TP_CD
			 , SELECT_SEQ
		  FROM TB_BF_RT_ACCRCY_M
		 WHERE 1=1
		   AND VER_CD = p_VER_CD
		   AND SELECT_SEQ = 1
--		   AND REGEXP_INSTR(ITEM_CD,'[^0-9]') = 0
	)  
    , RT AS (SELECT R.ITEM_CD
				 , R.ACCOUNT_CD
				 , R.BASE_DATE
                 , R.ENGINE_TP_CD
				 , R.QTY  
                 , R.QTY * I.ATTR_01 AS AMT
			  FROM TB_BF_RT_M R
                   INNER JOIN TB_CM_ITEM_MST I
                   ON R.ITEM_CD = I.ITEM_CD
			 WHERE VER_CD = p_VER_CD
--			 AND REGEXP_INSTR(ITEM_CD,'[^0-9]') = 0
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
			 , BASE_DATE
			 , RT.ENGINE_TP_CD
			 , QTY
             , AMT
		  FROM RT
	     INNER JOIN AC
			ON RT.ITEM_CD = AC.ITEM_CD
		   AND RT.ACCOUNT_CD = AC.ACCOUNT_CD
		   AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
		) M
    ;      

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

/*************************************************************************************************************
	-- 상품 센터 월별 보정 테이블 저장
*************************************************************************************************************/
    INSERT INTO TB_BF_RT_FINAL_M_ADJ (
      ID
    , VER_CD
    , ITEM_CD
    , LOCAT_CD
    , BASE_DATE
    , QTY
    , AMT
    , CREATE_BY
    , CREATE_DTTM
    )
    SELECT TO_SINGLE_BYTE(SYS_GUID()) AS ID	
         , A.VER_CD
         , A.ITEM_CD
         , A.LOCAT_CD
         , A.BASE_DATE
         , A.QTY
         , A.AMT
    	 , p_USER_ID AS CREATE_BY
    	 , SYSDATE AS CREATE_DTTM
      FROM (
            SELECT RF.VER_CD
                 , RF.ITEM_CD 
                 , AH.LVL02_CD AS LOCAT_CD
                 , RF.BASE_DATE
                 , SUM(RF.QTY) AS QTY 
                 , SUM(RF.QTY * IH.ATTR_01) AS AMT
              FROM TB_BF_RT_FINAL_M RF
                   INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
                   ON RF.ITEM_CD = IH.ITEM_CD
                   INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH 
                   ON RF.ACCOUNT_CD = AH.ACCOUNT_CD 
             WHERE 1=1
               AND RF.VER_CD = p_VER_CD
             GROUP BY RF.VER_CD,RF.ITEM_CD, AH.LVL02_CD, RF.BASE_DATE 
           ) A
    ;

/*************************************************************************************************************
	-- 소분류 센터 월별 집계 저장
*************************************************************************************************************/
    INSERT INTO TB_SCM102S_CATE_MONTHLY(
      VER_CD
    , CATE_CD
    , LOCAT_CD 
    , BASE_DATE 
    , AMT
    , AMT_MA
    , ADJ_YN 
    , CREATE_BY 
    , CREATE_DTTM 
    )
    SELECT A.VER_CD
         , A.CATE_CD
         , A.LOCAT_CD
         , A.BASE_DATE
         , A.AMT
         , CASE WHEN A.AMT_SEQ = 1 THEN MA_DIV_TMP + (A.MA_AMT - SUM(A.MA_DIV_TMP) OVER(PARTITION BY A.VER_CD,A.CATE_CD,A.BASE_DATE))
                ELSE A.MA_DIV_TMP
            END AS MA_AMT_DIV
         , 'N' ADJ_YN
         , p_USER_ID AS CREATE_BY
         , SYSDATE AS CREATE_DTTM
      FROM (
            SELECT A.VER_CD
                 , A.CATE_CD
                 , A.LOCAT_CD
                 , A.BASE_DATE 
                 , A.AMT
                 , ROW_NUMBER() OVER (PARTITION BY A.VER_CD,A.CATE_CD,A.BASE_DATE ORDER BY A.AMT DESC) AS AMT_SEQ
                 , SUM(A.AMT) OVER (PARTITION BY A.VER_CD, A.CATE_CD, A.BASE_DATE) AS TOT_AMT
                 , CASE WHEN SUM(A.AMT) OVER (PARTITION BY A.VER_CD, A.CATE_CD, A.BASE_DATE) = 0 THEN 0
                        ELSE A.AMT / SUM(A.AMT) OVER (PARTITION BY A.VER_CD, A.CATE_CD, A.BASE_DATE)
                    END AS AMT_RT
                 , MA.QTY AS MA_AMT
                 , ROUND(MA.QTY * (CASE WHEN SUM(A.AMT) OVER (PARTITION BY A.VER_CD, A.CATE_CD, A.BASE_DATE) = 0 THEN 0
                                        ELSE A.AMT / SUM(A.AMT) OVER (PARTITION BY A.VER_CD, A.CATE_CD, A.BASE_DATE)
                                    END),0) AS MA_DIV_TMP
              FROM (
                    SELECT A.VER_CD
                         , IH.LVL04_CD AS CATE_CD
                         , A.LOCAT_CD
                         , A.BASE_DATE
                         , SUM(A.AMT) AS AMT
                      FROM TB_BF_RT_FINAL_M_ADJ A
                           INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
                           ON A.ITEM_CD = IH.ITEM_CD
                     WHERE 1=1
                       AND A.VER_CD = p_VER_CD
                     GROUP BY A.VER_CD, IH.LVL04_CD, A.LOCAT_CD, A.BASE_DATE
                   ) A
                   INNER JOIN TB_BF_RT_FINAL_MA MA
                   ON A.CATE_CD = MA.ITEM_CD
                   AND A.BASE_DATE = MA.BASE_DATE
                   AND MA.VER_CD = v_MA_VER_CD 
             WHERE 1=1
           ) A
    ;

/*************************************************************************************************************
	-- Monthly Center/SKU Sum(Qty)
*************************************************************************************************************/	   
	DELETE FROM TB_BF_RT_FINAL_C 
	 WHERE VER_CD = p_VER_CD;

	INSERT INTO TB_BF_RT_FINAL_C  (
		SELECT RAWTOHEX(SYS_GUID())		AS ID
		     , VER_CD					AS VER_CD		
		     , SUBSTR(ACCOUNT_CD, 1, 2) AS LOCAT_CD		-- 센터
		     , ITEM_CD					AS ITEM_CD		-- SKU
		     , BASE_DATE				AS BASE_DATE
		     , SUM(QTY) 				AS QTY
		     , 'System'					AS CREATE_BY
		     , SYSDATE 					AS CREATE_DTTM
		     , NULL 					AS MODIFY_BY
		     , NULL 					AS MODIFY_DTTM
		  FROM TB_BF_RT_FINAL_M
		 WHERE VER_CD = p_VER_CD
		 GROUP BY VER_CD, SUBSTR(ACCOUNT_CD, 1, 2), ITEM_CD, BASE_DATE
	);
	COMMIT;      


/*************************************************************************************************************
	-- Monthly Sourcing/Center/Category Sum(Qty)
*************************************************************************************************************/	   
	DELETE FROM TB_BF_RT_FINAL_S
	 WHERE VER_CD = p_VER_CD;

	INSERT INTO TB_BF_RT_FINAL_S  (
		SELECT RAWTOHEX(SYS_GUID())		AS ID
		     , RT.VER_CD				AS VER_CD
		     , IH.ATTR_03 				AS SRC_CD		-- 소싱
		     , RT.ACCOUNT_CD			AS ACCOUNT_CD	-- 센터_채널
		     , IH.LVL04_CD				AS CATE_CD		-- 소분류
		     , RT.BASE_DATE				AS BASE_DATE
		     , SUM(RT.QTY) 				AS QTY
		     , 'System'					AS CREATE_BY
		     , SYSDATE 					AS CREATE_DTTM
		     , NULL 					AS MODIFY_BY
		     , NULL 					AS MODIFY_DTTM
		  FROM (
		  		SELECT VER_CD
		  		 	 , ITEM_CD
		  		 	 , ACCOUNT_CD
		  		 	 , BASE_DATE
		  		 	 , QTY
		  		  FROM TB_BF_RT_FINAL_M
		  		 WHERE VER_CD = p_VER_CD
		  	   ) RT
		 INNER JOIN TB_DPD_ITEM_HIERACHY2 IH
		    ON RT.ITEM_CD = IH.ITEM_CD
		 GROUP BY RT.VER_CD, IH.ATTR_03, RT.ACCOUNT_CD, IH.LVL04_CD, RT.BASE_DATE
	);
	COMMIT;	

/*************************************************************************************************************
	-- INSERT DEMAND OVERVIEW
*************************************************************************************************************/	   
	BEGIN
		DWSCM.SP_BF_MAKE_DEMAND_OVERVIEW_M(p_VER_CD, OUT1, OUT2);
	END;


    /* ============================================================================*/
--    P_RT_ROLLBACK_FLAG := 'true';
--    -- 저장되었습니다.
--    -- SELECT * FROM TB_AD_LANG_PACK WHERE LANG_KEY = 'MSG_0001';
--    P_RT_MSG := 'MSG_0001';  
--
--    EXCEPTION
--    WHEN OTHERS THEN
--        IF(SQLCODE = -20001)
--        THEN
--            P_RT_ROLLBACK_FLAG := 'false';
--            P_RT_MSG := sqlerrm;
--        ELSE
--            SP_COMM_RAISE_ERR();
--            --RAISE;
--        END IF;
	EXCEPTION WHEN OTHERS THEN
		ROLLBACK;
	
		a := SQLCODE;
		b := SQLERRM;
		c := SYS.dbms_utility.format_error_backtrace;
	
		BEGIN
			INSERT INTO TB_SCM100M_ERR_LOG(ERR_FILE, ERR_CODE, ERR_MSG, ERR_LINE, ERR_DTTM)
			SELECT 'SP_UI_BF_16_RT_S3_M', a, b, c, SYSDATE FROM DUAL;
		
			COMMIT;
		END;       
END ;