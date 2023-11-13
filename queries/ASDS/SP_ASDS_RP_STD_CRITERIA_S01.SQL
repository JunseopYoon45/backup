CREATE OR REPLACE PROCEDURE DWSCM."SP_ASDS_RP_STD_CRITERIA_S01" (
    P_SRC_TP              IN  TB_DS_RP_STD_CRITERIA.SRC_TP%TYPE := NULL       /*국내/수입*/ 
   ,P_GRADE               IN  TB_DS_RP_STD_CRITERIA.GRADE%TYPE := NULL        /*구분(등급)*/
   ,P_SEASONAL_IDX        IN  TB_DS_RP_STD_CRITERIA.SEASONAL_IDX%TYPE := NULL /*시즌지수(>)*/
   ,P_AGG_DIV             IN  TB_DS_RP_STD_CRITERIA.AGG_DIV%TYPE := NULL      /*집계구분*/
   ,P_AGG_PERIOD          IN  TB_DS_RP_STD_CRITERIA.AGG_PERIOD%TYPE := NULL   /*집계구간(WEEK)*/
   ,P_TRUNC               IN  TB_DS_RP_STD_CRITERIA.IS_TRUNC%TYPE := NULL     /*Min/Max 제외여부*/
   ,P_ZERO                IN  TB_DS_RP_STD_CRITERIA.IS_ZERO%TYPE := NULL      /*0값 제외여부*/
   ,P_USER_ID             IN  VARCHAR2 := NULL
   ,P_VIEW_ID             IN  VARCHAR2 := NULL  
   ,P_RT_ROLLBACK_FLAG    OUT VARCHAR2
   ,P_RT_MSG              OUT VARCHAR2
/**************************************************************************
  * Name    : SP_ASDS_RP_STD_CRITERIA_S01
  * Purpose : 표준편차 산출기준 저장
  * Notes   : 
  * [Special Logic]
  * [Parameters]
  **************************************************************************
  * History :
  * 2023-11-06 YJS Created
  **************************************************************************/
) IS

    -----------------------------
    -- Local Type Declarations --
    -----------------------------
    PK_ERROR        EXCEPTION;
    P_ERR_STATUS    NUMBER :=0;
    P_ERR_MSG       VARCHAR2(4000) :='';
    ---------------------------------
    -- Local Constant Declarations --
    ---------------------------------

    ---------------------------------
    -- Local Variable Declarations --
    ---------------------------------
    P_USER_NM       VARCHAR2(100);

BEGIN
    ---------------------------------
    -- Global Variable Declarations --
    ---------------------------------
    SELECT NMKOR INTO P_USER_NM 
      FROM ADDWCDC.HR220M 
     WHERE EMPNO = P_USER_ID;
    ---------------------------------
    -- Programming Start --
    ---------------------------------

    MERGE INTO TB_DS_RP_STD_CRITERIA TAR
        USING  (  
                SELECT P_SRC_TP       AS SRC_TP  
                     , P_GRADE        AS GRADE
                     , P_SEASONAL_IDX AS SEASONAL_IDX 
                     , P_AGG_DIV      AS AGG_DIV 
                     , P_AGG_PERIOD   AS AGG_PERIOD
                     , P_TRUNC        AS IS_TRUNC
                     , P_ZERO         AS IS_ZERO 
                     , P_USER_NM      AS CREATE_BY
                     , SYSDATE        AS CREATE_DTTM
                     , P_USER_NM      AS MODIFY_BY
                     , SYSDATE        AS MODIFY_DTTM
                FROM DUAL
               ) SRC
           ON
            (    TAR.SRC_TP = SRC.SRC_TP
             AND TAR.GRADE  = SRC.GRADE
            )
         WHEN  MATCHED THEN
       UPDATE  
          SET  TAR.SEASONAL_IDX = SRC.SEASONAL_IDX
             , TAR.AGG_DIV      = SRC.AGG_DIV 
             , TAR.AGG_PERIOD   = SRC.AGG_PERIOD
             , TAR.IS_TRUNC     = SRC.IS_TRUNC
             , TAR.IS_ZERO      = SRC.IS_ZERO
             , TAR.MODIFY_BY    = SRC.MODIFY_BY
             , TAR.MODIFY_DTTM  = SRC.MODIFY_DTTM
         WHEN NOT MATCHED THEN
       INSERT (  TAR.SRC_TP   
               , TAR.GRADE
               , TAR.SEASONAL_IDX 
               , TAR.AGG_DIV 
               , TAR.AGG_PERIOD
               , TAR.IS_TRUNC
               , TAR.IS_ZERO 
               , TAR.IS_SHP
               , TAR.IS_CORR
               , TAR.CREATE_BY
               , TAR.CREATE_DTTM
             )
       VALUES (                
                 SRC.SRC_TP
               , SRC.GRADE 
               , SRC.SEASONAL_IDX 
               , SRC.AGG_DIV
               , SRC.AGG_PERIOD
               , SRC.IS_TRUNC 
               , SRC.IS_ZERO
               , 'Y'
               , 'Y'
               , SRC.CREATE_BY
               , SRC.CREATE_DTTM
             )
            ;

    ---------------------------------
    -- Programming End --
    ---------------------------------
    P_RT_ROLLBACK_FLAG  := 'true';
    P_RT_MSG            := 'MSG_0001';  --저장 되었습니다.
    
    COMMIT;


EXCEPTION 
    WHEN PK_ERROR THEN
        ROLLBACK;
--        RAISE_APPLICATION_ERROR(-20012, P_ERR_MSG);
        P_RT_ROLLBACK_FLAG := 'false';
        P_RT_MSG := P_ERR_MSG;


    WHEN OTHERS THEN
    IF (SQLCODE = -20001) THEN
        ROLLBACK;
        P_RT_ROLLBACK_FLAG := 'false';
        P_RT_MSG := P_ERR_MSG;

    ELSE
        RAISE;
--              EXEC SP_COMM_RAISE_ERR
    END IF;
END;