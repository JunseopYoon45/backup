CREATE OR REPLACE PROCEDURE DWSCM.SP_UI_SCM102S_MONTHLY_CNF (
    P_VER_CD            IN VARCHAR2,
    P_USER_ID           IN VARCHAR2,
    P_RT_ROLLBACK_FLAG  OUT VARCHAR2,
    P_RT_MSG            OUT VARCHAR2
)
/**************************************************************************
* Name    : SP_UI_SCM102S_MONTHLY_CNF
* Purpose : 수요예측 보정 결과를 보충계획 수요량으로 이관
* Notes   : TB_SCM102S_CATE_MONTHLY 테이블 ADJ_YN = 'S' 인 소분류,센터,주차 데이터 대상 (보정 후 보충 계획 전송 전 상태)
*           TB_BF_RT_FINAL_M_ADJ 데이터를 TB_CM_DEMAND_OVERVIEW 로 이관
* 
* TB_SCM102S_CATE_MONTHLY 테이블 ADJ_YN 컬럼 - 보정 상태
* ** N : 보정 전
* ** Y : 보정 후
* ** S : SKU 분배
* ** C : 확정 : 보충계획 전송
			
**************************************************************************
* History 
* 2023-12-15 ZIONEX 
******************************************************************************
[실행]
  VAR P_RT_ROLLBACK_FLAG VARCHAR2(1000)
  VAR P_RT_MSG VARCHAR2(1000)
 EXEC SP_UI_SCM102S_MONTHLY_CNF ('BF-20230824-03',:P_RT_ROLLBACK_FLAG, :P_RT_MSG)
PRINT P_RT_ROLLBACK_FLAG
PRINT P_RT_MSG

*****************************************************************************/
IS
    P_ERR_MSG           VARCHAR2(4000) := '';
    V_MODULE_ID VARCHAR2(100);
    V_MAX_DMND INT := 0;
    V_FROM_DATE DATE;
    V_TO_DATE DATE;
    V_SND_DATE DATE;
    V_MST_ID VARCHAR2(32) := TO_SINGLE_BYTE(SYS_GUID());

