USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP3010_POP_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP3010_POP_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     긴급 요청 관리 팝업 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-19  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP3010_POP_Q1] (
	 @P_ID					NVARCHAR(32)
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
BEGIN

	SELECT A.ID
		 , C.ATTR_02 AS CORP_NM
		 , D.ANCESTER_NM AS TEAM_NM
		 , E.EMP_NM
		 , C.ATTR_03 AS ACCOUNT_CD
		 , C.ACCOUNT_NM
		 , C.ATTR_04 AS REGION
		 , B.ITEM_CD
		 , B.ITEM_NM
		 , C.ATTR_06 AS PLNT_NM
		 , A.URNT_DMND_QTY
		 , CAST(A.REQUEST_DATE_ID AS DATE) AS REQUEST_DATE_ID
		 , A.COMMENT AS URNT_COMMENT
		 , A.CREATE_BY
		 , A.CREATE_DTTM
		 , A.MODIFY_BY
		 , A.MODIFY_DTTM
	  FROM TB_SKC_DP_URNT_DMND_MST A
	 INNER JOIN TB_CM_ITEM_MST B 
		ON A.ITEM_MST_ID = B.ID
	 INNER JOIN TB_DP_ACCOUNT_MST C
		ON A.ACCOUNT_ID = C.ID
	 INNER JOIN TB_DPD_SALES_HIER_CLOSURE D
		ON C.ID = D.DESCENDANT_ID
	   AND DEPTH_NUM = 2
	 INNER JOIN TB_DP_EMPLOYEE E
	    ON A.EMP_ID = E.EMP_NO
	 INNER JOIN TB_AD_COMN_CODE F
	    ON A.STATUS_CD = F.COMN_CD
	   AND F.SRC_ID ='8a7776af8ef04b72018ef08538b70000'
	 WHERE A.ID = @P_ID
END
GO
