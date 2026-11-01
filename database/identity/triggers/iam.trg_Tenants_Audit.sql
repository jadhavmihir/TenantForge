-- audit trigger for iam.Tenants. actor, correlation id and ip come from SESSION_CONTEXT,
-- which the api sets per connection. they stay null for direct SQL.
CREATE OR ALTER TRIGGER iam.trg_Tenants_Audit
ON iam.Tenants
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
           CASE WHEN d.TenantId IS NULL THEN 'INSERT'
                WHEN i.TenantId IS NULL THEN 'DELETE'
                ELSE 'UPDATE' END,
           'iam.Tenants',
           CONVERT(varchar(100), COALESCE(i.TenantId, d.TenantId)),
           j.OldJson,
           j.NewJson,
           @corr,
           @ip
      FROM inserted AS i
      FULL OUTER JOIN deleted AS d ON d.TenantId = i.TenantId
      CROSS APPLY
      (
          SELECT
              OldJson = CASE WHEN d.TenantId IS NULL THEN NULL ELSE
                  (SELECT d.TenantId, d.PublicId, d.Slug, d.Name, d.Status, d.PoolId, d.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
              NewJson = CASE WHEN i.TenantId IS NULL THEN NULL ELSE
                  (SELECT i.TenantId, i.PublicId, i.Slug, i.Name, i.Status, i.PoolId, i.Version
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
      ) AS j
     WHERE j.OldJson IS NULL OR j.NewJson IS NULL OR j.OldJson <> j.NewJson;   -- skip updates that changed nothing we track
END
GO
