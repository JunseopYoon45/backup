USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_POP_Q2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_POP_Q2] (
	  @P_DP_VERSION		 NVARCHAR(30)	--DP 버전
	, @P_MP_VERSION		 NVARCHAR(30)	--MP 버전	
	, @P_BRND_CD		 NVARCHAR(MAX)	--Brand코드	
	, @P_GRADE_CD		 NVARCHAR(MAX)	--그레이드코드
	, @P_ITEM_CD		 NVARCHAR(30)	--제품코드	
	, @P_ITEM_NM		 NVARCHAR(30)	--제품명	
	, @P_ITEM_TP		 NVARCHAR(30)	--제품타입	
	, @P_CORP_CD         NVARCHAR(30)   --법인코드	
	, @P_LANG_CD		 NVARCHAR(10)   --다국어처리
    , @P_USER_ID		 NVARCHAR(100)   = NULL    -- USER_ID
    , @P_VIEW_ID		 NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********
   PROCEDURE NAME  : SP_SKC_UI_MP1031_POP_Q2
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > 공급 계획 분석
                     완제품 출하
-----------------------------------------------------------------------------------------------------------------------  
   CONTENTS        : ╬╬ 완제품 출하 PSI 산출
                     1. 선적 기준 공급 필요량             : 재고 Netting 및 L/T를 감안한 선적 시점(납기)의 Demand
					 2. CY 재고 차감                      : Σ(CY 재고(I) - 선적 기준 공급 필요량(S))
                     3. 완제품 출하 기준 공급 필요량      : 재고 Netting 및 L/T를 감안한 출하 시점(납기)의 Demand
					 4. 완제품 출하 기준 공급 계획        : MP 출하일 기준 공급계획					
					 5. 차이 누계                         : Σ(완제품 출하 기준 공급 계획 - 완제품 출하 기준 공급 필요량)
					 6. 완제품 출하 기준 공급 필요량 합계 : Σ(완제품 출하 기준 공급 필요량)
					 7. 완제품 출하 기준 공급 계획 합계   : Σ(완제품 출하 기준 공급 계획)
					 8. 차이 합계                         : Σ(완제품 출하 기준 공급 계획 합계 - 완제품 출하 기준 공급 필요량 합계)
-----------------------------------------------------------------------------------------------------------------------
   DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
   2024-07-10  Zionex         신규 생성
   2024-08-06  Zionex         성능을 고려한 테이블 조회 로직 변경
*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_POP_Q2' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_POP_Q2 'DP-202406-01-M','MP-20240702-03-M-24','ALL','ALL','100452','','','ALL','kr','zionex8',''
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
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_CORP_CD 		), '') 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_LANG_CD 		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID		), '')
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID		), '')
                   + ''''

DECLARE @V_DP_VERSION	  NVARCHAR(30) = @P_DP_VERSION		-- DP 버전
	  , @V_MP_VERSION	  NVARCHAR(30) = @P_MP_VERSION		-- MP 버전	  
	  , @V_BRND_CD		  NVARCHAR(MAX) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(MAX) = REPLACE(@P_GRADE_CD, 'ALL', '')
	  , @V_ITEM_CD		  NVARCHAR(30) = @P_ITEM_CD
	  , @V_ITEM_NM		  NVARCHAR(30) = @P_ITEM_NM
	  , @V_ITEM_TP		  NVARCHAR(30) = @P_ITEM_TP
	  , @V_CORP_CD		  NVARCHAR(30) = REPLACE(@P_CORP_CD,  'ALL', '')
	  , @V_DTF_DATE		  DATETIME
	  , @V_FROM_DATE	  DATETIME   
	  , @V_VAR_START_DATE DATETIME
	  , @V_TO_DATE		  DATETIME	  

   EXEC SP_PGM_LOG  'MP', @P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------
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
	SELECT A.BRND_CD,    A.BRND_NM, A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,    A.ITEM_NM, A.CDC_STCK_QTY, A.CY_STCK_QTY
		 , A.SALES_ZONE, A.PLNT_CD, A.PLNT_NM,      A.MEASURE_CD
		 , A.MEASURE_NM, A.DT_TYPE, A.REP_DT,       A.REP_DT_DESC
		 , A.YYYY,       A.YYYYMM,  A.PLAN_DT
		 , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
	  FROM TB_SKC_MP_UI_GFRT_SHNG A
	 WHERE 1 = 1
	   AND A.MP_VERSION_ID = @V_MP_VERSION
	   AND A.DP_VERSION_ID = @V_DP_VERSION
	   AND (A.BRND_CD  IN (SELECT VAL FROM #TM_BRND)  OR ISNULL(@V_BRND_CD,  '') = '')
	   AND (A.GRADE_CD IN (SELECT VAL FROM #TM_GRADE) OR ISNULL(@V_GRADE_CD, '') = '')
	   AND ((@V_ITEM_CD = '') OR (A.ITEM_CD LIKE '%' + @V_ITEM_CD + '%'))
	   AND ((@V_ITEM_NM = '') OR (A.ITEM_NM LIKE '%' + @V_ITEM_NM + '%')) 
	   AND ((@V_ITEM_TP = '') OR (A.ITEM_TP LIKE '%' + @V_ITEM_TP + '%'))
	   AND ((@V_CORP_CD = '') OR (A.CORP_CD	   =     @V_CORP_CD))
	 ORDER BY A.BRND_CD, A.BRND_NM,    A.GRADE_CD,   A.GRADE_NM
		    , A.ITEM_CD, A.ITEM_NM,    A.SALES_ZONE, A.PLNT_CD
			, A.PLNT_NM, A.MEASURE_CD, A.MEASURE_NM, A.YYYY
			, A.YYYYMM,  A.PLAN_DT
END
GO
