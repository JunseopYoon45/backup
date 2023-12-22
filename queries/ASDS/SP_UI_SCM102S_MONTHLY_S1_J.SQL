CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_SCM102S_MONTHLY_S1_J" (
	  P_JSON				CLOB
    , P_USER_ID            VARCHAR2
    , P_RT_ROLLBACK_FLAG   OUT VARCHAR2 
    , P_RT_MSG             OUT VARCHAR2 
) 
IS
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_SCM102S_MONTHLY_S1_J
   * Purpose : 월 수요예측 결과 소분류 센터 보정 저장 
   * Notes :
   * TB_SCM102S_CATE_MONTHLY 테이블 ADJ_YN 컬럼 - 보정 상태
   * ** N : 보정 전
   * ** Y : 보정 후
   * ** S : 상품 채널 분배
   * ** C : 확정 - 보충계획 전송
   **************************************************************************/
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    P_ERR_STATUS    NUMBER          := 0;
    P_ERR_MSG       VARCHAR2(4000)  := '';

BEGIN
	/* 소분류 센터 예측수량 보정 */
    MERGE INTO TB_SCM102S_CATE_MONTHLY TAR
    USING ( 
            SELECT  
            		CAST(VER_CD AS VARCHAR2(50))     AS VER_CD
            	  , CAST(CATE_CD AS VARCHAR2(100))   AS CATE_CD
            	  , CAST(LOCAT_CD AS VARCHAR2(100))  AS LOCAT_CD
            	  , TO_DATE(BASE_DATE, 'YYYY-MM-DD') AS BASE_DATE
				  , CAST(QTY_ADJ AS NUMBER(20,3))    AS QTY_ADJ
                  , P_USER_ID      AS USER_ID
            FROM JSON_TABLE( P_JSON, '$[*]'
            			COLUMNS (
									VER_CD    PATH '$.VER_CD'
								  , CATE_CD   PATH '$.CATE_CD'
								  , LOCAT_CD  PATH '$.LOCAT_CD'
								  , BASE_DATE PATH '$.BASE_DATE'
								  , QTY_ADJ	  PATH '$.QTY_ADJ'
            					)
            			)
          ) SRC
    ON    (   TAR.VER_CD    = SRC.VER_CD
          AND TAR.CATE_CD   = SRC.CATE_CD
          AND TAR.LOCAT_CD  = SRC.LOCAT_CD
          AND TAR.BASE_DATE = SRC.BASE_DATE
          )
    WHEN MATCHED THEN
         UPDATE 
           SET   TAR.QTY_ADJ     = SRC.QTY_ADJ
                ,TAR.ADJ_YN      = 'Y'
                ,TAR.MODIFY_BY    = SRC.USER_ID
                ,TAR.MODIFY_DTTM  = SYSDATE
	;

	/* 상품 센터별 월 보정수량 분배 */
    MERGE INTO TB_BF_RT_FINAL_M_ADJ TAR
    USING (
    SELECT A.VER_CD
		 , A.ITEM_CD
		 , A.ACCOUNT_CD
		 , A.BASE_DATE
		 , A.QTY AS FRCT_QTY
		 , A.ITEM_RT
		 , NVL(A.ADJ_QTY,A.QTY) AS ADJ_QTY
         , A.ITEM_ADD_YN
         , A.ADJ_YN
      FROM (
            SELECT A.VER_CD
                 , A.LG_CATE_CD
                 , A.LG_CATE_NM
                 , A.MD_CATE_CD
                 , A.MD_CATE_NM
                 , A.CATE_CD
                 , A.CATE_NM
            	 , A.ITEM_CD
                 , A.ITEM_NM
            	 , A.LOCAT_CD
                 , A.LOCAT_NM
            	 , A.ACCOUNT_CD
                 , A.ACCOUNT_NM
                 , A.BASE_DATE
            	 , A.QTY
                 , ROUND(A.ITEM_RT,5) AS ITEM_RT
                 , CASE WHEN ROW_NUMBER() OVER (PARTITION BY A.CATE_CD,A.LOCAT_CD ORDER BY A.ITEM_QTY DESC) = 1 -- 수요예측 수량이 가장 많은 상품 채널에 반올림 단수차 발생한 수량 적용
                        THEN ROUND(A.ITEM_RT * A.NEW_ADJ,0) + (A.NEW_ADJ - SUM(ROUND(A.ITEM_RT * A.NEW_ADJ,0)) OVER (PARTITION BY A.CATE_CD, A.LOCAT_CD, A.BASE_DATE))
                        ELSE ROUND(A.ITEM_RT * A.NEW_ADJ,0)
                   END AS ADJ_QTY
            	 , A.NEW_ADD
                 , A.ITEM_ADD_YN
                 , A.ADJ_YN
              FROM (
                   SELECT RF.VER_CD
                        , IH.LVL02_CD AS LG_CATE_CD
                        , IH.LVL02_NM AS LG_CATE_NM
                        , IH.LVL03_CD AS MD_CATE_CD
                        , IH.LVL03_NM AS MD_CATE_NM
            	        , IH.LVL04_CD AS CATE_CD
                        , IH.LVL04_NM AS CATE_NM
                        , IH.ITEM_CD AS ITEM_CD
                        , IH.ITEM_NM AS ITEM_NM
                        , AH.LVL02_CD AS LOCAT_CD
                        , AH.LVL02_NM AS LOCAT_NM
                        , AH.ACCOUNT_CD
                        , AH.ACCOUNT_NM
                        , RF.BASE_DATE
                        , RF.QTY
                        , RF.QTY_RT AS ITEM_QTY
                        , CW.QTY AS CATE_QTY
                        , CW.QTY_ADJ AS CATE_ADJ
                        , SUM(RF.QTY_RT) OVER (PARTITION BY IH.LVL04_CD, AH.LVL02_CD, RF.BASE_DATE) AS CATE_LOC_QTY
                        , CASE WHEN SUM(RF.QTY_RT) OVER (PARTITION BY IH.LVL04_CD, AH.LVL02_CD, RF.BASE_DATE) = 0 THEN 0
                               ELSE RF.QTY_RT / SUM(NVL(RF.QTY_RT,0)) OVER (PARTITION BY IH.LVL04_CD, AH.LVL02_CD, RF.BASE_DATE)
                           END AS ITEM_RT
                        , CASE WHEN CW.QTY < CW.QTY_ADJ AND CW.ADD_YN = 'Y' THEN CW.QTY_ADJ - CW.QTY ELSE CW.QTY_ADJ END NEW_ADJ 
                        , CW.ADJ_YN
                        , CW.ADD_YN
                        , CASE WHEN CW.QTY < CW.QTY_ADJ THEN CW.ADD_YN ELSE 'N' END AS NEW_ADD
                        , RF.ADD_YN AS ITEM_ADD_YN
                     FROM TB_BF_RT_FINAL_M_ADJ RF
                          INNER JOIN TB_DPD_ITEM_HIERACHY2 IH
                          ON RF.ITEM_CD = IH.ITEM_CD
                          INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH
                          ON RF.ACCOUNT_CD = AH.ACCOUNT_CD
                          INNER JOIN TB_SCM102S_CATE_MONTHLY CW
                          ON  CW.CATE_CD = IH.LVL04_CD
                          AND CW.LOCAT_CD = AH.LVL02_CD
                          AND CW.BASE_DATE = RF.BASE_DATE
                          AND CW.VER_CD = RF.VER_CD
                    WHERE 1=1
                        AND CW.ADJ_YN = 'Y'
                      AND RF.ADD_YN = CASE WHEN CW.QTY < CW.QTY_ADJ THEN CW.ADD_YN ELSE 'N' END
                   ) A
             UNION ALL
             /** 분배 제외 상품 **/
             SELECT RF.VER_CD
                  , IH.LVL02_CD AS LG_CATE_CD
                  , IH.LVL02_NM AS LG_CATE_NM
                  , IH.LVL03_CD AS MD_CATE_CD
                  , IH.LVL03_NM AS MD_CATE_NM
        	      , IH.LVL04_CD AS CATE_CD
                  , IH.LVL04_NM AS CATE_NM
                  , IH.ITEM_CD AS ITEM_CD
                  , IH.ITEM_NM AS ITEM_NM
                  , AH.LVL02_CD AS LOCAT_CD
                  , AH.LVL02_NM AS LOCAT_NM
                  , AH.ACCOUNT_CD
                  , AH.ACCOUNT_NM
                  , RF.BASE_DATE
                  , RF.QTY
                  , NULL AS ITEM_RT
                  , NULL AS ADJ_QTY
                  , CASE WHEN CW.QTY < CW.QTY_ADJ THEN CW.ADD_YN ELSE 'N' END AS NEW_ADD
                  , RF.ADD_YN AS ITEM_ADD_YN
                  , CW.ADJ_YN
               FROM TB_BF_RT_FINAL_M_ADJ RF
                    INNER JOIN TB_DPD_ITEM_HIERACHY2 IH
                    ON RF.ITEM_CD = IH.ITEM_CD
                    INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH
                    ON RF.ACCOUNT_CD = AH.ACCOUNT_CD
                    INNER JOIN TB_SCM102S_CATE_MONTHLY CW
                    ON  CW.CATE_CD = IH.LVL04_CD
                    AND CW.LOCAT_CD = AH.LVL02_CD
                    AND CW.BASE_DATE = RF.BASE_DATE
                    AND CW.VER_CD = RF.VER_CD
              WHERE 1=1
                AND CW.ADJ_YN = 'Y'
                AND RF.ADD_YN <> CASE WHEN CW.QTY < CW.QTY_ADJ THEN CW.ADD_YN ELSE 'N' END
            ) A
    ) SRC
    ON (   
           TAR.VER_CD = SRC.VER_CD
       AND TAR.ITEM_CD = SRC.ITEM_CD
       AND TAR.ACCOUNT_CD = SRC.ACCOUNT_CD
       AND TAR.BASE_DATE = SRC.BASE_DATE
       )
    WHEN MATCHED THEN
    UPDATE
       SET TAR.QTY_ADJ = SRC.ADJ_QTY
         , TAR.MODIFY_BY = 'SYSTEM'
         , TAR.MODIFY_DTTM = SYSDATE
    ;

    /* 보정 로그 'N' 업데이트 */
    UPDATE TB_SCM102S_CATE_MONTHLY
       SET ADJ_YN = 'N'
     WHERE 1=1
       AND ADJ_YN = 'Y'
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