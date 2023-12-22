CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_SCM102S_MONTHLY_S2_J" (
	  P_JSON				CLOB
    , P_USER_ID            VARCHAR2
    , P_RT_ROLLBACK_FLAG   OUT VARCHAR2 
    , P_RT_MSG             OUT VARCHAR2 
) 
IS
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_SCM102S_MONTHLY_S2_J
   * Purpose : 월 수요예측 결과 상품 센터별 수동 보정 저장 
   * Notes :
   **************************************************************************/
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    P_ERR_STATUS    NUMBER          := 0;
    P_ERR_MSG       VARCHAR2(4000)  := '';

BEGIN
	/* 소분류 센터 예측수량 보정 */
    MERGE INTO TB_BF_RT_FINAL_M_ADJ TAR
    USING ( 
            SELECT  
            		CAST(VER_CD AS VARCHAR2(50))     AS VER_CD
            	  , CAST(ITEM_CD AS VARCHAR2(100))   AS ITEM_CD
            	  , CAST(ACCOUNT_CD AS VARCHAR2(100))  AS ACCOUNT_CD
            	  , TO_DATE(BASE_DATE, 'YYYY-MM-DD') AS BASE_DATE
				  , CAST(FINAL_QTY AS NUMBER(20,3))   AS FINAL_QTY
                  , P_USER_ID      AS USER_ID
            FROM JSON_TABLE( P_JSON, '$[*]'
            			COLUMNS (
									VER_CD    PATH '$.VER_CD'
								  , ITEM_CD   PATH '$.ITEM_CD'
								  , ACCOUNT_CD  PATH '$.ACCOUNT_CD'
								  , BASE_DATE PATH '$.BASE_DATE'
								  , FINAL_QTY	  PATH '$.FINAL_QTY'
            					)
            			)
          ) SRC
    ON    (   TAR.VER_CD    = SRC.VER_CD
          AND TAR.ITEM_CD   = SRC.ITEM_CD
          AND TAR.ACCOUNT_CD  = SRC.ACCOUNT_CD
          AND TAR.BASE_DATE = SRC.BASE_DATE
          )
    WHEN MATCHED THEN
         UPDATE 
           SET   TAR.QTY_ADJ     = SRC.FINAL_QTY
                ,TAR.MODIFY_BY    = SRC.USER_ID
                ,TAR.MODIFY_DTTM  = SYSDATE
	;

	/* 보정 FLAG UPDATE */
    MERGE INTO TB_SCM102S_CATE_MONTHLY TAR
    USING ( 
            SELECT DISTINCT A.VER_CD
			     , IH.LVL04_CD AS CATE_CD
			     , AH.LVL02_CD AS LOCAT_CD
				 , A.BASE_DATE
			  FROM (
			        SELECT  
                    		CAST(VER_CD AS VARCHAR2(50))     AS VER_CD
                    	  , CAST(ITEM_CD AS VARCHAR2(100))   AS ITEM_CD
                    	  , CAST(ACCOUNT_CD AS VARCHAR2(100))  AS ACCOUNT_CD
                    	  , TO_DATE(BASE_DATE, 'YYYY-MM-DD') AS BASE_DATE
			        	  , CAST(FINAL_QTY AS NUMBER(20,3))   AS FINAL_QTY
                    FROM JSON_TABLE( P_JSON, '$[*]'
                    			COLUMNS (
			        						VER_CD    PATH '$.VER_CD'
			        					  , ITEM_CD   PATH '$.ITEM_CD'
			        					  , ACCOUNT_CD  PATH '$.ACCOUNT_CD'
			        					  , BASE_DATE PATH '$.BASE_DATE'
			        					  , FINAL_QTY	  PATH '$.FINAL_QTY'
                    					)
                    			)
					) A
					INNER JOIN TB_DPD_ITEM_HIERACHY2 IH
					ON A.ITEM_CD = IH.ITEM_CD
					INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH
					ON A.ACCOUNT_CD = AH.ACCOUNT_CD
          ) SRC
    ON    (   TAR.VER_CD    = SRC.VER_CD
          AND TAR.CATE_CD   = SRC.CATE_CD
          AND TAR.LOCAT_CD  = SRC.LOCAT_CD
          AND TAR.BASE_DATE = SRC.BASE_DATE
          )
    WHEN MATCHED THEN
         UPDATE 
           SET   TAR.ADJ_YN       = 'S'
                ,TAR.MODIFY_BY    = P_USER_ID
                ,TAR.MODIFY_DTTM  = SYSDATE
	;


    COMMIT;
    P_RT_ROLLBACK_FLAG  := 'true';
    P_RT_MSG            := 'MSG_0001';  --저장 되었습니다.

EXCEPTION WHEN OTHERS THEN
    IF (SQLERRM = P_ERR_MSG) THEN
        P_ERR_MSG := SQLERRM;
        P_RT_ROLLBACK_FLAG := 'false';
        P_RT_MSG := P_ERR_MSG;
		ROLLBACK;
    ELSE 
	    ROLLBACK;
        RAISE_APPLICATION_ERROR (SQLCODE, SQLERRM);
--              EXEC SP_COMM_RAISE_ERR
   END IF;
END;