USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_SKC_UI_FP2020_S1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- PROCEDURE NAME  : SP_SKC_UI_FP2020_S1
-- COPYRIGHT       : ZIONEX
-- REMARK          : DMT 생산계획 수정 (GRID 1)

/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
-- DATE        BY             MODIFICATION
-----------------------------------------------------------------------------------------------------------------------
-- 2024-07-22  ZIONEX         신규 생성
/*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^*********^********/
CREATE PROCEDURE [dbo].[SP_SKC_UI_FP2020_S1] (
      @P_WORK_TYPE                      NVARCHAR(10)                          -- 작업타입 (Q:조회, N:신규, U:수정, D:삭제)
    , @P_FP_VERSION                     NVARCHAR(100)                         -- Version
	, @P_PLAN_DTE						NVARCHAR(8)    = NULL
	, @P_ITEM_CD                        NVARCHAR(10)   = NULL		 	
	, @P_PRDT_PLAN_QTY                  FLOAT		   = 0		
    , @P_USER_ID                        NVARCHAR(100)                         -- LOGIN_ID
    , @P_VIEW_ID                        NVARCHAR(100)  = NULL                 -- VIEW_ID
    , @P_RT_ROLLBACK_FLAG               NVARCHAR(10)   = 'TRUE'  OUTPUT
    , @P_RT_MSG                         NVARCHAR(4000) = ''      OUTPUT
    )
AS
SET NOCOUNT ON
---------- LOG START ----------
/*
SELECT * FROM TB_PGM_LOG WHERE PGM_NM = 'SP_SKC_UI_FP2020_S1' ORDER BY LOG_KEY_SEQ DESC

EXEC SP_SKC_UI_FP2020_S1 'U','FP-20240806-DM-02','20240812','104601','50','I23768','UI_FP2020'

EXEC SP_SKC_UI_FP2020_S1 'U', '', '20240801', '104601', '100', 'SCM System', 'UI_FP2020'

*/
DECLARE @P_ERR_STATUS    INT = 0
      , @P_ERR_MSG       NVARCHAR(4000) =''

DECLARE @P_PGM_NM        NVARCHAR(100)  = ''
      , @PARM_DESC       NVARCHAR(1000) = ''
	  
	  , @P_MAX_CAPA_QTY  NUMERIC(16,6)  = 0
	  , @P_FB_CAPA_QTY   NUMERIC(16,6)  = 0


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



	    SELECT  @P_MAX_CAPA_QTY  = MAX(ISNULL(FB_MAX_CAPA_QTY,180)) * 1000
	      FROM  TB_SKC_FP_RSRC_MST
	     WHERE  ATTR_01 = '27'
           AND  SCM_USE_YN = 'Y'
           AND  SCM_CAPA_USE_YN = 'Y'

           
  
	    SELECT  @P_FB_CAPA_QTY = ISNULL(MAX(ISNULL(ADJ_PLAN_QTY,0)),0)
		  FROM  TB_SKC_FP_RS_PRDT_PLAN_DM A
		 WHERE  1=1
		   AND  PLAN_TYPE_CD  = 'DMND'
		   AND  EXISTS ( SELECT 1 FROM TB_CM_ITEM_MST B WHERE A.ITEM_CD = B.ITEM_CD AND ATTR_10 IN ( '27-A0310B3110C0830','27-A0310B3120C0840'))
		   AND  PLAN_DTE      = @P_PLAN_DTE
		   AND  VER_ID        = @P_FP_VERSION      
		   AND  ITEM_CD       <> @P_ITEM_CD
	


		IF( @P_MAX_CAPA_QTY <  (ISNULL(@P_FB_CAPA_QTY,0) + ISNULL(@P_PRDT_PLAN_QTY,0))) 
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

        
             MERGE INTO TB_SKC_FP_RS_PRDT_PLAN_DM AS TGT
             USING
			     (  SELECT  @P_FP_VERSION         AS  VER_ID
				         ,  (SELECT MAX(PLNT_CD) FROM TB_SKC_FP_RSRC_MST WHERE ATTR_01 ='27')
						                          AS  PLNT_CD
                         ,  'DMND'                AS  PLAN_TYPE_CD
				         ,  @P_PLAN_DTE           AS  CALD_DATE_ID
			             ,  @P_ITEM_CD            AS  ITEM_CD
						 ,  @P_PRDT_PLAN_QTY      AS  PLAN_QTY

                   ) AS SRC
                ON (     TGT.VER_ID        = SRC.VER_ID 
				     AND TGT.PLNT_CD       = SRC.PLNT_CD
					 AND TGT.ITEM_CD       = SRC.ITEM_CD
					 AND TGT.PLAN_TYPE_CD  = SRC.PLAN_TYPE_CD
					 AND TGT.PLAN_DTE      = SRC.CALD_DATE_ID
                   )				   
             WHEN  MATCHED THEN
			     UPDATE
				    SET ADJ_PLAN_QTY  	 = SRC.PLAN_QTY
					  , MODIFY_BY        = @P_USER_ID		  
                      , MODIFY_DTTM      = GETDATE() 
             WHEN  NOT MATCHED THEN
			 INSERT  
			    (  VER_ID
				,  PLNT_CD
				,  PLAN_TYPE_CD
				,  ITEM_CD
				,  PLAN_DTE
				,  PLAN_QTY
				,  ADJ_PLAN_QTY
				,  CREATE_BY
				,  CREATE_DTTM)
			 VALUES 
			    (  SRC.VER_ID
				,  SRC.PLNT_CD
				,  SRC.PLAN_TYPE_CD
				,  SRC.ITEM_CD
				,  SRC.PLAN_TYPE_CD
				,  SRC.PLAN_QTY
				,  SRC.PLAN_QTY
				,  @P_USER_ID
				,  GETDATE() 
				)

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
