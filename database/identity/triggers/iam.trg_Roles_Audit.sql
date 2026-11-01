-- audit trigger for iam.Roles
CREATE OR ALTER TRIGGER iam.trg_Roles_Audit
ON iam.Roles
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    IF @@ROWCOUNT = 0 RETURN;
    SET NOCOUNT ON;

    DECLARE @actor bigint           = TRY_CAST(SESSION_CONTEXT(N'actor_user_id') AS bigint);
    DECLARE @corr  uniqueidentifier = TRY_CAST(SESSION_CONTEXT(N'correlation_id') AS uniqueidentifier);
    DECLARE @ip    varchar(45)      = TRY_CAST(SESSION_CONTEXT(N'ip') AS varchar(45));

    INSERT audit.AuditLog (TenantId, ActorUserId, Action, EntityType, EntityId, OldValues, NewValues, CorrelationId, Ip)
    SELECT COALESCE(i.TenantId, d.TenantId),
           @actor,
           CASE WHEN d.RoleId IS NULL THEN 'INSERT'
                WHEN i.RoleId IS NULL THEN 'DELETE'
                ELSE 'UPDATE' END,
           'iam.Roles',
           CONVERT(varchar(100), COALESCE(i.RoleId, d.RoleId)),
           j.OldJson,
           j.NewJson,
           @corr,
           @ip
      FROM inserted AS i
      FULL OUTER JOIN deleted AS d ON d.RoleId = i.RoleId
      CROSS APPLY
      (
          SELECT
              OldJson = CASE WHEN d.RoleId IS NULL THEN NULL ELSE
                  (SELECT d.RoleId, d.TenantId, d.Name, d.IsSystem, d.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
              NewJson = CASE WHEN i.RoleId IS NULL THEN NULL ELSE
                  (SELECT i.RoleId, i.TenantId, i.Name, i.IsSystem, i.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
      ) AS j
     WHERE j.OldJson IS NULL OR j.NewJson IS NULL OR j.OldJson <> j.NewJson;
END
GO
