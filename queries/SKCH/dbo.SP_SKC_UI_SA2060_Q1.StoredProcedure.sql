USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA2060_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA2060_Q1] (
     @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA2060_Q1
-- COPYRIGHT       : AJS
-- REMARK          : S&OP 회의체 - 창고 Capacity 현황
--                    울산 창고의 현 Capacity와 향후 변화 예상되는 Capacity 정보를 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-15  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA2060_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA2060_Q1   'ko','I23670','UI_SA2060'
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID            ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID            ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

    BEGIN

        DECLARE @V_STCK_BASE_DATE NVARCHAR(10) = (SELECT CONVERT(NVARCHAR(10), MAX(BASE_DATE), 112)  FROM TB_SKC_CM_FERT_STCK_HST WITH(NOLOCK) )

        SELECT 'Total'                         AS CORP_CD
             , X.ERP_WRHS_GRP_CD               AS ERP_WRHS_GRP_CD
             , X.ERP_WRHS_GRP_NM               AS ERP_WRHS_GRP_NM
             , X.WRHS_CD                       AS ERP_WRHS_CD
             , X.WRHS_NM                       AS ERP_WRHS_NM
             , Y.CUR_CAPA                      AS CUR_CAPA
             , X.CUR_STCK_QTY / 1000           AS CUR_STCK_QTY
             , Y.CHG_CAPA                      AS CHG_CAPA
             , Y.CUR_CAPA + Y.CHG_CAPA         AS TOBE_CAPA
             , Y.REMARK                        AS REMARK
          FROM (
                  SELECT B.ERP_WRHS_GRP_CD     AS ERP_WRHS_GRP_CD
                       , B.ERP_WRHS_GRP_NM     AS ERP_WRHS_GRP_NM
                       , B.ERP_WRHS_CD         AS WRHS_CD
                       , B.ERP_WRHS_NM         AS WRHS_NM
                       , SUM(A.STCK_QTY)       AS CUR_STCK_QTY
                    FROM TB_SKC_CM_FERT_STCK_HST A WITH(NOLOCK)
                       , (  SELECT COD.COMN_CD                AS COMN_CD
                                 , COD.ATTR_01_VAL            AS WRHS_CD
                                 , COD.ATTR_02_VAL            AS ERP_WRHS_GRP_CD
                                 , COD.ATTR_03_VAL            AS ERP_WRHS_GRP_NM
                                 , COD.ATTR_04_VAL            AS ERP_WRHS_CD
                                 , COD.ATTR_05_VAL            AS ERP_WRHS_NM
                                 , COD.ATTR_06_VAL            AS CORP_CD
                                 , COD.ATTR_07_VAL            AS PLNT_CD

                              FROM TB_AD_COMN_CODE COD  WITH(NOLOCK)
                             WHERE COD.SRC_ID = (SELECT MAX(ID) FROM dbo.TB_AD_COMN_GRP  WITH(NOLOCK) WHERE GRP_CD = 'ERP_WRHS_MAP')
                         )      B
                   WHERE A.BASE_DATE   = @V_STCK_BASE_DATE
                     AND A.CORP_CD     = B.CORP_CD
                     AND A.PLNT_CD     = B.PLNT_CD
                     AND A.WRHS_CD     = B.WRHS_CD
                     AND A.CORP_CD     = '1000'
                     AND EXISTS (SELECT 1
                                   FROM TB_CM_ITEM_MST I WITH(NOLOCK)
                                  WHERE A.ITEM_CD = I.ITEM_CD
                                    AND I.ATTR_04 IN ( '11','1B')   -- 제품그룹코드 (COPOLYESTER)
                                )
                   GROUP BY
                         B.ERP_WRHS_GRP_CD
                       , B.ERP_WRHS_GRP_NM
                       , B.ERP_WRHS_CD
                       , B.ERP_WRHS_NM
               ) X

               LEFT JOIN TB_SKC_SA_WRHS_CAPA Y WITH(NOLOCK)
                 ON X.WRHS_CD     = Y.WRHS_CD

         WHERE ISNULL(X.WRHS_CD,'') != ''
         ORDER BY X.ERP_WRHS_GRP_CD
                , X.ERP_WRHS_GRP_NM
                , X.WRHS_CD
                , X.WRHS_NM

    END

GO
