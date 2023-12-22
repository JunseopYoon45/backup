CREATE OR REPLACE PROCEDURE DWSCM.SP_UI_BF_16_RT_S3
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
   * Name : SP_UI_BF_16_RT_S3
   * Purpose : 주 단위 예측값 결정
   * Notes :
   **************************************************************************/ 
	p_ERR_STATUS 		INT:=0;
	p_ERR_MSG 			VARCHAR2(4000):='';
	p_TARGET_FROM_DATE 	DATE:='';
	p_TARGET_TO_DATE 	DATE:='';
	p_STD_WK 			VARCHAR2(30):='';
	p_EXISTS_NUM 		VARCHAR2(2):='';
	p_DOW_DEPT 			INT:=0;
	v_BUKT_CD 			VARCHAR2(10):=p_BUKT_CD;
	v_VER_CD			VARCHAR2(100) := '';
	a VARCHAR2(20);
	b VARCHAR2(200);
	c VARCHAR2(50);

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

	SELECT MAX(TARGET_FROM_DATE)
		 , TRUNC(MAX(TARGET_TO_DATE), 'IW') 
           INTO
           p_TARGET_FROM_DATE
         , p_TARGET_TO_DATE		 
	  FROM TB_BF_CONTROL_BOARD_VER_DTL tbcbvd
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
	SELECT MAX(VER_CD) INTO v_VER_CD
	  FROM TB_BF_CONTROL_BOARD_VER_DTL
	 WHERE VER_CD LIKE 'BFM%'
	   AND PROCESS_NO = 1000000
	   AND STATUS = 'Completed';
	
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
	DELETE FROM TB_BF_RT_FINAL
	  WHERE VER_CD = p_VER_CD
	  ;
	COMMIT;
/*************************************************************************************************************
	-- Get Forecast , Accuracy ...
*************************************************************************************************************/	
    INSERT INTO TB_BF_RT_FINAL( 
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
		SELECT A.ITEM_CD
			 , A.ACCOUNT_CD
			 , ENGINE_TP_CD 
			 , A.SELECT_SEQ
		  FROM TB_BF_RT_ACCRCY A
		 INNER JOIN (SELECT ITEM_CD
		 				  , ACCOUNT_CD
		 				  , MIN(SELECT_SEQ) AS SELECT_SEQ
		 			   FROM TB_BF_RT_ACCRCY
		 			  WHERE VER_CD = p_VER_CD
		 			    AND ENGINE_TP_CD NOT LIKE 'S-%'
		 			  GROUP BY ITEM_CD, ACCOUNT_CD) B -- 23.12.13 SPLIT MODEL 제외하여 모델 선택
		 	ON A.ITEM_CD = B.ITEM_CD
		   AND A.ACCOUNT_CD = B.ACCOUNT_CD
		   AND A.SELECT_SEQ = B.SELECT_SEQ 
		 WHERE 1=1
--		   AND REGEXP_INSTR(ITEM_CD,'[^0-9]') = 0
		   AND VER_CD = p_VER_CD
--		   AND SELECT_SEQ = 1 -- 23.12.13 SPLIT MODEL 제외하여 모델 선택
	)   
    , CA AS (
	    SELECT MIN(DAT)				AS FROM_DATE
			 , MAX(DAT)				AS TO_DATE
			 , MIN(YYYYMM)			AS YYYYMM
			 , COUNT(DAT)			AS DAT_CNT
		  FROM TB_CM_CALENDAR	
	     WHERE DAT BETWEEN p_TARGET_FROM_DATE AND p_TARGET_TO_DATE 
	  GROUP BY YYYY
			 , CASE WHEN v_BUKT_CD IN ('M', 'PW') THEN MM    ELSE '1' END
			 , CASE WHEN v_BUKT_CD IN ('PW', 'W') THEN TO_CHAR(DP_WK) ELSE '1' END 
	) 
    , RT AS (
    	SELECT ITEM_CD
			 , ACCOUNT_CD
             , BASE_DATE
             , ENGINE_TP_CD
			 , QTY 
		  FROM TB_BF_RT 
		 WHERE VER_CD = p_VER_CD
--		   AND REGEXP_INSTR(ITEM_CD,'[^0-9]') = 0
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
			 , RT.QTY
		  FROM RT
		 INNER JOIN AC
			ON RT.ITEM_CD = AC.ITEM_CD
		   AND RT.ACCOUNT_CD = AC.ACCOUNT_CD
		   AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
		) M
    ;    
	COMMIT;
  
