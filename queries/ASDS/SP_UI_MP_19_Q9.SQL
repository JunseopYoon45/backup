CREATE OR REPLACE PROCEDURE DWSCM.SP_UI_MP_19_Q9 (
    P_DEMAND_VER_ID IN VARCHAR2 := ''
    ,pResult OUT SYS_REFCURSOR
)
IS
    P_DMD_ID_PREFIX VARCHAR2(100) :='DMND_';
    P_NEW_DMD_ID VARCHAR2(100) :='';

BEGIN 

    SELECT P_DMD_ID_PREFIX ||LPAD(REPLACE(MAX(DMND_ID), 'DMND_', '') + 1, 15, '0')
      INTO P_NEW_DMD_ID
   	  FROM TB_CM_DEMAND_OVERVIEW 
   	 WHERE T3SERIES_VER_ID = P_DEMAND_VER_ID;
   	
--    SELECT P_DMD_ID_PREFIX || LPAD(CAST(NVL(MAX(CAST(REPLACE(X.DMND_ID,P_DMD_ID_PREFIX,'') AS INT)) ,0) + 1 AS VARCHAR2(100)),15,'0')
--    INTO P_NEW_DMD_ID
--      FROM TB_CM_DEMAND_OVERVIEW X
--     WHERE 1=1
--       AND X.MODULE_VAL = 'DP' 
--       AND X.T3SERIES_VER_ID = P_DEMAND_VER_ID
--       AND EXISTS (
--                   SELECT  1
--                     FROM TB_AD_COMN_GRP A
--                          INNER JOIN 
--                       TB_AD_COMN_CODE B
--                    ON (A.ID = B.SRC_ID)
--                    WHERE 1=1
--                      AND A.GRP_CD = 'DEMAND_TYPE'
--                      AND B.COMN_CD= 'DMND_TYPE_07' --BOM Requirement
--                      AND X.DMND_TP_ID <> B.ID
--                  );

  OPEN pResult FOR
  SELECT TO_SINGLE_BYTE(SYS_GUID()) AS NEW_ID
        ,P_NEW_DMD_ID               AS DEMAND_ID
  FROM DUAL;

END;