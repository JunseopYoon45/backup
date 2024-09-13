USE [T3SMARTSCM_NEW]
GO
/****** Object:  StoredProcedure [dbo].[SP_UI_DP_00_POPUP_USER_Q1]    Script Date: 2024-09-13 오후 3:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*****************************************************************************
Title : [SP_DP_00_POPUP_USER_Q1]
최초 작성자 : 민희영
최초 생성일 : 2017.06.21
 
설명
 - DP USER POPUP 조회 프로시저
  
History (수정일자 / 수정자 / 수정내용)
- 2017.06.21 / 민희영 / 최초 작성
- 2018.05.29 / 박민정 / Delegation 추가
- 2018.10.15 / 김소희 / DEPARTMENT 추가 및 대소문자 구분 없이 검색 가능하게 UPPER 처리
- 2019.06.20 / 김소희 / Employee 활성화 여부 체크하고 데이터 가져오기
- 2020.03.11 / 김소희 / User ID 추가
- 2020.06.05 / hanguls / USER_ID => USERNAME
- 2020.06.29 / kimsohee / Delegation 테이블명 변경으로 인해 컬럼명도 변경
- 2020.09.22 /hanguls TB_DP_EMPLOYEE => TB_AD_USER
- 2021.04.13 /hanguls ADMIN 권한체크로 모든 delegation 처리여부 결정
- 2023.04.05 /hanguls ADMIN 권한인 경우 DP user 분리 옵션 추가
- 2024.04-03 /Kim Sung Yong email 컬럼추가
*****************************************************************************/

CREATE PROCEDURE [dbo].[SP_UI_DP_00_POPUP_USER_Q1]  (@p_EMP_NO    NVARCHAR(30)   = ''
                                                  ,@p_EMP_NM     NVARCHAR(240) = ''
												  ,@p_CHECK_DP   NVARCHAR(30) = ''
												  ,@p_USER_ID    NVARCHAR(50)   = ''
) AS
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
DECLARE   @V_AUTHORITY	INT = ''


select @V_AUTHORITY = count(AUTHORITY) from TB_AD_AUTHORITY a
inner join TB_AD_USER u  on a.user_id = u.id and AUTHORITY = 'ADMIN' and u.USERNAME = @p_USER_ID

IF (@V_AUTHORITY > 0 or @P_USER_ID = 'LOGIN_ID_IGNORE_ALL_LOAD')

	BEGIN

	if (@p_CHECK_DP = 'DP')
		BEGIN
			with DP_USER as (
				select distinct EMP_ID from TB_DP_USER_ACCOUNT_MAP
				union
				select distinct EMP_ID from TB_DP_USER_ITEM_MAP
				union
				select distinct EMP_ID from TB_DP_USER_ITEM_ACCOUNT_MAP
				union
				select distinct EMP_ID from TB_DP_SALES_AUTH_MAP
			)
			SELECT	DISTINCT
					US.ID
				  , US.USERNAME 		AS EMP_NO
				  , US.USERNAME 		AS USER_ID
				  , US.DISPLAY_NAME   	AS EMP_NM
				  , US.DEPARTMENT 		AS DEPT_NM
				  , US.EMAIL      		AS EMAIL
			FROM	TB_AD_USER US
			--INNER JOIN DP_USER on DP_USER.EMP_ID = US.ID
			INNER JOIN DP_USER on DP_USER.EMP_ID = US.USERNAME
			WHERE	UPPER(US.USERNAME) LIKE '%' + UPPER(@P_EMP_NO) + '%'
			AND	   (ISNULL(UPPER(US.DISPLAY_NAME),'')  LIKE '%' + UPPER(@P_EMP_NM) +'%' OR ISNULL(@P_EMP_NM,'')='')
		   ORDER BY US.USERNAME ;
	    END
	ELSE
		BEGIN
			SELECT	DISTINCT
					US.ID
				  , US.USERNAME AS EMP_NO
				  , US.USERNAME AS USER_ID
				  , US.DISPLAY_NAME   AS EMP_NM
				  , US.DEPARTMENT AS DEPT_NM
				  , US.EMAIL      		AS EMAIL
			FROM	TB_AD_USER US
			WHERE	UPPER(US.USERNAME) LIKE '%' + UPPER(@P_EMP_NO) + '%'
			AND	   (ISNULL(UPPER(US.DISPLAY_NAME),'')  LIKE '%' + UPPER(@P_EMP_NM) +'%' OR ISNULL(@P_EMP_NM,'')='')
		   ORDER BY US.USERNAME ;
	   END
	END

