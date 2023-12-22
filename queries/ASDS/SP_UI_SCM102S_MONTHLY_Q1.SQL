CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_SCM102S_MONTHLY_Q1"
(
    p_VER_CD   VARCHAR2 := ''
  , p_CATE_CD  VARCHAR2 := ''
  , p_CATE_NM  VARCHAR2 := ''
  , p_LOCAT_CD VARCHAR2 := ''
  , p_LOCAT_NM VARCHAR2 := ''
  , pRESULT OUT SYS_REFCURSOR
)

IS 
  /**************************************************************************
   * Copyrightⓒ2023 ZIONEX, All rights reserved.
   **************************************************************************
   * Name : SP_UI_SCM102S_MONTHLY_Q1
   * Purpose : 월 수요예측 결과 소분류 센터 보정 화면 조회 
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
    SELECT A.VER_CD
         , A.LG_CATE_CD
         , A.LG_CATE_NM
         , A.MD_CATE_CD
         , A.MD_CATE_NM
         , A.CATE_CD
         , A.CATE_NM
         , A.LOCAT_CD
         , A.LOCAT_NM
         , A.BASE_DATE
         , A.QTY
         , A.AMT
         , A.QTY_ADJ
         , A.CATE_PCT
         , A.ADJ_YN
      FROM (
            SELECT CW.VER_CD 
                 , LC.ITEM_LV_CD AS LG_CATE_CD
                 , LC.ITEM_LV_NM AS LG_CATE_NM
                 , MC.ITEM_LV_CD AS MD_CATE_CD
                 , MC.ITEM_LV_NM AS MD_CATE_NM
                 , SC.ITEM_LV_CD AS CATE_CD 
                 , SC.ITEM_LV_NM AS CATE_NM
                 , LT.SALES_LV_CD AS LOCAT_CD 
                 , LT.SALES_LV_NM AS LOCAT_NM
                 , CW.BASE_DATE
                 , CW.QTY 
                 , CW.AMT
                 , NVL(CW.QTY_ADJ,CW.QTY) AS QTY_ADJ
                 , CASE WHEN SUM(NVL(CW.QTY_ADJ,CW.QTY)) OVER (PARTITION BY CW.VER_CD, CW.LOCAT_CD, CW.BASE_DATE)=0 THEN 0
                        ELSE ROUND(NVL(CW.QTY_ADJ,CW.QTY) / SUM(NVL(CW.QTY_ADJ,CW.QTY)) OVER (PARTITION BY CW.VER_CD, CW.LOCAT_CD,CW.BASE_DATE) * 100,4) END AS CATE_PCT
                 , CASE WHEN CW.QTY_ADJ IS NOT NULL AND NVL(CW.QTY,0) <> NVL(CW.QTY_ADJ,0) THEN 'Y' ELSE' N' END AS ADJ_YN
              FROM TB_SCM102S_CATE_MONTHLY CW
                   INNER JOIN TB_CM_ITEM_LEVEL_MGMT SC
                   ON CW.CATE_CD = SC.ITEM_LV_CD 
                   INNER JOIN TB_CM_ITEM_LEVEL_MGMT MC
                   ON SC.PARENT_ITEM_LV_ID = MC.ID
                   INNER JOIN TB_CM_ITEM_LEVEL_MGMT LC
                   ON MC.PARENT_ITEM_LV_ID = LC.ID
                   INNER JOIN TB_DP_SALES_LEVEL_MGMT LT
                   ON CW.LOCAT_CD = LT.SALES_LV_CD 
             WHERE 1=1
               AND CW.VER_CD = p_VER_CD
               AND CW.BASE_DATE <= LIMIT_DATE
           ) A
     WHERE 1=1
       AND 1 = CASE WHEN NVL(p_CATE_CD,'ALL') = 'ALL'  THEN 1
                    WHEN A.CATE_CD LIKE p_CATE_CD ||'%'  THEN 1
                    ELSE 0 END 
       AND 1 = CASE WHEN NVL(p_LOCAT_CD,'ALL') = 'ALL' THEN 1
                    WHEN p_LOCAT_CD = A.LOCAT_CD THEN 1
                    ELSE 0 END  
       AND ( REGEXP_LIKE (UPPER(A.CATE_NM), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_CATE_NM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
             OR  p_CATE_NM IS NULL
           )
       AND ( REGEXP_LIKE (UPPER(A.LOCAT_NM), REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_LOCAT_NM), ')', '\)'), '(', '\('), ']', '\]'), '[', '\[')) 
             OR  p_LOCAT_NM IS NULL
           ) 
     ORDER BY 1,2,4,6,8,10
    ;
END;