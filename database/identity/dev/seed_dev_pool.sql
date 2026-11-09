-- one small pool for local testing. MaxTenants is 3 on purpose, so a full pool is easy to reach.
-- dev only, never run against a shared server.

USE TenantForge_Identity;
GO

IF NOT EXISTS (SELECT 1 FROM iam.TenantPools WHERE Name = N'Pool01')
    INSERT INTO iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants)
    VALUES (N'Pool01', 'Pooled', 'Pool01', 3);
GO
