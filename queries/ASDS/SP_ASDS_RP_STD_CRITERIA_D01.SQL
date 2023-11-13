CREATE OR REPLACE PROCEDURE DWSCM."SP_ASDS_RP_STD_CRITERIA_D01" (
    P_SRC_TP              IN  VARCHAR2 := NULL /*국내/수입*/
   ,P_GRADE               IN  VARCHAR2 := NULL /*구분(등급)*/
   ,P_USER_ID             IN  VARCHAR2 := NULL
   ,P_VIEW_ID             IN  VARCHAR2 := NULL 
   ,P_RT_ROLLBACK_FLAG    OUT VARCHAR2
   ,P_RT_MSG              OUT VARCHAR2
/**************************************************************************
  * Name    : SP_ASDS_RP_STD_CRITERIA_D01
  * Purpose : 표준편차 산출기준 삭제
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

BEGIN
    ---------------------------------
    -- Global Variable Declarations --
    ---------------------------------
    
    IF NVL(P_SRC_TP,'') = '' OR NVL(P_GRADE, '') = '' THEN
        P_ERR_MSG := 'Key 값이 존재하지 않습니다.';
        RAISE PK_ERROR;
    END IF;

    ---------------------------------
    -- Programming Start --
    ---------------------------------
    
    DELETE 
    FROM  TB_DS_RP_STD_CRITERIA     
    WHERE SRC_TP = P_SRC_TP
      AND GRADE = P_GRADE
    ;

    ---------------------------------
    -- Programming End --
    ---------------------------------
    P_RT_ROLLBACK_FLAG  := 'true';
    P_RT_MSG            := 'MSG_0001';  --저장 되었습니다.
    

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