BEGIN
    SELECT ID INTO V_MODULE_ID
      FROM TB_CM_COMM_CONFIG
     WHERE CONF_CD = 'DP'
       AND CONF_GRP_CD = 'DP_WK_TP'
    ;

	SELECT CAST(SUBSTR(MAX(DMND_ID),-15) AS INT) INTO V_MAX_DMND
	  FROM TB_CM_DEMAND_OVERVIEW DO
	 WHERE 1=1
	   AND DO.T3SERIES_VER_ID = P_VER_CD
	;   
   
    /*Demand Overview 데이터 Merge - 보충 계획 수요량 데이터*/
    MERGE INTO TB_CM_DEMAND_OVERVIEW TAR 
    USING (
    WITH IA AS (
    SELECT BRF.ITEM_CD
         , BRF.ACCOUNT_CD
      FROM TB_BF_RT_FINAL_M_ADJ BRF
           INNER JOIN TB_DPD_ITEM_HIERACHY2 IH 
           ON BRF.ITEM_CD = IH.ITEM_CD 
           INNER JOIN TB_DPD_ACCOUNT_HIERACHY2 AH 
           ON BRF.ACCOUNT_CD = AH.ACCOUNT_CD 
           INNER JOIN TB_SCM102S_CATE_MONTHLY CW 
           ON CW.VER_CD = BRF.VER_CD 
           AND CW.CATE_CD = IH.LVL04_CD 
           AND CW.LOCAT_CD = AH.LVL02_CD
     WHERE 1=1
       AND BRF.VER_CD = P_VER_CD
       AND CW.ADJ_YN = 'S'
     GROUP BY BRF.ITEM_CD, BRF.ACCOUNT_CD
    )
    SELECT 'DP'                                                                     AS MODULE_VAL
         , P_VER_CD                                                                 AS T3SERIES_VER_ID
         , 'Y'                                                                      AS CONFRM_YN
         , 'Y'                                                                      AS FINAL_CONFRM_YN
         , 'DMND_' || LPAD(ROW_NUMBER() OVER (ORDER BY DE.ITEM_CD,DE.ACCOUNT_CD,DE.BASE_DATE)+V_MAX_DMND,15,'0') AS DMND_ID
         , '4A75B460404C407E8C2B18A92167686E'                                       AS DMND_TP_ID
         , (SELECT B.ID 
              FROM TB_AD_COMN_GRP A
                  ,TB_AD_COMN_CODE B
             WHERE 1=1
               AND A.ID = B.SRC_ID
               AND A.GRP_CD = 'DEMAND_CLASS'
               AND COMN_CD = 'NEW')                                                 AS DMND_CLASS_ID
         , IT.ITEM_ID                                                               AS ITEM_MST_ID
         , NVL(QTY_ADJ, QTY)                                                        AS DMND_QTY
         , UM.ID                                                                    AS UOM_ID
         , BASE_DATE                                                                AS DUE_DATE
         , LD.ID                                                                    AS REQUEST_SITE_ID
         , ACCOUNT_ID                                                               AS ACCOUNT_ID
         , IT.ATTR_01                                                               AS SALES_UNIT_PRIC
         , AC.CURCY_ID                                                              AS CURCY_CD_ID
         , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'CM_BASE_ORD_DELIV_POLICY'
               AND DEFAT_VAL = 'Y'           
           )                                                                        AS DELIVY_PLAN_POLICY_CD_ID
         , (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_GRP_CD = 'MP_ORD_CAPA_MAT_COST'
               AND DEFAT_VAL = 'Y')                                                 AS MAT_CONST_CD_ID
         , (SELECT CONF_CD  FROM TB_CM_COMM_CONFIG
             WHERE CONF_GRP_CD = 'MP_BASE_EFFCIENCY')                               AS EFFICY
         , (SELECT CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end FROM TB_CM_COMM_CONFIG
             WHERE CONF_GRP_CD = 'MP_ORD_PARTIAL_PLN')                              AS PARTIAL_PLAN_YN
         , (SELECT (CASE WHEN CONF_CD = 'TRUE' then 'Y' else 'N'  end) FROM TB_CM_COMM_CONFIG
             WHERE CONF_GRP_CD = 'CM_ORD_ROUT_COST_OPT')                            AS COST_OPTIMIZ_YN
         , ( SELECT CASE B.UOM_CD
                         WHEN 'DAY'   THEN BASE_DATE+CAST(A.CATAGY_VAL AS NUMERIC)
                         WHEN 'WEEK'  THEN BASE_DATE+CAST(A.CATAGY_VAL AS NUMERIC)*7
                         WHEN 'MONTH' THEN ADD_MONTHS(BASE_DATE, CAST(A.CATAGY_VAL AS NUMERIC))
                         WHEN 'YEAR'  THEN ADD_MONTHS(BASE_DATE, CAST(A.CATAGY_VAL AS NUMERIC)*12)
                    END          
              FROM TB_CM_BASE_ORDER A
                   INNER JOIN
                   TB_CM_UOM B
                ON A.CATAGY_CD = 'BASE_ORDER_DUE_DATE_FENCE'
               AND A.UOM_ID = B.ID AND  A.ACTV_YN = 'Y' )                           AS DUE_DATE_FNC
         , 'Y'                                                                      AS ACTV_YN
         , 'BFM'                                                                    AS CREATE_BY
         , SYSDATE                                                                  AS CREATE_DTTM
      FROM TB_BF_RT_FINAL_M_ADJ DE
      	   INNER JOIN IA
      	ON DE.ITEM_CD = IA.ITEM_CD
      	AND DE.ACCOUNT_CD = IA.ACCOUNT_CD
           INNER JOIN
           TB_DPD_ITEM_HIERACHY2 IT 
        ON DE.ITEM_CD = IT.ITEM_CD
        AND IT.LV_TP_CD = 'I'
        AND IT.USE_YN = 'Y'
           INNER JOIN 
           TB_CM_UOM UM
        ON IT.UOM = UM.UOM_CD 
       AND UM.ACTV_YN = 'Y'                         
           INNER JOIN
           TB_DPD_ACCOUNT_HIERACHY2 AC
        ON AC.ACCOUNT_CD = DE.ACCOUNT_CD
           INNER JOIN
           TB_CM_LOC_DTL LD 
        ON LD.LOCAT_CD = CASE WHEN AC.ACCOUNT_CD LIKE '%POS' THEN '0'||AC.LVL02_CD ELSE AC.LVL02_CD END
     WHERE 1=1 
       AND QTY > 0
       AND DE.VER_CD = p_VER_CD
    ) SRC
    ON (
           TAR.T3SERIES_VER_ID = SRC.T3SERIES_VER_ID
       AND TAR.DMND_TP_ID      = SRC.DMND_TP_ID
       AND TAR.ITEM_MST_ID     = SRC.ITEM_MST_ID
       AND TAR.ACCOUNT_ID      = SRC.ACCOUNT_ID
       AND TAR.DUE_DATE        = SRC.DUE_DATE
       )
    WHEN MATCHED THEN 
    UPDATE
       SET TAR.DMND_QTY = SRC.DMND_QTY
         , TAR.MODIFY_BY = P_USER_ID
         , TAR.MODIFY_DTTM = SYSDATE
    WHEN NOT MATCHED THEN 
    INSERT (
      ID
    , MODULE_VAL
    , T3SERIES_VER_ID
    , CONFRM_YN
    , FINAL_CONFRM_YN
    , DMND_ID
    , DMND_TP_ID
    , DMND_CLASS_ID
    , ITEM_MST_ID
    , DMND_QTY
    , UOM_ID
    , DUE_DATE
    , REQUEST_SITE_ID
    , ACCOUNT_ID
    , SALES_UNIT_PRIC
    , CURCY_CD_ID
    , DELIVY_PLAN_POLICY_CD_ID
    , MAT_CONST_CD_ID
    , EFFICY
    , PARTIAL_PLAN_YN
    , COST_OPTIMIZ_YN
    , DUE_DATE_FNC
    , ACTV_YN
    , CREATE_BY
    , CREATE_DTTM
    )
    VALUES (
      TO_SINGLE_BYTE(SYS_GUID())
    , SRC.MODULE_VAL
    , SRC.T3SERIES_VER_ID
    , SRC.CONFRM_YN
    , SRC.FINAL_CONFRM_YN
    , SRC.DMND_ID
    , SRC.DMND_TP_ID
    , SRC.DMND_CLASS_ID
    , SRC.ITEM_MST_ID
    , SRC.DMND_QTY
    , SRC.UOM_ID
    , SRC.DUE_DATE
    , SRC.REQUEST_SITE_ID
    , SRC.ACCOUNT_ID
    , SRC.SALES_UNIT_PRIC
    , SRC.CURCY_CD_ID
    , SRC.DELIVY_PLAN_POLICY_CD_ID
    , SRC.MAT_CONST_CD_ID
    , SRC.EFFICY
    , SRC.PARTIAL_PLAN_YN
    , SRC.COST_OPTIMIZ_YN
    , SRC.DUE_DATE_FNC
    , SRC.ACTV_YN
    , P_USER_ID
    , SYSDATE
    )    
    ;
  
    /* 보정 상태 'C' (확정 상태) 업데이트 */
    UPDATE TB_SCM102S_CATE_MONTHLY
       SET ADJ_YN = 'C'
     WHERE 1=1
       AND ADJ_YN = 'S'
    ;
   
    COMMIT;    
    P_RT_ROLLBACK_FLAG := 'true';
    P_RT_MSG := 'MSG_0003';

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        P_RT_ROLLBACK_FLAG := 'false';
        IF ( SQLCODE = -20012 ) THEN
            P_RT_MSG := P_ERR_MSG;
        ELSE
            P_RT_MSG := SQLERRM;
        END IF;

END;