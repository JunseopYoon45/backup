USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_Q1] (
	  @P_DP_VERSION		 NVARCHAR(30)	-- DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	-- MP 버전	
	, @P_BRND_CD		 NVARCHAR(MAX)	-- Brand코드	
	, @P_GRADE_CD		 NVARCHAR(MAX)	-- 그레이드코드
	, @P_ITEM_CD		 NVARCHAR(30)	-- 제품코드	
	, @P_ITEM_NM		 NVARCHAR(30)	-- 제품명	
	, @P_ITEM_TP		 NVARCHAR(30)	-- 제품타입	
	, @P_LANG_CD		 NVARCHAR(10)   -- 다국어코드
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID		 NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
  PROCEDURE NAME  : SP_SKC_UI_MP1031_Q1
  COPYRIGHT       : Zionex
  REMARK          : 공급 계획 > 공급 계획 수립 > PSI 및 공급 계획 확정
                    법인 창고 PSI

  CONTENTS        : ╬╬ SKCA, SKCA 법인 제품/창고별 PSI 산출 (A199, B199는 본사 PSI에 포함)
                    1. 수요계획                    : 확정 수요계획 (DP)
					2. 예상 창고 입고 (공급 계획)  : MP 납품일 기준 공급계획
					3. 예상 창고 입고 (In-Transit) : In-Transit 도착일 기준
					4. 예상 창고 재고              : Σ(법인 창고 재고(I) – 수요계획(S) + 예상 창고 입고(P))
					5. 예상 선적 (CY + 공급 계획)  : MP 선적일 기준 공급계획 + CY 선적 L/T 반영일 기준
					6. 예상 In-Transit 재고        : Σ(In-Transit 재고(I) – 예상 창고 입고(S) + 예상 선적(P))
-----------------------------------------------------------------------------------------------------------------------
    DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
   2024-07-05  Zionex          신규 생성
   2024-08-05  Zionex          성능을 고려한 테이블 조회 로직 변경
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

-------------------------------------------------- LOG START --------------------------------------------------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_Q1 'DP-202407-01-M','MP-20240808-01-M-07','ALL','ALL','','','','kr','zionex8',''
*/
DECLARE @P_PGM_NM     NVARCHAR(100)  = OBJECT_NAME(@@PROCID)
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID) ;

    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_DP_VERSION	), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_MP_VERSION	), '')			 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_BRND_CD		), '')				 
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_GRADE_CD		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_CD		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_NM		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_TP		), '')
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD 		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID		), '')
                   + ''''

DECLARE @V_DP_VERSION	  NVARCHAR(30)  = @P_DP_VERSION		-- DP 버전
	  , @V_MP_VERSION	  NVARCHAR(30)  = @P_MP_VERSION		-- MP 버전	  
	  , @V_BRND_CD		  NVARCHAR(MAX) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(MAX) = REPLACE(@P_GRADE_CD, 'ALL', '')
	  , @V_ITEM_CD		  NVARCHAR(30)  = @P_ITEM_CD
	  , @V_ITEM_NM		  NVARCHAR(30)  = @P_ITEM_NM
	  , @V_ITEM_TP		  NVARCHAR(30)  = @P_ITEM_TP	

   EXEC SP_PGM_LOG  'MP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

-------------------------------------------------- LOG END --------------------------------------------------

BEGIN

    ---------------------------------------------------------------------------------------------------------
    -- #TM_BRND
	-- Brand 다중 검색 용도
    ---------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#TM_BRND') IS NOT NULL DROP TABLE #TM_BRND -- 임시테이블 삭제
	SELECT Value AS VAL
      INTO #TM_BRND
      FROM SplitTableNVARCHAR(ISNULL(UPPER(@V_BRND_CD),''),'|');

    ---------------------------------------------------------------------------------------------------------
    -- #TM_GRADE
	-- Grade 다중 검색 용도
    ---------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#TM_GRADE') IS NOT NULL DROP TABLE #TM_GRADE -- 임시테이블 삭제
	SELECT Value AS VAL
      INTO #TM_GRADE
      FROM SplitTableNVARCHAR(ISNULL(UPPER(@V_GRADE_CD),''),'|');

	/*************************************************************************************************************
	  [화면 조회]
	*************************************************************************************************************/
	SELECT A.BRND_CD,     A.BRND_NM,     A.GRADE_CD,      A.GRADE_NM, A.ITEM_CD
	     , CONCAT(A.ITEM_CD, ' - ', A.ITEM_NM) AS ITEM_NM
		 , A.ITEM_TP,     A.CDC_STCK_QTY
		 , A.CY_STCK_QTY, A.IN_TRNS_QTY, A.PLNT_STCK_QTY, A.BOD_W_LT
		 , A.CORP_CD,     A.CORP_NM,     A.PLNT_CD,       A.PLNT_NM
		 , A.MEASURE_CD,  A.MEASURE_NM,  A.DT_TYPE,       A.REP_DT
		 , A.REP_DT_DESC, A.YYYY,        A.YYYYMM,        A.PLAN_DT
		 , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY	
	  FROM TB_SKC_MP_UI_PLNT_PSI A
	 WHERE 1 = 1
	   AND A.MP_VERSION_ID = @V_MP_VERSION
	   AND A.DP_VERSION_ID = @V_DP_VERSION
	   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
	   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	   AND ((@V_ITEM_CD = '') OR (A.ITEM_CD LIKE '%' + @V_ITEM_CD + '%'))
	   AND ((@V_ITEM_NM = '') OR (A.ITEM_NM LIKE '%' + @V_ITEM_NM + '%')) 
	   AND ((@V_ITEM_TP = '') OR (A.ITEM_TP LIKE '%' + @V_ITEM_TP + '%'))
	 ORDER BY A.BRND_CD, A.BRND_NM, A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD, A.ITEM_NM, A.CORP_CD,    A.CORP_NM
			, A.PLNT_CD, A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM
		    , A.YYYY,    A.YYYYMM,  A.PLAN_DT

 END
GO
