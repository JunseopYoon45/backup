CREATE OR REPLACE PROCEDURE DWSCM."SP_ASDS_RP_STD_CRITERIA_Q01" (
    P_RESULT            OUT SYS_REFCURSOR
) 
/**************************************************************************
  * Name    : SP_ASDS_RP_STD_CRITERIA_Q01
  * Purpose : 표준편차 산출기준 조회
  * Notes   : 
  *           [Special Logic]
  *           [Parameters]
  * DECLARE
  *     pRESULT SYS_REFCURSOR;
  * BEGIN
  *     SP_ASDS_RP_STD_CRITERIA_Q01(pRESULT);
  *     DBMS_SQL.RETURN_RESULT(pRESULT);
  * END;
  **************************************************************************
  * History :
  * 2023-11-06 YJS Created
  **************************************************************************/
    IS

    -----------------------------
    -- Local Type Declarations --
    -----------------------------

    ---------------------------------
    -- Local Constant Declarations --
    ---------------------------------

    ---------------------------------
    -- Local Variable Declarations --
    ---------------------------------

BEGIN

OPEN P_RESULT FOR
    ---------------------------------
    -- Global Variable Declarations --
    ---------------------------------

    ---------------------------------
    -- Programming Start --
    ---------------------------------

      SELECT 'N' AS CHK_YN
      	   , T10.SRC_TP
           , CASE WHEN T10.SRC_TP = 'FR' THEN '수입'
                  WHEN T10.SRC_TP = 'KR' THEN '국내' END AS SRC_TP_NM
           , C10.COMN_CD  AS GRADE
           , T10.SEASONAL_IDX
           , C20.COMN_CD AS AGG_DIV
           , T10.AGG_PERIOD
           , T10.IS_TRUNC
           , T10.IS_ZERO
           , T10.IS_SHP
           , T10.IS_CORR
           , T10.CREATE_BY
           , T10.CREATE_DTTM
           , T10.MODIFY_BY
           , T10.MODIFY_DTTM     
        FROM TB_DS_RP_STD_CRITERIA T10
        LEFT OUTER JOIN TB_AD_COMN_CODE C10
          ON C10.SRC_ID = ( SELECT MAX(ID) FROM TB_AD_COMN_GRP WHERE GRP_CD = 'ASDS_ITEM_FCST_GD_VIEW' )
         AND T10.GRADE = C10.COMN_CD 
        LEFT OUTER JOIN TB_AD_COMN_CODE C20
          ON C20.SRC_ID = ( SELECT MAX(ID) FROM TB_AD_COMN_GRP WHERE GRP_CD = 'ASDS_SFST_STDDEV_BASE' )
         AND T10.AGG_DIV = C20.COMN_CD 
       ORDER BY 1,2
        ;

    ---------------------------------
    -- Programming End --
    ---------------------------------


END SP_ASDS_RP_STD_CRITERIA_Q01;