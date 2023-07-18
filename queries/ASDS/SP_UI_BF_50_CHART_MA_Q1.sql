CREATE OR REPLACE PROCEDURE DWSCM."SP_UI_BF_50_CHART_MA_Q1" 
(
    p_VER_CD        VARCHAR2,
    p_ITEM       	VARCHAR2,
    p_FROM_DATE     DATE,
    p_TO_DATE       DATE,
    pRESULT         OUT SYS_REFCURSOR  
)
IS 

    p_TARGET_FROM_DATE  DATE := NULL;
    v_TO_DATE           DATE := NULL;
    v_BUKT              VARCHAR2(5);

BEGIN
    SELECT MAX(TARGET_FROM_DATE)
         , MAX(TARGET_BUKT_CD)
           INTO
           p_TARGET_FROM_DATE
         , v_BUKT
      FROM DWSCMDEV.TB_BF_CONTROL_BOARD_VER_DTL
     WHERE VER_CD = p_VER_CD
       AND ENGINE_TP_CD IS NOT NULL
    ;

    v_TO_DATE := p_TO_DATE;

    OPEN pRESULT FOR
    WITH RT AS (
        SELECT ITEM_CD
             , BASE_DATE 
             , CASE WHEN ENGINE_TP_CD LIKE 'ZAUTO%' THEN 'ZAUTO' ELSE ENGINE_TP_CD end ENGINE_TP_CD
             , COALESCE(QTY,0)	AS QTY
          FROM TB_BF_RT_MA
         WHERE BASE_DATE BETWEEN p_FROM_DATE and v_TO_DATE
           AND VER_CD = p_VER_CD
           AND ITEM_CD = p_ITEM
    )
    , CALENDAR AS (
        SELECT DAT 
             , YYYY
             , YYYYMM
             , YYYYMM AS BUKT	
          FROM TB_CM_CALENDAR CA
         WHERE DAT BETWEEN p_FROM_DATE AND v_TO_DATE     
    )
    , CA AS (
        SELECT MIN(DAT)	 			AS STRT_DATE
             , BUKT	
             , MAX(LAST_DAY(DAT))	AS END_DATE
          FROM CALENDAR CA
         WHERE TRUNC(DAT, 'MONTH') BETWEEN p_FROM_DATE AND v_TO_DATE 
         GROUP BY BUKT 
    )
    , SA AS (
        SELECT IH.LVL04_CD 	AS ITEM_CD
             , CA.STRT_DATE
             , CA.BUKT 
             , SUM(AMT)		AS QTY 
          FROM TB_CM_ACTUAL_SALES S
         INNER JOIN CA ON S.BASE_DATE BETWEEN CA.STRT_DATE AND CA.END_DATE
         INNER JOIN TB_CM_ITEM_MST IM ON S.ITEM_MST_ID = IM.ID AND COALESCE(IM.DEL_YN,'N') = 'N'           
         INNER JOIN TB_DPD_ITEM_HIERACHY2 IH ON IM.ITEM_CD = IH.LVL05_CD
         WHERE 1=1 AND IH.LVL04_CD = p_ITEM
         GROUP BY IH.LVL04_CD, CA.BUKT, CA.STRT_DATE
    )
    , N AS (
        SELECT RT.ITEM_CD		AS ITEM_CD
             , CA.BUKT
             , RT.ENGINE_TP_CD
             , SUM(RT.QTY)		AS QTY 			 
          FROM RT 
         INNER JOIN CA ON RT.BASE_DATE BETWEEN CA.STRT_DATE AND END_DATE
    	 GROUP BY ITEM_CD, CA.BUKT, ENGINE_TP_CD 
         UNION
        SELECT SA.ITEM_CD
             , BUKT
             , 'Z_ACT_SALES'	AS ENGINE_TP_CD
             , SA.QTY 
          FROM SA
    )
    , M AS (
        SELECT ITEM_CD
             , ENGINE_TP_CD
             , STRT_DATE
             , END_DATE
             , BUKT
             , CASE WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE >= p_TARGET_FROM_DATE THEN 'ORANGE' 
                    WHEN ENGINE_TP_CD ='Z_ACT_SALES' AND STRT_DATE < p_TARGET_FROM_DATE THEN 'GREY'
                    ELSE NULL 
               END AS COLOR
          FROM CA 
         CROSS JOIN
               ( SELECT ITEM_CD, ENGINE_TP_CD
                   FROM N  
                  GROUP BY ITEM_CD, ENGINE_TP_CD
               ) RT
    )
    SELECT M.ITEM_CD
         , M.ENGINE_TP_CD
         , M.BUKT
         , N.QTY	 
         , M.COLOR 
      FROM M
      LEFT JOIN N ON M.ITEM_CD = N.ITEM_CD AND M.BUKT = N.BUKT AND M.ENGINE_TP_CD = N.ENGINE_TP_CD
     ORDER BY M.ENGINE_TP_CD, M.STRT_DATE
    ;
END;