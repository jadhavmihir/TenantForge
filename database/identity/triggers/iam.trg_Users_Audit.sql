-- audit trigger for iam.Users. same shape as the tenants one, plus SOFT_DELETE.
-- the password hash lives in UserCredentials and is deliberately not audited anywhere.
CREATE OR ALTER TRIGGER iam.trg_Users_Audit
ON iam.Users
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
           CASE WHEN d.UserId IS NULL THEN 'INSERT'
                WHEN i.UserId IS NULL THEN 'DELETE'
                WHEN d.IsDeleted = 0 AND i.IsDeleted = 1 THEN 'SOFT_DELETE'
                ELSE 'UPDATE' END,
           'iam.Users',
           CONVERT(varchar(100), COALESCE(i.UserId, d.UserId)),
           j.OldJson,
           j.NewJson,
           @corr,
           @ip
      FROM inserted AS i
      FULL OUTER JOIN deleted AS d ON d.UserId = i.UserId
      CROSS APPLY
      (
          SELECT
              OldJson = CASE WHEN d.UserId IS NULL THEN NULL ELSE
                  (SELECT d.UserId, d.TenantId, d.PublicId, d.Email, d.DisplayName, d.Status, d.IsDeleted, d.PermVersion, d.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
              NewJson = CASE WHEN i.UserId IS NULL THEN NULL ELSE
                  (SELECT i.UserId, i.TenantId, i.PublicId, i.Email, i.DisplayName, i.Status, i.IsDeleted, i.PermVersion, i.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
      ) AS j
     WHERE j.OldJson IS NULL OR j.NewJson IS NULL OR j.OldJson <> j.NewJson;
END
GO