/*************************************************************************************************************
		수요예측 결과 보정 MERGE
*************************************************************************************************************/   
      
--	MERGE INTO TB_BF_RT_FINAL A USING (
--		WITH AC AS ( -- 4주 평균 정확도 50% 이하
--			SELECT A.ITEM_CD
--				 , A.ACCOUNT_CD
--				 , ENGINE_TP_CD
--				 , WAPE
--			 FROM TB_BF_RT_ACCRCY A
--			INNER JOIN (SELECT ITEM_CD
--		 				  , ACCOUNT_CD
--		 				  , MIN(SELECT_SEQ) AS SELECT_SEQ
--		 			   FROM TB_BF_RT_ACCRCY
--		 			  WHERE VER_CD = p_VER_CD
--		 			    AND ENGINE_TP_CD NOT LIKE 'S-%'
--		 			  GROUP BY ITEM_CD, ACCOUNT_CD) B -- 23.12.13 SPLIT MODEL 제외하여 모델 선택
--			 	ON A.ITEM_CD = B.ITEM_CD
--			   AND A.ACCOUNT_CD = B.ACCOUNT_CD
--			   AND A.SELECT_SEQ = B.SELECT_SEQ  
--			 WHERE VER_CD = p_VER_CD
----			  AND SELECT_SEQ = 1 -- 23.12.13 SPLIT MODEL 제외하여 모델 선택
--			  AND WAPE >= 50	
--		)
--		, SA AS (
--			SELECT BASE_DATE
--				 , IH.LVL05_CD AS ITEM_CD
--				 , AH.LVL03_CD AS ACCOUNT_CD
--				 , QTY
--			  FROM TB_CM_ACTUAL_SALES SA
--			 INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
--			 	ON SA.ITEM_MST_ID = IH.LVL05_ID
--			 INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH 
--			 	ON SA.ACCOUNT_ID = AH.LVL03_ID
--			 INNER JOIN AC
--			 	ON IH.LVL05_CD = AC.ITEM_CD
--			   AND AH.LVL03_CD = AC.ACCOUNT_CD
--			 WHERE SA.QTY > 0
--			 UNION ALL
--		 	SELECT BASE_DATE
--		 		 , RT.ITEM_CD
--		 		 , RT.ACCOUNT_CD
--		 		 , NULL AS QTY
--		 	 FROM TB_BF_RT RT
--		 	INNER JOIN AC 
--		 	   ON RT.ITEM_CD = AC.ITEM_CD
--		 	  AND RT.ACCOUNT_CD = AC.ACCOUNT_CD
--		 	WHERE VER_CD = p_VER_CD   
--		 	  AND RT.ENGINE_TP_CD = AC.ENGINE_TP_CD
--		)
--		, CON1 AS ( -- 최초 판매일 12개월 이상 (Y)
--			SELECT ITEM_CD	
--				 , ACCOUNT_CD
--				 , MIN(BASE_DATE) AS MIN_DATE
--			 FROM SA
--			HAVING MIN(BASE_DATE) < TRUNC(ADD_MONTHS(SYSDATE, -12), 'IW')
--			GROUP BY ITEM_CD, ACCOUNT_CD
--		) 
--		, CON2 AS ( -- 최초 판매일 12개월 미만 (N)
--			SELECT ITEM_CD	
--				 , ACCOUNT_CD
--				 , MIN(BASE_DATE) AS MIN_DATE
--			 FROM SA
--			HAVING MIN(BASE_DATE) >= TRUNC(ADD_MONTHS(SYSDATE, -12), 'IW')
--			GROUP BY ITEM_CD, ACCOUNT_CD
--		) 
--		, CON3 AS ( -- 최근 한 달 실적 합 20 미만 (Y)
--			SELECT A.ITEM_CD	
--				 , A.ACCOUNT_CD
--			 FROM SA A
--			INNER JOIN CON1 B
--			   ON A.ITEM_CD = B.ITEM_CD
--			  AND A.ACCOUNT_CD = B.ACCOUNT_CD
--			WHERE BASE_DATE BETWEEN TRUNC(ADD_MONTHS(SYSDATE, -1), 'IW') AND TRUNC(SYSDATE, 'IW')
--			HAVING SUM(NVL(QTY, 0)) < 20
--			GROUP BY A.ITEM_CD, A.ACCOUNT_CD
--		)
--		, CON4 AS ( -- 최근 한 달 실적 합 20 이상 (N)
--			SELECT A.ITEM_CD	
--				 , A.ACCOUNT_CD
--			 FROM SA A
--			INNER JOIN CON1 B
--			   ON A.ITEM_CD = B.ITEM_CD
--			  AND A.ACCOUNT_CD = B.ACCOUNT_CD
--			WHERE BASE_DATE BETWEEN TRUNC(ADD_MONTHS(SYSDATE, -1), 'IW') AND TRUNC(SYSDATE, 'IW')
--			HAVING SUM(NVL(QTY, 0)) >= 20
--			GROUP BY A.ITEM_CD, A.ACCOUNT_CD
--		)
--		, SMA AS ( -- 이동평균 3주
--			SELECT A.BASE_DATE
--			     , A.ITEM_CD
--			     , A.ACCOUNT_CD
--			     , NVL(A.QTY, B.QTY) AS QTY 
--			  FROM SA A
--			 INNER JOIN (SELECT ITEM_CD
--							  , ACCOUNT_CD
--							  , BASE_DATE
--							  , QTY
--					  	   FROM (SELECT A.ITEM_CD
--									  , A.ACCOUNT_CD
--									  , BASE_DATE
--									  , NVL(QTY, ROUND(AVG(QTY) OVER(PARTITION BY A.ITEM_CD, A.ACCOUNT_CD ORDER BY BASE_DATE ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING))) AS QTY
--								   FROM SA A
--								  INNER JOIN (SELECT ITEM_CD
--								 	 		 	   , ACCOUNT_CD 
--								 			    FROM CON2 
--								 			   UNION ALL 
--								 			  SELECT ITEM_CD
--								 			  	   , ACCOUNT_CD 
--								 			    FROM CON3) B
--								     ON A.ITEM_CD = B.ITEM_CD
--								    AND A.ACCOUNT_CD = B.ACCOUNT_CD)
--						  WHERE BASE_DATE = TRUNC(SYSDATE, 'IW')) B 
--				ON A.ITEM_CD = B.ITEM_CD 
--			   AND A.ACCOUNT_CD = B.ACCOUNT_CD
--			 WHERE A.BASE_DATE >= TRUNC(SYSDATE, 'IW') 
--		) 
--		, YOY AS (
--			SELECT A.ITEM_CD
--				 , A.ACCOUNT_CD
--				 , BASE_DATE
--				 , QTY
--			  FROM (SELECT DISTINCT ITEM_CD, ACCOUNT_CD 
--			          FROM (
--						SELECT A.ITEM_CD
--							 , A.ACCOUNT_CD
--						  FROM CON4 A
--						 INNER JOIN (SELECT ITEM_CD
--						 				  , RES_STRONG 
--						 			   FROM TB_BF_SEASONAL_INDEX_M 
--						 			  WHERE VER_CD = v_VER_CD
--						 			    AND RES_STRONG = 1) B 
--						 	ON A.ITEM_CD = B.ITEM_CD
--						 INNER JOIN TB_CM_ITEM_MST C
--						    ON A.ITEM_CD = C.ITEM_CD
--						 WHERE C.ATTR_03 = 'FR'
--						 UNION ALL
--						SELECT A.ITEM_CD
--							 , A.ACCOUNT_CD
--						  FROM CON4 A			  
--						 INNER JOIN TB_CM_ITEM_MST C
--						    ON A.ITEM_CD = C.ITEM_CD
--						 WHERE (C.ATTR_06 = 'SES' OR C.ATTR_06 = 'SRZ')
--						   AND C.ATTR_03 = 'FR'
--						 )
--				     ) A
--			 INNER JOIN AC B
--			 	ON A.ITEM_CD = B.ITEM_CD
--			   AND A.ACCOUNT_CD = B.ACCOUNT_CD
--			   AND WAPE >= 80			 
--			 INNER JOIN (SELECT ITEM_CD
--			 				  , ACCOUNT_CD
--			 				  , BASE_DATE
--			 				  , QTY 
--			 			   FROM TB_BF_RT 
--			 			  WHERE VER_CD = p_VER_CD
--			 			    AND ENGINE_TP_CD = 'YOY') C
--				ON A.ITEM_CD = C.ITEM_CD
--			   AND A.ACCOUNT_CD = C.ACCOUNT_CD	 
--			 WHERE BASE_DATE >= TRUNC(SYSDATE, 'IW')  
--		)
--		, AGG AS (
--		  	SELECT p_VER_CD AS VER_CD, ITEM_CD, ACCOUNT_CD, BASE_DATE, QTY, 'SMA' AS MODIFY_BY
--			  FROM SMA
--		     UNION ALL 
--		    SELECT p_VER_CD AS VER_CD, ITEM_CD, ACCOUNT_CD, BASE_DATE, QTY, 'YOY' AS MODIFY_BY
--		      FROM YOY 	
--		) SELECT * FROM AGG) B
--			  ON (A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE AND A.VER_CD = B.VER_CD)
--		WHEN MATCHED THEN
--		UPDATE SET A.QTY = B.QTY, A.MODIFY_BY = B.MODIFY_BY , A.MODIFY_DTTM = SYSDATE;
--   	COMMIT;
   
	MERGE INTO TB_BF_RT_FINAL A USING (
		WITH AC AS ( -- 4주 평균 정확도 50% 이하
				SELECT A.ITEM_CD
					 , A.ACCOUNT_CD
					 , ENGINE_TP_CD
				  FROM TB_BF_RT_ACCRCY A
				 INNER JOIN (SELECT ITEM_CD
			 				      , ACCOUNT_CD
			 				  	  , MIN(SELECT_SEQ) AS SELECT_SEQ
				 			   FROM TB_BF_RT_ACCRCY A
				 			  WHERE VER_CD = p_VER_CD
--				 			    AND ENGINE_TP_CD NOT LIKE 'S-%'
--				 			    AND ENGINE_TP_CD NOT IN ('SMA3M', 'CRST')
				 			    AND ENGINE_TP_CD IN ('RF', 'GBM', 'PR', 'YOY')
				 			  GROUP BY ITEM_CD, ACCOUNT_CD) B -- 23.12.20 강한시즌성 OR 시즌/시리즈 품목 SMA3M, CRST 제외하고 모델 선택
				 	ON A.ITEM_CD = B.ITEM_CD
				   AND A.ACCOUNT_CD = B.ACCOUNT_CD
				   AND A.SELECT_SEQ = B.SELECT_SEQ  
				 INNER JOIN (SELECT ITEM_CD
				 			   FROM TB_CM_ITEM_MST
				 			  WHERE ATTR_06 IN ('SES', 'SRZ')
				 			  UNION
				 			 SELECT ITEM_CD
				 			   FROM TB_BF_SEASONAL_INDEX_M
				 			  WHERE RES_STRONG = 1
				 			    AND VER_CD = v_VER_CD) C
				    ON A.ITEM_CD = C.ITEM_CD			 			    
				 WHERE VER_CD = p_VER_CD
			) 
			, RT AS (
				SELECT A.ITEM_CD
					 , A.ACCOUNT_CD
					 , BASE_DATE
					 , A.ENGINE_TP_CD
					 , QTY
				  FROM TB_BF_RT A
				 INNER JOIN AC 
				    ON A.ITEM_CD = AC.ITEM_CD
				   AND A.ACCOUNT_CD = AC.ACCOUNT_CD
				   AND A.ENGINE_TP_CD = AC.ENGINE_TP_CD
				 WHERE A.VER_CD = p_VER_CD
			) SELECT p_VER_CD AS VER_CD
				   , ITEM_CD
				   , ACCOUNT_CD
				   , BASE_DATE
				   , QTY
				   , 'ADJ' AS MODIFY_BY 
				FROM RT) B
				  ON (A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE AND A.VER_CD = B.VER_CD)
			WHEN MATCHED THEN
			UPDATE SET A.QTY = B.QTY, A.MODIFY_BY = B.MODIFY_BY , A.MODIFY_DTTM = SYSDATE;
   	COMMIT;

    /*수요예측 결과 보정 테이블 저장*/
    INSERT INTO TB_BF_RT_FINAL_ADJ (
		ID,
	    VER_CD,
	    ITEM_CD, 
	    ACCOUNT_CD, 
	    BASE_DATE, 
	    QTY, 
	    QTY_RT, 
	    ADD_YN, 
	    CREATE_BY, 
	    CREATE_DTTM 
    )
    SELECT ID
         , VER_CD 
         , ITEM_CD 
         , ACCOUNT_CD 
         , BASE_DATE 
         , QTY AS QTY
         , QTY AS QTY_RT
         , 'N' AS ADD_YN
         , CREATE_BY 
         , CREATE_DTTM 
      FROM TB_BF_RT_FINAL
     WHERE VER_CD = p_VER_CD
    ;
   
    /*예측값 없는 센터에 최근 1주 실적 평균 생성*/
    INSERT INTO TB_BF_RT_FINAL_ADJ(
    	ID,
    	VER_CD, 
    	ITEM_CD, 
    	ACCOUNT_CD, 
    	BASE_DATE, 
    	QTY_RT, 
    	ADD_YN, 
    	CREATE_BY, 
    	CREATE_DTTM 
    )
    WITH IL AS (
    SELECT A.CATE_CD
         , A.ITEM_CD
         , SLM.SALES_LV_CD AS LOCAT_CD
      FROM (
            SELECT A.CATE_CD
                 , A.ITEM_CD
              FROM (
                    SELECT IH.LVL04_CD AS CATE_CD
                         , IH.ITEM_CD
                      FROM TB_BF_RT_FINAL RF
                           INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
                           ON RF.ITEM_CD = IH.ITEM_CD 
                           INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH 
                           ON RF.ACCOUNT_CD = AH.ACCOUNT_CD 
                     WHERE 1=1
                       AND RF.VER_CD = p_VER_CD
                     GROUP BY IH.LVL04_CD
                            , IH.ITEM_CD
                   ) A
           ) A
           CROSS JOIN TB_DP_SALES_LEVEL_MGMT SLM
     WHERE SLM.LV_MGMT_ID = 'FE00001E54F88F3FE053DD0A10AC762B'
       AND SLM.ACTV_YN = 'Y'
    MINUS
    SELECT A.CATE_CD
         , A.ITEM_CD
         , A.LOCAT_CD
      FROM (
            SELECT IH.LVL04_CD AS CATE_CD
                 , IH.ITEM_CD
                 , AH.LVL02_CD AS LOCAT_CD
              FROM TB_BF_RT_FINAL RF
                   INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
                   ON RF.ITEM_CD = IH.ITEM_CD 
                   INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH 
                   ON RF.ACCOUNT_CD = AH.ACCOUNT_CD 
             WHERE 1=1
               AND RF.VER_CD = p_VER_CD
             GROUP BY IH.LVL04_CD
                    , IH.ITEM_CD
                    , AH.LVL02_CD
           ) A
     WHERE 1=1
    )
    SELECT TO_SINGLE_BYTE(SYS_GUID())  AS ID
         , p_VER_CD AS VER_CD
         , A.ITEM_CD
         , AH.ACCOUNT_CD 
         , A.BASE_DATE
         , A. QTY_RT
         , 'Y' AS ADD_YN
         , p_USER_ID AS CREATE_BY
         , SYSDATE AS CREATE_DTTM 
      FROM (
            SELECT A.ITEM_CD
                 , B.BASE_DATE
                 , A.ITEM_AVG AS QTY_RT
              FROM (
                    SELECT IH.ITEM_CD
                         , ROUND(SUM(ACT.QTY)/6,0) AS ITEM_AVG
                      FROM TB_CM_ACTUAL_SALES ACT
                           INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
                           ON ACT.ITEM_MST_ID = IH.ITEM_ID 
                     WHERE 1=1
                       AND ACT.BASE_DATE = (SELECT TARGET_FROM_DATE - 7   FROM TB_BF_CONTROL_BOARD_VER_DTL WHERE VER_CD = p_VER_CD AND PROCESS_NO = 10000)
                       AND IH.ITEM_CD IN (SELECT DISTINCT ITEM_CD FROM IL)
                     GROUP BY IH.ITEM_CD
                    ) A
                    CROSS JOIN (SELECT DISTINCT BASE_DATE FROM TB_BF_RT_FINAL WHERE VER_CD = p_VER_CD ) B
             WHERE A.ITEM_AVG > 0
           ) A
           INNER JOIN IL ON A.ITEM_CD = IL.ITEM_CD
           INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH ON IL.LOCAT_CD = AH.LVL02_CD
    ;
	COMMIT;

