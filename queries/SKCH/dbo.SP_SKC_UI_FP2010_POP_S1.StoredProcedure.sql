USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_POP_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_POP_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_FP_VERSION                     NVARCHAR(100)                         -- Version
	, @P_PLAN_DTE						NVARCHAR(8)    = NULL
	, @P_RSRC_CD                        NVARCHAR(10)   = NULL		 	
	, @P_RE_ESTB_YN						NVARCHAR(2)	   = 'N'
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
)
AS
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_POP_S1
-- COPYRIGHT       : ZIONEX
-- REMARK          : CHDM 생산계획
--                   1) CHDM 생산계획 재수립 정보 수정
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             Modification
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET NOCOUNT ON;

---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_POP_S1' ORDER BY LOG_DTTM DESC
EXEC SP_SKC_UI_FP2010_POP_S1'U','FP-20240722-CH-01','20240523','CDP-1','Y','SCM System','UI_FP2010'
EXEC SP_SKC_UI_FP2010_POP_S1'U','FP-20240722-CH-01','20240531','CDP-4','Y','SCM System','UI_FP2010'
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000) =''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''
	  , @v_PLAN_DTE   NVARCHAR(8)

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE            ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION           ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLAN_DTE             ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD              ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RE_ESTB_YN           ),'')    -- 
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID              ),'')    -- LOGIN_ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID              ),'')    -- VIEW_ID
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------
BEGIN

    BEGIN TRY
        IF @P_WORK_TYPE IN ('U')
        BEGIN

		SET @v_PLAN_DTE = CONVERT(CHAR(8), CAST(CONVERT(CHAR(10), @P_PLAN_DTE, 23) AS DATE), 112)
     -----------------------------------
    -- 저장
    -----------------------------------
	
	
		BEGIN        
             MERGE INTO TB_SKC_FP_RE_ESTB AS TGT
             USING (
                     SELECT @P_FP_VERSION            AS VERSION_CD
                          , @P_RSRC_CD               AS RSRC_CD         -- LINE    (KEY)
						  , @v_PLAN_DTE				 AS PLAN_DTE		-- 일자    (KEY)
						  , @P_RE_ESTB_YN			 AS RE_ESTB_YN

                   ) AS SRC
                ON (     TGT.VERSION_CD    = SRC.VERSION_CD 
					 AND TGT.RSRC_CD       = SRC.RSRC_CD
                   )				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET PLAN_DTE  	     = SRC.PLAN_DTE
					  , RE_ESTB_YN		 = SRC.RE_ESTB_YN
					  , MODIFY_BY        = @P_USER_ID		  
                      , MODIFY_DTTM      = GETDATE();

		END;

	IF NOT EXISTS (SELECT 1 FROM TB_SKC_FP_RE_ESTB WHERE PLAN_SCOPE = 'FP-CHDM' AND VERSION_CD = @P_FP_VERSION)
		BEGIN
			INSERT INTO TB_SKC_FP_RE_ESTB (PLAN_SCOPE, VERSION_CD, CORP_CD, PLNT_CD, RSRC_CD, PLAN_DTE, RE_ESTB_YN, CREATE_BY, CREATE_DTTM)
			SELECT 'FP-CHDM' AS PLAN_SCOPE
				 , VERSION AS VERSION_CD
				 , '1000' AS CORP_CD
				 , '1130' AS PLNT_CD
				 , RSRC_CD
				 , NULL AS PLAN_DTE
				 , 'N' AS RE_ESTB_YN
				 , 'SCM System'
				 , GETDATE()
	 	 	  FROM VW_FP_PLAN_VERSION A
			 CROSS JOIN (SELECT DISTINCT RSRC_CD, RSRC_NM FROM TB_SKC_FP_RSRC_MST WHERE PLNT_CD = '1130' AND ATTR_01 = '12') B
			 WHERE PLAN_SCOPE = 'FP-CHDM'
  			   AND VERSION = @P_FP_VERSION;

			MERGE INTO TB_SKC_FP_RE_ESTB AS TGT
             USING (
                     SELECT @P_FP_VERSION            AS VERSION_CD
                          , @P_RSRC_CD               AS RSRC_CD         -- LINE    (KEY)
						  , @v_PLAN_DTE				 AS PLAN_DTE		-- 일자    (KEY)
						  , @P_RE_ESTB_YN			 AS RE_ESTB_YN

                   ) AS SRC
                ON (     TGT.VERSION_CD    = SRC.VERSION_CD 
					 AND TGT.RSRC_CD       = SRC.RSRC_CD
                   )				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET PLAN_DTE  	     = SRC.PLAN_DTE
					  , RE_ESTB_YN		 = SRC.RE_ESTB_YN
					  , MODIFY_BY        = @P_USER_ID		  
                      , MODIFY_DTTM      = GETDATE();
			   
		END;

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
END
GO
