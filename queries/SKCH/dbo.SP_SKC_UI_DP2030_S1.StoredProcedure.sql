USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_DP2030_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME             SP_SKC_UI_DP2030_S1
-- COPYRIGHT                  ZIONEX
-- REMARK                     수요 우선순위 저장
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-03-21  YJS            신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_DP2030_S1] (
	  @P_VER_ID				NVARCHAR(32)
    , @P_ID					NVARCHAR(32)
	, @P_STRTGY_YN			NVARCHAR(10)
	, @P_USER_ID			NVARCHAR(32)
	, @P_RT_ROLLBACK_FLAG   NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG             NVARCHAR(4000) = ''      OUTPUT
	)
AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON;

DECLARE 
	  @v_VER_ID			VARCHAR(32)
	, @P_ERR_STATUS		INT = 0
    , @P_ERR_MSG		NVARCHAR(4000)='';	

BEGIN TRY

	BEGIN

	SELECT @v_VER_ID = ID 
	  FROM TB_DP_CONTROL_BOARD_VER_MST 
	 WHERE VER_ID = @P_VER_ID

	MERGE INTO TB_SKC_DP_STRTGY_ENTRY A USING (
		SELECT VER_ID
			 , ID
			 , ITEM_MST_ID
			 , ACCOUNT_ID
			 , BASE_DATE
			 , @P_STRTGY_YN AS STRTGY_YN
		  FROM TB_SKC_DP_STRTGY_ENTRY
		 WHERE ID = @P_ID
		   --AND VER_ID = @P_VER_ID
	) B ON (A.ID = B.ID)
	WHEN MATCHED THEN
	UPDATE SET A.STRTGY_YN = B.STRTGY_YN, A.MODIFY_BY = @P_USER_ID, A.MODIFY_DTTM = GETDATE();		

	MERGE INTO TB_DP_ENTRY A USING (
		SELECT A.ID AS ID
			 , A.ITEM_MST_ID
			 , A.ACCOUNT_ID
			 , A.VER_ID
			 , A.BASE_DATE
			 , CASE WHEN B.STRTGY_YN = 'Y' THEN '1'
					WHEN B.STRTGY_YN = 'N' AND B.RTF_YN = 'Y' THEN '2'
					WHEN B.STRTGY_YN = 'N' AND B.RTF_YN = 'N' THEN '3' END AS PRIORT
		  FROM TB_DP_ENTRY A
		 INNER JOIN TB_SKC_DP_STRTGY_ENTRY B
			ON A.ITEM_MST_ID = B.ITEM_MST_ID
		   AND A.ACCOUNT_ID = B.ACCOUNT_ID
		   AND FORMAT(A.BASE_DATE, 'yyyyMM') = FORMAT(B.BASE_DATE, 'yyyyMM')
		 --WHERE A.VER_ID = @v_VER_ID
		 WHERE A.VER_ID = @P_VER_ID
		   AND B.ID = @P_ID
		   AND A.AUTH_TP_ID = (SELECT ID FROM TB_CM_LEVEL_MGMT WHERE LV_CD = 'MARKETER')
	) B ON (A.ID = B.ID)
	WHEN MATCHED THEN
	UPDATE SET A.PRIORT = B.PRIORT, A.MODIFY_BY = @P_USER_ID, A.MODIFY_DTTM = GETDATE();


    -----------------------------------
    -- 저장메시지
    -----------------------------------
    IF  @@TRANCOUNT > 0 COMMIT TRANSACTION
        SET @P_RT_ROLLBACK_FLAG = 'TRUE';
        SET @P_RT_MSG           = 'MSG_0001';  --저장되었습니다.
	END

    END TRY

    BEGIN CATCH
        IF (ERROR_MESSAGE() LIKE 'MSG_%')
			BEGIN
			  SET @P_ERR_MSG          = ERROR_MESSAGE()
			  SET @P_RT_ROLLBACK_FLAG = 'FALSE'
			  SET @P_RT_MSG           = @P_ERR_MSG
			END
        ELSE
		    THROW;
    END CATCH
GO
