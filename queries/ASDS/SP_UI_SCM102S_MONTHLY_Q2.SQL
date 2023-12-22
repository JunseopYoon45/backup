CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_SCM102S_MONTHLY_Q2"
(
    p_VER_CD   VARCHAR2 := ''
  , p_CATE_CD  VARCHAR2 := ''
  , p_CATE_NM  VARCHAR2 := ''
  , p_LOCAT_CD VARCHAR2 := ''
  , p_LOCAT_NM VARCHAR2 := ''
  , p_BASE_DATE VARCHAR2 := ''
  , pRESULT OUT SYS_REFCURSOR
)

IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_SCM102S_MONTHLY_Q2
   * Purpose : 월 수요예측 결과 상품 센터 보정 화면 조회 
   * Notes :
   **************************************************************************/

LIMIT_DATE DATE;

BEGIN
	SELECT ADD_MONTHS(TARGET_FROM_DATE, 4)
      INTO LIMIT_DATE
      FROM TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND PROCESS_NO = 10000
    ;
   
    OPEN pRESULT
    FOR
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
         , RF.QTY AS FRCT_QTY
         , RF.AMT AS FRCT_AMT
         , NVL(RF.QTY_ADJ,RF.QTY) AS ADJ_QTY
         , NVL(RF.QTY_ADJ,RF.QTY) AS FINAL_QTY
         , RF.ADD_YN AS ITEM_ADD_YN
		 , CASE WHEN CW.QTY_ADJ IS NOT NULL AND NVL(CW.QTY,0) <> NVL(CW.QTY_ADJ,0) THEN 'Y' ELSE' N' END AS ADJ_YN
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
       AND RF.VER_CD = p_VER_CD
       AND RF.BASE_DATE = TO_DATE(p_BASE_DATE)
       AND 1 = CASE WHEN NVL(p_CATE_CD,'ALL') = 'ALL'  THEN 1
                    WHEN p_CATE_CD = IH.LVL04_CD THEN 1
                    ELSE 0 END 
       AND 1 = CASE WHEN NVL(p_LOCAT_CD,'ALL') = 'ALL' THEN 1
                    WHEN p_LOCAT_CD = AH.LVL02_CD THEN 1
                    ELSE 0 END  
       AND ( REGEXP_LIKE (UPPER(IH.LVL04_NM), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_CATE_NM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
             OR  p_CATE_NM IS NULL
           )
       AND ( REGEXP_LIKE (UPPER(AH.LVL02_NM), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_LOCAT_NM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
             OR  p_LOCAT_NM IS NULL
           )
       AND RF.BASE_DATE <= LIMIT_DATE
	 ORDER BY CATE_CD, LOCAT_CD,ITEM_ADD_YN, ITEM_CD, ACCOUNT_CD,BASE_DATE
	;
END;