/*************************************************************************************************************
		신제품 수요예측 결과 생성
*************************************************************************************************************/
   
	INSERT INTO TB_BF_RT_FINAL_NEW (
		ID,
		VER_CD,
		ITEM_CD,
		ACCOUNT_CD,
		BASE_DATE,
		FCST_POLICY,
		RTFCST,
		CATDIV,
		SALFCST,
		CREATE_BY,
		CREATE_DTTM,
		MODIFY_BY,
		MODIFY_DTTM
	)
	WITH FP AS (
		SELECT ITEM_CD
			 , FCST_POLICY
			 , QTY_RATIO
			 , ATTR_01
		  FROM TB_BF_NEW_ITEM_FCST_POLICY 
		)
	, IA AS (
		SELECT A.ITEM_CD
			 , A.ACCOUNT_CD
			 , ENGINE_TP_CD
		  FROM TB_BF_RT_ACCRCY A
		 INNER JOIN (SELECT A.ITEM_CD
				 		  , ACCOUNT_CD
						  , MIN(SELECT_SEQ) SELECT_SEQ 
					   FROM TB_BF_RT_ACCRCY A
					  INNER JOIN FP B ON A.ITEM_CD = B.ITEM_CD
					  WHERE VER_CD = p_VER_CD
					    AND ENGINE_TP_CD LIKE 'S-%'
					  GROUP BY A.ITEM_CD, ACCOUNT_CD) B
		    ON A.ITEM_CD = B.ITEM_CD 
		   AND A.ACCOUNT_CD = B.ACCOUNT_CD 
		   AND A.SELECT_SEQ = B.SELECT_SEQ
		 WHERE VER_CD = p_VER_CD
	)
	, RT_C AS (
		SELECT ITEM_CD
		     , ACCOUNT_CD
		     , BASE_DATE
			 , QTY  AS CATDIV
		 FROM (
			SELECT A.ITEM_CD
				 , A.ACCOUNT_CD
				 , A.ENGINE_TP_CD
				 , BASE_DATE
				 , QTY
			  FROM TB_BF_RT A
			 INNER JOIN IA B
			   ON A.ITEM_CD = B.ITEM_CD
			  AND A.ACCOUNT_CD = B.ACCOUNT_CD
			  AND A.ENGINE_TP_CD = B.ENGINE_TP_CD
			 WHERE VER_CD = p_VER_CD
			 )
		) 
		, RT_F AS (
			  SELECT ITEM_CD
				   , ACCOUNT_CD
				   , BASE_DATE
				   , QTY AS RTFCST
			   FROM (
					SELECT A.ITEM_CD
						 , A.ACCOUNT_CD
						 , A.BEST_ENGINE_TP_CD AS ENGINE_TP_CD
						 , BASE_DATE
						 , QTY
					  FROM TB_BF_RT_FINAL A
					 INNER JOIN FP B
					   ON A.ITEM_CD = B.ITEM_CD
					 WHERE VER_CD = p_VER_CD
					 )
		) 
		, RT_S AS (
	 	  SELECT ITEM_CD
			   , ACCOUNT_CD
			   , BASE_DATE
			   , ROUND(QTY * QTY_RATIO) AS SALFCST
			   FROM (
		    SELECT A.ITEM_CD
				 , A.ACCOUNT_CD
				 , A.ENGINE_TP_CD
				 , BASE_DATE 
				 , QTY
				 , A.QTY_RATIO
			  FROM (SELECT ITEM_CD
			  			 , ACCOUNT_CD
			  			 , BASE_DATE
			  			 , ENGINE_TP_CD
			  			 , QTY 
			  		  FROM TB_BF_RT WHERE VER_CD = p_VER_CD) RT
			 INNER JOIN (SELECT A.ITEM_CD
						 	  , ACCOUNT_CD
						 	  , CASE WHEN BEST_ENGINE_TP_CD LIKE 'S-%' THEN SUBSTR(BEST_ENGINE_TP_CD, 3)
						 	  		 ELSE BEST_ENGINE_TP_CD END AS ENGINE_TP_CD
						 	  , MAX(QTY_RATIO) AS QTY_RATIO
						 	  , ATTR_01 AS CATE_CD
					 	   FROM TB_BF_RT_FINAL A 
						   INNER JOIN FP B ON A.ITEM_CD = B.ITEM_CD
						   WHERE VER_CD = p_VER_CD
						   GROUP BY A.ITEM_CD, ACCOUNT_CD, BEST_ENGINE_TP_CD, QTY_RATIO, ATTR_01) A
			 	ON RT.ITEM_CD = A.CATE_CD
			   AND RT.ACCOUNT_CD = A.ACCOUNT_CD
			   AND RT.ENGINE_TP_CD = A.ENGINE_TP_CD)
		) 
		SELECT RAWTOHEX(SYS_GUID()) AS ID
			 , p_VER_CD AS VER_CD
			 , A.ITEM_CD
			 , A.ACCOUNT_CD
			 , A.BASE_DATE
			 , D.FCST_POLICY
			 , A.RTFCST
			 , NVL(B.CATDIV, 0) AS CATDIV
			 , C.SALFCST
			 , 'SYSTEM' AS CREATE_BY
			 , SYSDATE  AS CREATE_DTTM
			 , NULL		AS MODIFY_BY
			 , NULL		AS MODIFY_DTTM
		  FROM RT_F A
	 	  LEFT JOIN RT_C B
	 	    ON A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE
	 	 INNER JOIN RT_S C
	  	    ON A.ITEM_CD = C.ITEM_CD AND A.ACCOUNT_CD = C.ACCOUNT_CD AND A.BASE_DATE = C.BASE_DATE
	  	 INNER JOIN FP D
	        ON A.ITEM_CD = D.ITEM_CD;   
	COMMIT;

