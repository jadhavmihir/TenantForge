-- audit trigger for iam.RolePermissions. tenant id comes from the role, null for system roles.
CREATE OR ALTER TRIGGER iam.trg_RolePermissions_Audit
ON iam.RolePermissions
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    IF @@ROWCOUNT = 0 RETURN;
    SET NOCOUNT ON;

    DECLARE @actor bigint           = TRY_CAST(SESSION_CONTEXT(N'actor_user_id') AS bigint);
    DECLARE @corr  uniqueidentifier = TRY_CAST(SESSION_CONTEXT(N'correlation_id') AS uniqueidentifier);
    DECLARE @ip    varchar(45)      = TRY_CAST(SESSION_CONTEXT(N'ip') AS varchar(45));

    INSERT audit.AuditLog (TenantId, ActorUserId, Action, EntityType, EntityId, OldValues, NewValues, CorrelationId, Ip)
    SELECT r.TenantId,
           @actor,
           CASE WHEN d.RoleId IS NULL THEN 'INSERT'
                WHEN i.RoleId IS NULL THEN 'DELETE'
                ELSE 'UPDATE' END,
           'iam.RolePermissions',
           CONCAT(COALESCE(i.RoleId, d.RoleId), ':', COALESCE(i.PermissionId, d.PermissionId)),
           j.OldJson,
           j.NewJson,
           @corr,
           @ip
      FROM inserted AS i
      FULL OUTER JOIN deleted AS d ON d.RoleId = i.RoleId AND d.PermissionId = i.PermissionId
      LEFT JOIN iam.Roles AS r ON r.RoleId = COALESCE(i.RoleId, d.RoleId)
      CROSS APPLY
      (
          SELECT
              OldJson = CASE WHEN d.RoleId IS NULL THEN NULL ELSE
                  (SELECT d.RoleId, d.PermissionId, d.GrantedAt, d.GrantedBy
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
              NewJson = CASE WHEN i.RoleId IS NULL THEN NULL ELSE
                  (SELECT i.RoleId, i.PermissionId, i.GrantedAt, i.GrantedBy
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
      ) AS j
     WHERE j.OldJson IS NULL OR j.NewJson IS NULL OR j.OldJson <> j.NewJson;
END
GO