ELSE

	BEGIN

	WITH DELEGATION
	 AS (
		  SELECT DG.USER_ID AS ID
		   FROM TB_AD_DELEGATION DG
				INNER JOIN
				TB_AD_USER US
			 ON DG.DELEGATION_USER_ID = US.ID
		  WHERE US.USERNAME = @p_USER_ID
			AND COALESCE(DG.APPLY_START_DTTM, GETDATE()) <= GETDATE()
			AND COALESCE(DG.APPLY_END_DTTM, DATEADD(DAY,1,GETDATE())) > GETDATE()
		  UNION
		  SELECT ID
			FROM TB_AD_USER
		  WHERE USERNAME = @p_USER_ID
		  UNION -- 24.08.27 팀장은 하위 팀원들도 조회할 수 있도록 수정
		  SELECT ID
		    FROM TB_AD_USER
		  WHERE USERNAME IN (SELECT DISTINCT DESC_ID FROM TB_DPD_USER_HIER_CLOSURE WHERE ANCS_ID = @P_USER_ID AND MAPPING_SELF_YN = 'Y')
		)

	SELECT	US.ID
 	 	  , US.USERNAME AS EMP_NO
 	 	  , US.USERNAME AS USER_ID
 	 	  , US.DISPLAY_NAME AS EMP_NM
 	 	  , US.DEPARTMENT AS DEPT_NM
 	 FROM	TB_AD_USER US
 	 	    INNER JOIN
 	 		DELEGATION DG
 	 	ON  US.ID = DG.ID
 	 AND	UPPER(US.USERNAME) LIKE '%' + UPPER(@P_EMP_NO) + '%'
 	 AND	ISNULL(UPPER(US.DISPLAY_NAME),'')  LIKE '%' + UPPER(@P_EMP_NM) +'%'
 	 ORDER BY US.USERNAME ;

--	SELECT	US.ID
--			  , US.USERNAME AS EMP_NO
--			  , US.USERNAME AS USER_ID
--			  , US.DISPLAY_NAME AS EMP_NM
--			  , US.DEPARTMENT AS DEPT_NM
--		FROM	TB_AD_USER US
--		WHERE	 ID IN  (SELECT DEL.USER_ID
--								  FROM TB_AD_DELEGATION DEL
--								  INNER JOIN TB_AD_USER U on U.Id = DEL.DELEGATION_USER_ID
--								 WHERE U.USERNAME = @P_USER_ID
--								 AND	(
--											(DEL.APPLY_START_DTTM <= GETDATE() AND DEL.APPLY_END_DTTM > GETDATE())
--										 OR (DEL.APPLY_START_DTTM IS NULL AND DEL.APPLY_END_DTTM > GETDATE())
--										 OR (DEL.APPLY_START_DTTM <= GETDATE() AND DEL.APPLY_END_DTTM IS NULL)
--										 OR (DEL.APPLY_START_DTTM IS NULL AND DEL.APPLY_END_DTTM IS NULL)
--										)
--								 UNION
--								 SELECT @P_USER_ID
--								)
--		AND	UPPER(US.USERNAME) LIKE '%' + UPPER(@P_EMP_NO) + '%'
--		AND	ISNULL(UPPER(US.DISPLAY_NAME),'')  LIKE '%' + UPPER(@P_EMP_NM) +'%'
--		ORDER BY US.USERNAME ;

	END
GO
