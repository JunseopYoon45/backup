USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_MP1031_POP_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_MP1031_POP_Q1] (
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
   PROCEDURE NAME  : SP_SKC_UI_MP1031_POP_Q1
   COPYRIGHT       : Zionex
   REMARK          : 공급 계획 > 공급 계획 수립 > 공급 계획 분석
                     울산 선적 기준
-----------------------------------------------------------------------------------------------------------------------  
   CONTENTS        : ╬╬ 울산 선적 기준 PSI 산출
                     1. 수요계획                        : 확정 수요계획 (DP)
					 2. 재고차감(In-transit + 법인창고) : Σ(법인 창고 재고(I) - 수요 계획(S) + In-transit 재고(P))
                     3. 안전 재고 보충                  : 안전 재고 Demand 공급계획 (Demand ID의 첫 글자 'S'로 구분)
					 4. 선적 기준 공급 필요량           : 재고 Netting 및 L/T를 감안한 선적 시점(납기)의 Demand
					 5. 선적 기준 공급 계획             : MP 선적일 기준 공급계획
					 6. 차이 누계                       : Σ(선적 기준 공급 계획 - 선적 기준 공급 필요량)
					 7. 선적 기준 공급 필요량 합계      : Σ(선적 기준 공급 필요량)
					 8. 선적 기준 공급 계획 합계        : Σ(선적 기준 공급 계획)
					 9. 차이                            : Σ(선적 기준 공급 계획 합계 - 선적 기준 공급 필요량 합계)
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
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_MP1031_POP_Q1' ORDER BY LOG_DTTM DESC

EXEC SP_SKC_UI_MP1031_POP_Q1 'DP-202407-01-M','MP-20240805-01-M-03','ALL','ALL','','','','ALL','ko','zionex8',''
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
	  , @V_BRND_CD		  NVARCHAR(30) = REPLACE(@P_BRND_CD,  'ALL', '')	 
	  , @V_GRADE_CD		  NVARCHAR(30) = REPLACE(@P_GRADE_CD, 'ALL', '')
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

    /* 버전조회 */
    -- 대상 DP버전 선택
	IF OBJECT_ID ('tempdb..#TB_DP_VER') IS NOT NULL DROP TABLE #TB_DP_VER
	SELECT @V_DTF_DATE		 = MA.DTF_DATE
		 , @V_FROM_DATE		 = MA.FROM_DATE
		 , @V_VAR_START_DATE = MA.VER_S_HORIZON_DATE 
		 , @V_TO_DATE		 = MA.TO_DATE
	  FROM TB_DP_CONTROL_BOARD_VER_MST MA WITH (NOLOCK)
	     , TB_DP_CONTROL_BOARD_VER_DTL DT WITH (NOLOCK)
	     , ( SELECT * 
		       FROM TB_CM_COMM_CONFIG WITH (NOLOCK)
		      WHERE 1 = 1
		        AND CONF_GRP_CD = 'DP_CL_STATUS' 
		        AND CONF_CD		= 'CLOSE'        -- 확정버전
		        AND ACTV_YN		= 'Y'
	       ) CN
	 WHERE 1 = 1
	   AND MA.ID           = DT.CONBD_VER_MST_ID
	   AND DT.CL_STATUS_ID = CN.ID
	   AND MA.VER_ID       = @V_DP_VERSION

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
	SELECT A.BRND_CD,     A.BRND_NM,       A.GRADE_CD,     A.GRADE_NM
		 , A.ITEM_CD,     A.ITEM_NM,       A.CDC_STCK_QTY, A.CY_STCK_QTY
		 , A.IN_TRNS_QTY, A.PLNT_STCK_QTY, A.BOD_W_LT,     A.SALES_ZONE
		 , A.PLNT_CD,     A.PLNT_NM,       A.MEASURE_CD,   A.MEASURE_NM
		 , A.DT_TYPE,     A.REP_DT,        A.REP_DT_DESC,  A.YYYY
		 , A.YYYYMM,      A.PLAN_DT,       A.ITEM_TP
		 , ROUND(A.PLAN_QTY, 0) AS PLAN_QTY
      FROM TB_SKC_MP_UI_ULSAN_SHMT A
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
