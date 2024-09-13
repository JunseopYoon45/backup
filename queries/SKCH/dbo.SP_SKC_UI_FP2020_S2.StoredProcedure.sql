USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_S2]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_S2
-- COPYRIGHT       : ZIONEX
-- REMARK          : DMT 생산계획 수정 (GRID 2)

/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_S2] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_FP_VERSION                     NVARCHAR(100)                         -- Version
	, @P_PLAN_DTE						NVARCHAR(8)    = NULL
	, @P_ITEM_CD                        NVARCHAR(10)   = NULL		 	
	, @P_PRDT_PLAN_QTY                  FLOAT		   = NULL		
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_S2' ORDER BY LOG_KEY_SEQ DESC
EXEC SP_SKC_UI_FP2020_S2 'U','FP-20240805-DM-14','20240813','104600','100','I23768','UI_FP2020'


*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000) =''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''
	  , @P_ADJ_MIN_QTY NUMERIC(16,6) = 0 

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE            ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION           ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLAN_DTE             ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ITEM_CD              ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PRDT_PLAN_QTY        ),'')    -- 
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID              ),'')    -- LOGIN_ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID              ),'')    -- VIEW_ID
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;




SET @P_PRDT_PLAN_QTY = @P_PRDT_PLAN_QTY*1000




---------- LOG END ----------
BEGIN

    BEGIN TRY
        IF @P_WORK_TYPE IN ('U')
        BEGIN

    -----------------------------------
    -- 저장
    -----------------------------------


        
             MERGE INTO TB_SKC_FP_RS_PRDT_PLAN_DM AS TGT
             USING (
                     SELECT  DISTINCT VER_ID            AS VER_ID
					      ,  (SELECT MAX(PLNT_CD) FROM TB_SKC_FP_RSRC_MST WHERE ATTR_01 ='27') AS PLNT_CD
						  ,  'PRDT'                     AS PLAN_TYPE_CD
                          ,  '104600'                   AS ITEM_CD         
						  ,  PLAN_DTE                   AS CALD_DATE_ID		-- 일자    (KEY)
						  ,  @P_PRDT_PLAN_QTY           AS PRDT_PLAN_QTY	
                       FROM  TB_SKC_FP_RS_PRDT_PLAN_DM
                      WHERE  VER_ID   = @P_FP_VERSION
					    AND  PLAN_DTE = @P_PLAN_DTE
                      GROUP  BY VER_ID
					      ,  PLAN_DTE
                   ) AS SRC
                ON (     TGT.VER_ID        = SRC.VER_ID  
				     AND TGT.PLNT_CD       = SRC.PLNT_CD
					 AND TGT.ITEM_CD       = SRC.ITEM_CD
					 AND TGT.PLAN_DTE      = SRC.CALD_DATE_ID
                   )				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET ADJ_PLAN_QTY  	 = SRC.PRDT_PLAN_QTY
					  , PLAN_QTY  	      = SRC.PRDT_PLAN_QTY
					  , MODIFY_BY        = @P_USER_ID		  
                      , MODIFY_DTTM      = GETDATE() 
             WHEN NOT MATCHED THEN
			 INSERT
			      (  VER_ID
				  ,  PLNT_CD
				  ,  PLAN_TYPE_CD
				  ,  ITEM_CD
				  ,  PLAN_DTE
				  ,  PLAN_QTY
				  ,  ADJ_PLAN_QTY
				  ,  CREATE_BY
				  ,  CREATE_DTTM
				  )
             VALUES
			      (  SRC.VER_ID
				  ,  SRC.PLNT_CD
				  ,  SRC.PLAN_TYPE_CD
				  ,  SRC.ITEM_CD
				  ,  SRC.CALD_DATE_ID
				  ,  SRC.PRDT_PLAN_QTY
				  ,  SRC.PRDT_PLAN_QTY
				  ,  @P_USER_ID
				  ,  GETDATE() 
				  );
	   
	   
	   ;

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