/*************************************************************************************************************
		신제품 수요예측 결과 MERGE
*************************************************************************************************************/	       	       
   MERGE INTO TB_BF_RT_FINAL_ADJ A USING (
	    SELECT VER_CD
			 , ITEM_CD
			 , ACCOUNT_CD
			 , BASE_DATE
			 , FCST_POLICY
			 , CASE WHEN FCST_POLICY = 'RTFCST' THEN RTFCST
			 		WHEN FCST_POLICY = 'CATDIV' THEN CATDIV
			 		WHEN FCST_POLICY = 'SALFCST' THEN SALFCST END AS QTY
	     FROM TB_BF_RT_FINAL_NEW
	    WHERE VER_CD = p_VER_CD) B
		ON (A.ITEM_CD = B.ITEM_CD AND A.ACCOUNT_CD = B.ACCOUNT_CD AND A.BASE_DATE = B.BASE_DATE AND A.VER_CD = B.VER_CD)
		WHEN MATCHED THEN 
			  UPDATE SET A.QTY_ADJ = B.QTY, A.MODIFY_BY = 'SYSTEM', A.MODIFY_DTTM = SYSDATE;	   
   
			 
			 
   /*소분류 센터 주별 예측 결과 저장*/
    INSERT INTO TB_SCM101S_CATE_WEEKLY(
      VER_CD
    , CATE_CD
    , LOCAT_CD 
    , BASE_DATE 
    , QTY
    , ADD_YN
    , ADJ_YN 
    , CREATE_BY 
    , CREATE_DTTM 
    )
    SELECT A.VER_CD
         , B.LVL04_CD AS CATE_CD
         , C.LVL02_CD AS LOCAT_CD
         , A.BASE_DATE 
         , SUM(NVL(A.QTY,0)) AS QTY
         , MAX(A.ADD_YN) AS ADD_YN
         , 'N' AS ADJ_YN 
         , p_USER_ID AS CREATE_BY
         , SYSDATE AS CREATE_DTTM
      FROM TB_BF_RT_FINAL_ADJ A
           INNER JOIN TB_DPD_ITEM_HIERACHY2 B
           ON A.ITEM_CD = B.ITEM_CD
           INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 C
           ON A.ACCOUNT_CD = C.ACCOUNT_CD 
     WHERE 1=1
       AND A.VER_CD = p_VER_CD
     GROUP BY A.VER_CD,B.LVL04_CD, B.LVL04_NM, C.LVL02_CD, C.LVL02_NM, A.BASE_DATE
    ;
	COMMIT;

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
--                     FROM TB_BF_RT_FINAL BF 
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
--                  FROM TB_BF_RT_ACCRCY ACC
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
			SELECT 'SP_UI_BF_16_RT_S3', a, b, c, SYSDATE FROM DUAL;
		
			COMMIT;
		END;       
END ;