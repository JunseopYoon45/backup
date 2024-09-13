USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_CM2050_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_CM2050_Q1
-- COPYRIGHT                  ZIONEX
-- REMARK                     BOD 관리 조회
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-04-01  YJS            신규 생성
-- 2024-07-09  YJS			  테이블 구조 변경
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^***N******^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_CM2050_Q1] (
	 @P_VER_CD				NVARCHAR(30)
   , @P_LANG_CD				NVARCHAR(10)    = 'ko'
   , @P_USER_ID             NVARCHAR(100)   = NULL    -- USER_ID
   , @P_VIEW_ID             NVARCHAR(100)   = NULL    -- VIEW_ID
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
DECLARE	@v_VER_CD CHAR(30)

BEGIN
	
	SET @v_VER_CD = @P_VER_CD;

	IF @v_VER_CD = CONVERT(CHAR(8), GETDATE(), 112)
	BEGIN
		SELECT A.ID
			 , A.PLNT_CD
			 , (SELECT TOP 1 CASE WHEN @P_LANG_CD = 'en' THEN PLNT_NM_EN ELSE PLNT_NM END FROM VW_CORP_PLNT K WHERE K.PLNT_CD = A.PLNT_CD)  AS PLNT_NM
			 , SHIP_CD
			 , C1.COMN_CD_NM AS SHIP
			 , CY_CD
			 , C2.COMN_CD_NM AS CY
			 , A.POL_CD
			 , C3.COMN_CD_NM AS DEP_PORT
			 , A.POD_CD
			 , COALESCE(C4.COMN_CD_NM, '-') AS ARR_PORT
			 , A.PLNT_CD AS STORAGE
			 , A.FD_CD
			 , COALESCE(F.COMN_CD_NM, '-') AS DLVR_LOC
			 , CY_LT
			 , SEA_LEAD_TIME AS SHIP_LT
			 , SHIP_CONF_LT
			 , LAND_LEAD_TIME AS LAND_LT
			 , LAND_CONF_LT
			 , A.CREATE_BY
			 , A.CREATE_DTTM
			 , A.MODIFY_BY
			 , A.MODIFY_DTTM
		 FROM TB_SKC_DP_BOD_MST A
		 LEFT JOIN TB_SKC_BOD_MST B
		   ON A.POD_CD = B.POD_CD
		  AND A.POL_CD = B.POL_CD
		  AND A.PLNT_CD = B.PLNT_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'FD')) F
			ON A.FD_CD = F.COMN_CD
		 INNER JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C1
			ON A.SHIP_CD = C1.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C2
			ON A.CY_CD = C2.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C3
			ON A.POL_CD = C3.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C4
			ON A.POD_CD = C4.COMN_CD
		 ORDER BY 2
	END;
	ELSE
		BEGIN
		SELECT A.PLNT_CD
			 , (SELECT TOP 1 CASE WHEN @P_LANG_CD = 'en' THEN PLNT_NM_EN ELSE PLNT_NM END FROM VW_CORP_PLNT K WHERE K.PLNT_CD = A.PLNT_CD)  AS PLNT_NM
			 , SHIP_CD
			 , C1.COMN_CD_NM AS SHIP
			 , CY_CD
			 , C2.COMN_CD_NM AS CY
			 , A.POL_CD
			 , C3.COMN_CD_NM AS DEP_PORT
			 , A.POD_CD
			 , COALESCE(C4.COMN_CD_NM, '-') AS ARR_PORT
			 , A.PLNT_CD AS STORAGE
			 , A.FD_CD
			 , COALESCE(F.COMN_CD_NM, '-') AS DLVR_LOC
			 , CY_LT
			 , SEA_LEAD_TIME AS SHIP_LT
			 , SHIP_CONF_LT
			 , LAND_LEAD_TIME AS LAND_LT
			 , LAND_CONF_LT
			 , A.CREATE_BY
			 , A.CREATE_DTTM
			 , A.MODIFY_BY
			 , A.MODIFY_DTTM
		 FROM TB_SKC_DP_BOD_MST_HIS A
		 LEFT JOIN TB_SKC_BOD_MST B
		   ON A.POD_CD = B.POD_CD
		  AND A.POL_CD = B.POL_CD
		  AND A.PLNT_CD = B.PLNT_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'FD')) F
			ON A.FD_CD = F.COMN_CD
		 INNER JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C1
			ON A.SHIP_CD = C1.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C2
			ON A.CY_CD = C2.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C3
			ON A.POL_CD = C3.COMN_CD
		 LEFT JOIN (SELECT COMN_CD
						  , COMN_CD_NM 
					   FROM TB_AD_COMN_CODE 
					  WHERE SRC_ID = (SELECT ID fROM TB_AD_COMN_GRP WHERE GRP_CD = 'POD')) C4
			ON A.POD_CD = C4.COMN_CD
		 WHERE VER_ID = @v_VER_CD
		 ORDER BY 1
		END;
END
GO
