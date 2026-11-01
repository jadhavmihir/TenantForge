-- audit trigger for iam.UserRoles. the table has no TenantId, so we take it from the user.
-- left join so an audit row is never dropped if the lookup misses.
CREATE OR ALTER TRIGGER iam.trg_UserRoles_Audit
ON iam.UserRoles
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    IF @@ROWCOUNT = 0 RETURN;
    SET NOCOUNT ON;

    DECLARE @actor bigint           = TRY_CAST(SESSION_CONTEXT(N'actor_user_id') AS bigint);
    DECLARE @corr  uniqueidentifier = TRY_CAST(SESSION_CONTEXT(N'correlation_id') AS uniqueidentifier);
    DECLARE @ip    varchar(45)      = TRY_CAST(SESSION_CONTEXT(N'ip') AS varchar(45));

    INSERT audit.AuditLog (TenantId, ActorUserId, Action, EntityType, EntityId, OldValues, NewValues, CorrelationId, Ip)
    SELECT u.TenantId,
           @actor,
           CASE WHEN d.UserId IS NULL THEN 'INSERT'
                WHEN i.UserId IS NULL THEN 'DELETE'
                ELSE 'UPDATE' END,
           'iam.UserRoles',
           CONCAT(COALESCE(i.UserId, d.UserId), ':', COALESCE(i.RoleId, d.RoleId)),
           j.OldJson,
           j.NewJson,
           @corr,
           @ip
      FROM inserted AS i
      FULL OUTER JOIN deleted AS d ON d.UserId = i.UserId AND d.RoleId = i.RoleId
      LEFT JOIN iam.Users AS u ON u.UserId = COALESCE(i.UserId, d.UserId)
      CROSS APPLY
      (
          SELECT
              OldJson = CASE WHEN d.UserId IS NULL THEN NULL ELSE
                  (SELECT d.UserId, d.RoleId, d.AssignedAt, d.AssignedBy
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
              NewJson = CASE WHEN i.UserId IS NULL THEN NULL ELSE
                  (SELECT i.UserId, i.RoleId, i.AssignedAt, i.AssignedBy
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
      ) AS j
     WHERE j.OldJson IS NULL OR j.NewJson IS NULL OR j.OldJson <> j.NewJson;
END
GO
