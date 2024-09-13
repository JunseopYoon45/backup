USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2010_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2010_S1
-- COPYRIGHT       : ZIONEX
-- REMARK          : CHDM 생산계획 수정

/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2010_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_FP_VERSION                     NVARCHAR(100)                         -- Version
	, @P_PLAN_DTE						NVARCHAR(8)    = NULL
	, @P_RSRC_CD                        NVARCHAR(10)   = NULL		 	
	, @P_ADJ_OPER_RATE                  FLOAT		   = 0		
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2010_S1' ORDER BY LOG_KEY_SEQ DESC
EXEC SP_SKC_UI_FP2010_S1 'U', '', '20240523', 'CDP-1', '78', 'SYSTEM', 'UI_FP2010'
EXEC SP_SKC_UI_FP2010_S1 'U', '', '20240602', 'CDP-1', '86', 'SYSTEM', 'UI_FP2010'
*/
DECLARE @P_ERR_STATUS INT = 0
      , @P_ERR_MSG    NVARCHAR(4000) =''

DECLARE @P_PGM_NM     NVARCHAR(100)  = ''
      , @PARM_DESC    NVARCHAR(1000) = ''

    SET @P_PGM_NM  = OBJECT_NAME(@@PROCID);
    SET @PARM_DESC =    '''' + ISNULL(CONVERT(VARCHAR(100), @P_WORK_TYPE            ),'')    -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_FP_VERSION           ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_PLAN_DTE             ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_RSRC_CD              ),'')    -- 
				   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_ADJ_OPER_RATE        ),'')    -- 
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_USER_ID              ),'')    -- LOGIN_ID
                   + ''',''' + ISNULL(CONVERT(VARCHAR(100), @P_VIEW_ID              ),'')    -- VIEW_ID
                   + ''''

  EXEC T3SMARTSCM_NEW.DBO.SP_PGM_LOG  'FP',@P_PGM_NM, NULL, NULL, @PARM_DESC, @P_USER_ID ;

---------- LOG END ----------
BEGIN


		IF( @P_ADJ_OPER_RATE < 0 OR  @P_ADJ_OPER_RATE > 100) 
		BEGIN
			SET @P_RT_ROLLBACK_FLAG = 'FALSE';
			--SET @P_RT_MSG           = 'MSG_SKC_036';  --외부판매 생산계획보다 수량이 작습니다. 조정바랍니다.
    		SET @P_RT_MSG           = 'MSG_SKC_036';  --외부판매 생산계획보다 수량이 작습니다. 조정바랍니다.
		RETURN	
		END



    BEGIN TRY
        IF @P_WORK_TYPE IN ('U')
        BEGIN

    -----------------------------------
    -- 저장
    -----------------------------------
	--SELECT MAX_CAPA_QTY FROM TB_SKC_FP_RSRC_MST
	--SELECT * FROM TB_SKC_FP_RS_PRDT_PLAN_CH
        
             MERGE INTO TB_SKC_FP_RS_PRDT_PLAN_CH AS TGT
             USING (
                     SELECT @P_FP_VERSION            AS VER_ID
                          , @P_RSRC_CD               AS RSRC_CD         -- LINE    (KEY)
						  , @P_PLAN_DTE				 AS PLAN_DTE		-- 일자    (KEY)
						  , @P_ADJ_OPER_RATE/100     AS ADJ_OPER_RATE	-- 가동률
                          , (@P_ADJ_OPER_RATE/100) * (SELECT ISNULL(MAX(MAX_CAPA_QTY),0) FROM TB_SKC_FP_RSRC_MST WHERE RSRC_CD = @P_RSRC_CD)*1000  AS ADJ_PLAN_QTY

                   ) AS SRC
                ON (     TGT.VER_ID        = SRC.VER_ID 
					 AND TGT.RSRC_CD       = SRC.RSRC_CD
					 AND TGT.PLAN_DTE	   = SRC.PLAN_DTE
                   )				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET ADJ_OPER_RATE  	 = SRC.ADJ_OPER_RATE  
					  , ADJ_PLAN_QTY	 = SRC.ADJ_PLAN_QTY
					  , MODIFY_BY        = @P_USER_ID		  
                      , MODIFY_DTTM      = GETDATE() 
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
