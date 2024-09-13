USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_UI_DP_00_POPUP_VERSION_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************
Title : SP_UI_DP_00_POPUP_VERSION_Q1
최초 작성자 : 김소희
최초 생성일 : 2019.01.21
？ 
설명
 -  DP Version ID 조회
 ？
History (수정일자 / 수정자 / 수정내용)
-  2019.01.21 / 김소희 / DP Version 조회 공용화를 위한 프로시저 생성
-  2021.07.01 / 김소희 / get RTF Version 
-  2021.10.05 / hanguls/ MP Version 을 confirm dttm 순서로 sort
- 2023.02.16 / kim sohee / RTF version 분리 (RTF 보고서)
- 2023.05.18 / kim sohee / change a method to get LAST VERSION ID
*****************************************************************************/
CREATE PROCEDURE [dbo].[SP_UI_DP_00_POPUP_VERSION_Q1] 
(
	@P_CONFRM_YN NVARCHAR(10)
)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

	DECLARE @P_DF_PLAN_TP_ID CHAR(32);

BEGIN

SELECT @P_DF_PLAN_TP_ID = ID  
  FROM TB_CM_COMM_CONFIG
 WHERE CONF_GRP_CD = 'DP_PLAN_TYPE'
  AND DEFAT_VAL = 'Y'
  ;

	IF (@P_CONFRM_YN = 'ALL')
		BEGIN
			SELECT A.* 
			FROM (
				SELECT    MS.ID
						, MS.VER_ID
						, MS.BUKT
						, MS.HORIZ
						, MS.FROM_DATE
						, MS.TO_DATE                
						, ROW_NUMBER() OVER (ORDER BY COALESCE(MS.CREATE_DTTM, MS.MODIFY_DTTM) DESC, MS.VER_ID desc) AS ROWN
						, DT.CL_STATUS_ID
						, C.CONF_CD AS V_STATUS
				  FROM TB_DP_CONTROL_BOARD_VER_MST MS
					   INNER JOIN
					   TB_DP_CONTROL_BOARD_VER_DTL DT
					ON MS.ID = DT.CONBD_VER_MST_ID
					AND DT.WORK_TP_ID IN (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_CD = 'CL' AND CONF_GRP_CD = 'DP_WK_TP') 
					LEFT OUTER JOIN  TB_CM_COMM_CONFIG c on CONF_GRP_CD = 'DP_CL_STATUS' and c.id = DT.CL_STATUS_ID
				WHERE 1=1
				  --AND (case when @P_CL_YN ='Y'  then C.CONF_CD else 'CLOSE' END) = 'CLOSE'
				  AND MS.PLAN_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_CD = 'DP_PLAN_MONTHLY')
			)  A
			--WHERE A.ROWN <= @P_VER_CNT
			ORDER BY A.ROWN
			  ;
		END;
	IF (@P_CONFRM_YN = 'Y')
		BEGIN
			SELECT A.* 
			FROM (
				SELECT    MS.ID
						, MS.VER_ID
						, MS.BUKT
						, MS.HORIZ
						, MS.FROM_DATE
						, MS.TO_DATE                
						, ROW_NUMBER() OVER (ORDER BY COALESCE(MS.CREATE_DTTM, MS.MODIFY_DTTM) DESC, MS.VER_ID desc) AS ROWN
						, DT.CL_STATUS_ID
						, C.CONF_CD AS V_STATUS
				  FROM TB_DP_CONTROL_BOARD_VER_MST MS
					   INNER JOIN
					   TB_DP_CONTROL_BOARD_VER_DTL DT
					ON MS.ID = DT.CONBD_VER_MST_ID
					AND DT.WORK_TP_ID IN (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_CD = 'CL' AND CONF_GRP_CD = 'DP_WK_TP') 
					LEFT OUTER JOIN  TB_CM_COMM_CONFIG c on CONF_GRP_CD = 'DP_CL_STATUS' and c.id = DT.CL_STATUS_ID
				WHERE 1=1
				  AND C.CONF_CD = 'CLOSE'
				  AND MS.PLAN_TP_ID = (SELECT ID FROM TB_CM_COMM_CONFIG WHERE CONF_CD = 'DP_PLAN_MONTHLY')
			)  A
			--WHERE A.ROWN <= @P_VER_CNT
			ORDER BY A.ROWN
			  ;
		END;

END;
GO
