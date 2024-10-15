USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_SA1150_Q1]    Script Date: 2024-10-15 오후 2:16:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_SA1150_Q1] (
     @P_BASE_YYYY             NVARCHAR(100)   = NULL    -- 기준년도
   , @P_LANG_CD               NVARCHAR(100)   = NULL    -- LANG_CD (ko, en)
   , @P_USER_ID               NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID               NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_SA1150_Q1
-- COPYRIGHT       : AJS
-- REMARK          : 임가공 생산목표 比 실적
--                    모아, KS Tech 등 주요 임가공처에 대한 월 생산목표 대비 실적을 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2023-09-02  AJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHIGNORE ON
SET ARITHABORT OFF;


---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_SA1150_Q1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_SA1150_Q1 '2024','ko','I23779','UI_SA1140'

*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_BASE_YYYY                 ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID                   ), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID                   ), '')
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'SA',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;


---------- LOG END ----------

BEGIN

    DECLARE @V_TO_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), EOMONTH(DATEADD(MONTH, 0, @P_BASE_YYYY + '0101')) , 112)
    DECLARE @V_FR_YYYYMM NVARCHAR(6) = CONVERT(NVARCHAR(6), EOMONTH(DATEADD(MONTH, 0, @P_BASE_YYYY + '1231')) , 112)



    -----------------------------------
    -- MEASURE
    -----------------------------------
    IF OBJECT_ID('tempdb..#TM_MEASURE') IS NOT NULL DROP TABLE #TM_MEASURE -- 임시테이블 삭제
        SELECT COMN_CD          AS MEASURE_CD
             , COMN_CD_NM       AS MEASURE_NM
             , SEQ              AS SEQ
          INTO #TM_MEASURE
          FROM FN_COMN_CODE('SA1150','')


    --------------------------
    -- 생산목표량
    -- MP Verseion 확인
    --------------------------
    IF OBJECT_ID('tempdb..#TM_MP_VERSION') IS NOT NULL DROP TABLE #TM_MP_VERSION -- 임시테이블 삭제

        SELECT YYYYMM
             , CASE WHEN ISNULL(MP_VERSION_ID, '') = '' AND C.YYYYMM < Y.VER_YYYYMM THEN  Y.MIN_MP_VERSION_ID
                    WHEN ISNULL(MP_VERSION_ID, '') = '' AND C.YYYYMM > Z.VER_YYYYMM THEN  Z.MAX_MP_VERSION_ID
                    ELSE MP_VERSION_ID
                END                                                AS MP_VERSION_ID
          INTO #TM_MP_VERSION
          FROM (  SELECT DISTINCT YYYYMM
                    FROM TB_CM_CALENDAR
                   WHERE YYYY = @P_BASE_YYYY
               ) C
               LEFT JOIN
                    (
                       SELECT SIMUL_VER_ID                                   AS MP_VERSION_ID
                            , CONVERT(NVARCHAR(6), VER_DATE, 112)            AS VER_YYYYMM
                         FROM TB_CM_CONBD_MAIN_VER_MST M WITH(NOLOCK)
                            , TB_CM_CONBD_MAIN_VER_DTL D WITH(NOLOCK)
                        WHERE 1=1
                          AND D.CONFRM_YN   = 'Y'
                          AND M.ID          = D.CONBD_MAIN_VER_MST_ID
                          AND CONVERT(NVARCHAR(4), M.VER_DATE, 112) = @P_BASE_YYYY

                  ) X  -- MP Version
                 ON 1=1
                AND C.YYYYMM = X.VER_YYYYMM

               LEFT JOIN (
                            SELECT MIN(CONVERT(NVARCHAR(6), VER_DATE, 112))  AS VER_YYYYMM
                                 , MIN(SIMUL_VER_ID)                         AS MIN_MP_VERSION_ID
                              FROM TB_CM_CONBD_MAIN_VER_MST M WITH(NOLOCK)
                                 , TB_CM_CONBD_MAIN_VER_DTL D WITH(NOLOCK)
                             WHERE 1=1
                               AND D.CONFRM_YN   = 'Y'
                               AND M.ID          = D.CONBD_MAIN_VER_MST_ID
                               AND CONVERT(NVARCHAR(4), M.VER_DATE, 112) = @P_BASE_YYYY

                         ) Y  -- Min MP Version
                      ON 1=1

               LEFT JOIN (
                            SELECT MAX(CONVERT(NVARCHAR(6), VER_DATE, 112))  AS VER_YYYYMM
                                 , MAX(SIMUL_VER_ID)                         AS MAX_MP_VERSION_ID
                              FROM TB_CM_CONBD_MAIN_VER_MST M WITH(NOLOCK)
                                 , TB_CM_CONBD_MAIN_VER_DTL D WITH(NOLOCK)
                             WHERE 1=1
                               AND D.CONFRM_YN   = 'Y'
                               AND M.ID          = D.CONBD_MAIN_VER_MST_ID
                               AND CONVERT(NVARCHAR(4), M.VER_DATE, 112) = @P_BASE_YYYY

                       ) Z   -- Max MP Version
                 ON 1=1

    --------------------------
    -- 생산목표량
    --------------------------
    IF OBJECT_ID('tempdb..#TM_PROD_TGT') IS NOT NULL DROP TABLE #TM_PROD_TGT -- 임시테이블 삭제
        SELECT
               I.ATTR_12                       AS VNDR_CD
             , I.ATTR_13                       AS VNDR_NM
             , P.PLAN_MONTH                    AS YYYYMM
             , P.PLAN_QTY                      AS PLAN_QTY
          INTO #TM_PROD_TGT
          FROM TB_SKC_MP_RT_PLAN P
             , TB_CM_ITEM_MST I --ATTR_12
             , #TM_MP_VERSION V
         WHERE 1=1
           AND P.ITEM_CD          = I.ITEM_CD
           AND I.ITEM_TP_ID       = 'GSUB'
           AND P.MP_VERSION_ID    = V.MP_VERSION_ID
           AND P.PLAN_MONTH       = V.YYYYMM
           AND EXISTS ( SELECT 1
                          FROM TB_CM_ITEM_MST I
                         WHERE I.ATTR_12 IN ('102819', '501516')  -- 모아, 케이에스텍
                           AND P.ITEM_CD = I.ITEM_CD
                      )

    --------------------------
    -- Max Capacity
    --------------------------

    IF OBJECT_ID('tempdb..#TM_PROD_CAPA') IS NOT NULL DROP TABLE #TM_PROD_CAPA -- 임시테이블 삭제

        SELECT VNDR_CD
             , YYYYMM
             , CAPA_QTY
          INTO #TM_PROD_CAPA
          FROM TB_SKC_MP_CALD_VNDR V1
         WHERE YYYYMM LIKE @P_BASE_YYYY+'%'
           AND VNDR_CD IN ('102819', '501516')  -- 모아, 케이에스텍
           AND GRADE_CD = 'SUM'

    --------------------------
    -- 생산실적
    --------------------------
    IF OBJECT_ID('tempdb..#TM_PROD_ACT') IS NOT NULL DROP TABLE #TM_PROD_ACT -- 임시테이블 삭제
        SELECT CONVERT(NVARCHAR(6), X.TRNS_DATE,112)     AS YYYYMM
             , VNDR_CD                                   AS VNDR_CD
             , X.STORE_QTY / 1000                        AS ACT_QTY
          INTO #TM_PROD_ACT
          FROM TB_SKC_CM_ACT_VNDR_INFO  X WITH(NOLOCK)
         WHERE CONVERT(NVARCHAR(4), X.TRNS_DATE,112) = @P_BASE_YYYY
           AND VNDR_CD IN ('102819', '501516')  -- 모아, 케이에스텍
		   
    --------------------------
    -- 조회
    --------------------------
    IF OBJECT_ID('tempdb..#TM_QTY_RAW') IS NOT NULL DROP TABLE #TM_QTY_RAW -- 임시테이블 삭제
	

                  SELECT VNDR_CD
                       , YYYYMM
                       , CAPA_QTY   -- Max Capa
                       , PLAN_QTY    -- 생산목표량
                       , ACT_QTY     -- 생산실적
					INTO #TM_QTY_RAW
                    FROM (
                            -- Max Capacity
                            SELECT VNDR_CD          AS VNDR_CD
                                 , YYYYMM           AS YYYYMM
                                 , CAPA_QTY         AS CAPA_QTY
                                 , 0                AS PLAN_QTY
                                 , NULL             AS ACT_QTY
                              FROM #TM_PROD_CAPA
                             UNION ALL
                            -- 생산 목표
                            SELECT VNDR_CD          AS VNDR_CD
                                 , YYYYMM           AS YYYYMM
                                 , 0                AS CAPA_QTY
                                 , PLAN_QTY         AS PLAN_QTY
                                 , NULL             AS ACT_QTY
                              FROM #TM_PROD_TGT
                             UNION ALL
                            -- 생산 실적
                            SELECT VNDR_CD          AS VNDR_CD
                                 , YYYYMM           AS YYYYMM
                                 , 0                AS CAPA_QTY
                                 , 0                AS PLAN_QTY
                                 , ACT_QTY          AS ACT_QTY
                              FROM #TM_PROD_ACT
                        ) X

    --------------------------
    -- 조회
    --------------------------
    IF OBJECT_ID('tempdb..#TM_QTY') IS NOT NULL DROP TABLE #TM_QTY -- 임시테이블 삭제
        SELECT A.VNDR_CD                            AS VNDR_CD
		     , A.VNDR_NM                             AS VNDR_NM
             , A.YYYYMM                             AS YYYYMM
             , M.MEASURE_CD                         AS MEASURE_CD
             , M.MEASURE_NM                         AS MEASURE_NM
             --, ISNULL(CASE WHEN MEASURE_CD = '01' THEN CAPA_QTY              -- Max Capa
             --              WHEN MEASURE_CD = '02' THEN PLAN_QTY              -- 생산목표량
             --              WHEN MEASURE_CD = '03' THEN ACT_QTY               -- 생산실적
             --              WHEN MEASURE_CD = '04' THEN GAP_QTY               -- GAP = 생산실적 - 생산목표량
             --              WHEN MEASURE_CD = '05' THEN OPER_RATE             -- 가동률 = 생산실적 / Max Capacity
             --              WHEN MEASURE_CD = '06' THEN ACT_RATE              -- 실적 달성률 = 생산실적 / 생산목표량
             --          END ,0)                      AS QTY
			 , CASE WHEN MEASURE_CD = '01' THEN ISNULL(CAPA_QTY, 0)              -- Max Capa
                    WHEN MEASURE_CD = '02' THEN ISNULL(PLAN_QTY, 0)              -- 생산목표량
                    WHEN MEASURE_CD = '03' THEN ACT_QTY               -- 생산실적
                    WHEN MEASURE_CD = '04' THEN GAP_QTY               -- GAP = 생산실적 - 생산목표량
                    WHEN MEASURE_CD = '05' THEN OPER_RATE             -- 가동률 = 생산실적 / Max Capacity
                    WHEN MEASURE_CD = '06' THEN ACT_RATE              -- 실적 달성률 = 생산실적 / 생산목표량
                END                       AS QTY
      INTO #TM_QTY
          FROM (
		          SELECT A.VNDR_CD                                   AS VNDR_CD
             , B.VNDR_NM                            AS VNDR_NM
                       , A.YYYYMM                                    AS YYYYMM
                       , IIF(YYYYMM BETWEEN '202401' AND '202407' , 6000,SUM(CAPA_QTY ))          AS CAPA_QTY    -- Max Capa
                       , IIF(YYYYMM BETWEEN '202401' AND '202407' , 6000,SUM(PLAN_QTY ))          AS PLAN_QTY    -- 생산목표량
                       , SUM(ACT_QTY  )                            AS ACT_QTY     -- 생산실적
                       , SUM(ACT_QTY  ) - IIF(YYYYMM BETWEEN '202401' AND '202407' , 6000,SUM(PLAN_QTY ))          AS GAP_QTY     -- GAP = 생산실적 - 생산목표량
                       , (SUM(ACT_QTY ) / IIF(YYYYMM BETWEEN '202401' AND '202407' , 6000,SUM(CAPA_QTY ))) * 100   AS OPER_RATE   -- 가동률 = 생산실적 / Max Capacity
                       , (SUM(ACT_QTY ) / IIF(YYYYMM BETWEEN '202401' AND '202407' , 6000,SUM(PLAN_QTY ))) * 100   AS ACT_RATE    -- 실적 달성률 = 생산실적 / 생산목표량
					   FROM #TM_QTY_RAW A
             , TB_SKC_CM_VNDR_MST B
         WHERE A.VNDR_CD = B.VNDR_CD
           AND B.VNDR_CD IN ('102819', '501516')  -- 모아, 케이에스텍
                   GROUP BY A. VNDR_CD
				         , B.VNDR_NM 
                          , YYYYMM
						  UNION ALL
						  
		          SELECT 'Total'                                   AS VNDR_CD
				      , 'Total'                                   AS VNDR_NM
                       , YYYYMM                                    AS YYYYMM
                       , IIF(YYYYMM BETWEEN '202401' AND '202407' , 12000,SUM(CAPA_QTY ))                            AS CAPA_QTY    -- Max Capa
                       , IIF(YYYYMM BETWEEN '202401' AND '202407' , 12000,SUM(PLAN_QTY ))                            AS PLAN_QTY    -- 생산목표량
                       , SUM(ACT_QTY  )                            AS ACT_QTY     -- 생산실적
                       , SUM(ACT_QTY  ) - IIF(YYYYMM BETWEEN '202401' AND '202407' , 12000,SUM(PLAN_QTY ))          AS GAP_QTY     -- GAP = 생산실적 - 생산목표량
                       , (SUM(ACT_QTY ) / IIF(YYYYMM BETWEEN '202401' AND '202407' , 12000,SUM(CAPA_QTY ))) * 100   AS OPER_RATE   -- 가동률 = 생산실적 / Max Capacity
                       , (SUM(ACT_QTY ) / IIF(YYYYMM BETWEEN '202401' AND '202407' , 12000,SUM(PLAN_QTY ))) * 100   AS ACT_RATE    -- 실적 달성률 = 생산실적 / 생산목표량
					   FROM #TM_QTY_RAW
                   GROUP BY YYYYMM
		       ) A
             , #TM_MEASURE M

         ORDER BY VNDR_CD
                , YYYYMM


    --------------------------
    -- 조회 (전체)
    --------------------------
        SELECT VNDR_CD               AS VNDR_CD
             , VNDR_NM               AS VNDR_NM
             , YYYYMM                AS YYYYMM
             , MEASURE_CD            AS MEASURE_CD
             , MEASURE_NM            AS MEASURE_NM
             , QTY                   AS QTY
          FROM #TM_QTY
        -- UNION ALL
        --SELECT 'Total'               AS VNDR_CD
        --     , 'Total'               AS VNDR_NM
        --     , YYYYMM                AS YYYYMM
        --     , MEASURE_CD            AS MEASURE_CD
        --     , MEASURE_NM            AS MEASURE_NM
        --     , SUM(QTY)              AS QTY
        --  FROM #TM_QTY
        -- GROUP BY
        --       YYYYMM
        --     , MEASURE_CD
        --     , MEASURE_NM
         ORDER BY
               VNDR_CD
			 , MEASURE_CD
             , MEASURE_NM
			 , YYYYMM

END

GO
