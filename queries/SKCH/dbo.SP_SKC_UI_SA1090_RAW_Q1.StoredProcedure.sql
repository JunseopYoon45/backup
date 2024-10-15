USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1090_RAW_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1090_RAW_Q1] (
     @P_FR_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (From)
   , @P_TO_YYYYMM             NVARCHAR(100)   = NULL    -- 기준년월 (To)
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1090_RAW_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 비정상 재고  상세
--                   비정상 재고 수량을 상세 lv로 조회할 수 있는 화면
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-06-20  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1090_RAW_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1090_RAW_Q1  '202404','202409', 'ko','I23779',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_FR_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_TO_YYYYMM       ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID         ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID         ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    -----------------------------------
    -- 임시 테이블
    -----------------------------------

    BEGIN
        IF OBJECT_ID('TM_SA1090') IS NOT NULL DROP TABLE TM_SA1090 -- 임시테이블 삭제

          CREATE TABLE TM_SA1090
          (
            YYYYMM                NVARCHAR(100)
          , BRAND                 NVARCHAR(100)
          , TOT_STCK_QTY          DECIMAL(18,0)
          , ON_SPEC_STCK_QTY      DECIMAL(18,0)
          , OFF_SPEC_STCK_QTY     DECIMAL(18,0)
          , LOGIN_ID              NVARCHAR(50) 
          )
    END


    -----------------------------------
    -- 조회
    -----------------------------------

		INSERT INTO TM_SA1090
		SELECT A.YYYYMM                                                            AS YYYYMM
             , A.BRAND                                                             AS BRAND
             , ISNULL(B.TOT_STCK_QTY, 0) AS TOT_STCK_QTY       -- 총재고수량
			 , ISNULL(B.ON_SPEC_STCK_QTY, 0) AS ON_SPEC_STCK_QTY
			 , ISNULL(B.OFF_SPEC_STCK_QTY, 0) AS OFF_SPEC_STCK_QTY
			 , @P_USER_ID
		  FROM (SELECT DISTINCT ATTR_07 AS BRAND, YYYYMM
				  FROM TB_CM_ITEM_MST A
				 CROSS JOIN (SELECT DISTINCT YYYYMM FROM TB_CM_CALENDAR WHERE YYYYMM BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM) B
				 WHERE ATTR_04 IN ('11', '1B')) A -- 2024.10.14 재고 I/F 가 되지 않은 BRAND의 경우 화면에서 표시되지 않는 오류 조치
          LEFT JOIN (
		    SELECT YYYYMM
				 , I.BRAND
				 , SUM(ISNULL(X.STCK_QTY    , 0)) / 1000                               AS TOT_STCK_QTY       -- 총재고수량
				 , SUM(CASE WHEN I.MDM_NRML_TYPE_CD = '01' THEN STCK_QTY END) / 1000   AS ON_SPEC_STCK_QTY   -- 정상재고
				 , SUM(CASE WHEN I.MDM_NRML_TYPE_CD = '02' THEN STCK_QTY END) / 1000   AS OFF_SPEC_STCK_QTY  -- 비정상재고
		      FROM (
                  SELECT CONVERT(NVARCHAR(6), IF_STD_DATE, 112)              AS YYYYMM
                       , PLNT_CD                                             AS PLNT_CD
                       , ITEM_CD                                             AS ITEM_CD
                       , STCK_QTY                                            AS STCK_QTY     -- 재고수량
                       , STCK_PRICE                                          AS STCK_PRICE   -- 재고금액
                    FROM TB_SKC_CM_FERT_EOH_HST WITH(NOLOCK)
                   WHERE 1=1
                     AND CONVERT(NVARCHAR(6), IF_STD_DATE, 112)  BETWEEN @P_FR_YYYYMM AND @P_TO_YYYYMM
                     AND PLNT_CD IN ('1110', '1230')
               ) X

               INNER MERGE JOIN
                    (  SELECT A.ITEM_CD                                                                             AS ITEM_CD
                            , CASE WHEN 'ko' = 'en' THEN A.ITEM_NM_EN ELSE ITEM_NM END                        AS ITEM_NM
                            , CASE WHEN 'ko' = 'en' THEN B.MDM_NRML_TYPE_NM_EN ELSE B.MDM_NRML_TYPE_NM END    AS MDM_NRML_TYPE_NM
                            , MDM_NRML_TYPE_CD                                                                      AS MDM_NRML_TYPE_CD
                            , A.ATTR_07                                                                             AS BRAND
                            , A.ATTR_14                                                                             AS NRML_TYPE_CD
                            , A.ATTR_15                                                                             AS NRML_TYPE_NM
                            , A.ATTR_04                                                                             AS ITEM_GRP_CD
                         FROM TB_CM_ITEM_MST A WITH(NOLOCK)
                            , (  SELECT COD.COMN_CD           AS COMN_CD
                                      , COD.ATTR_01_VAL       AS MDM_NRML_TYPE_CD
                                      , COD.ATTR_02_VAL       AS MDM_NRML_TYPE_NM
                                      , COD.ATTR_03_VAL       AS MDM_NRML_TYPE_NM_EN
                                   FROM TB_AD_COMN_CODE COD WITH(NOLOCK)
                                  WHERE COD.SRC_ID = (SELECT MAX(ID) FROM dbo.TB_AD_COMN_GRP WITH(NOLOCK) WHERE GRP_CD = 'NRML_TYPE_MDM')
                              ) B
                        WHERE A.ATTR_14  = B.COMN_CD              -- NRML_TYPE_CD
                          AND A.ATTR_04 IN ( '11', '1B')          -- ITEM_GRP_CD :제품그룹코드 (COPOLYESTER)
                    )  I

                 ON X.ITEM_CD = I.ITEM_CD

         GROUP BY X.YYYYMM
                , I.BRAND
				) B
		ON A.YYYYMM = B.YYYYMM
		AND A.BRAND = B.BRAND


END

GO
