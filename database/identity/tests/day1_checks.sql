-- Self-checking tests for the identity schema (migrations 0001 to 0009).
-- Run against TenantForge_Identity, then read the Messages tab in SSMS. Every line should start with PASS.
-- Each test runs inside its own transaction and rolls back, so no data (and no audit rows) is left behind.
-- Test names starting with "expect error" prove that the database refuses something it must refuse.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- T01 expect error: tenant slug must be lowercase
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('Acme', N'Acme', @pool);
    ROLLBACK;
    PRINT 'FAIL T01: an uppercase slug was accepted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%CK_Tenants_Slug%' THEN 'PASS T01: slug must be lowercase'
               ELSE 'FAIL T01: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T02 expect error: a pool cannot hold more tenants than its maximum
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants, CurrentTenants)
    VALUES (N'chk-pool', 'Pooled', 'ChkPool', 1, 5);
    ROLLBACK;
    PRINT 'FAIL T02: an over-full pool was accepted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%CK_TenantPools_Current%' THEN 'PASS T02: pool capacity is enforced'
               ELSE 'FAIL T02: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T03 expect error: same email twice in one tenant (case and spaces ignored)
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    DECLARE @t int = SCOPE_IDENTITY();
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t, N'chk-t03@example.test', N'First');
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t, N'  CHK-T03@Example.Test ', N'Second');
    ROLLBACK;
    PRINT 'FAIL T03: a duplicate email was accepted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%UX_Users_Tenant_Email%' THEN 'PASS T03: email is unique per tenant'
               ELSE 'FAIL T03: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T04 same email is allowed in another tenant, and again after a soft delete
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    DECLARE @t1 int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('globex', N'Globex', @pool);
    DECLARE @t2 int = SCOPE_IDENTITY();
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t1, N'chk-t04@example.test', N'A');
    DECLARE @u bigint = SCOPE_IDENTITY();
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t2, N'chk-t04@example.test', N'A');
    DELETE FROM iam.Users WHERE UserId = @u;
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t1, N'chk-t04@example.test', N'A');
    DECLARE @n int = (SELECT COUNT(*) FROM iam.Users WHERE EmailNormalized = N'chk-t04@example.test');
    DECLARE @soft int = (SELECT COUNT(*) FROM iam.Users WHERE UserId = @u AND IsDeleted = 1);
    ROLLBACK;
    PRINT CASE WHEN @n = 3 AND @soft = 1 THEN 'PASS T04: email reuse across tenants and after soft delete works'
               ELSE 'FAIL T04: expected 3 rows and 1 soft-deleted, got ' + CONVERT(varchar(10), @n) + ' and ' + CONVERT(varchar(10), @soft) END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT 'FAIL T04: ' + ERROR_MESSAGE();
END CATCH
GO

-- T05 expect error: only one active signing key
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.SigningKeys (Kid, PublicKey, PrivateKeyProtected, Status) VALUES ('chk-k1', N'pub', 0x01, 'Active');
    INSERT iam.SigningKeys (Kid, PublicKey, PrivateKeyProtected, Status) VALUES ('chk-k2', N'pub', 0x01, 'Active');
    ROLLBACK;
    PRINT 'FAIL T05: two active signing keys were accepted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%UX_SigningKeys_OneActive%' THEN 'PASS T05: only one active signing key'
               ELSE 'FAIL T05: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T06 expect error: duplicate system role name (needs migration 0008)
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.Roles (TenantId, Name, IsSystem) VALUES (NULL, N'TenantAdmin', 1);
    ROLLBACK;
    PRINT 'FAIL T06: a duplicate system role was accepted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%UX_Roles_Tenant_Name%' THEN 'PASS T06: system role names are unique'
               ELSE 'FAIL T06: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T07 expect error: the audit log cannot be updated
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    UPDATE audit.AuditLog SET Action = 'TAMPERED' WHERE AuditId = (SELECT MAX(AuditId) FROM audit.AuditLog);
    ROLLBACK;
    PRINT 'FAIL T07: an audit row was updated';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%append-only%' THEN 'PASS T07: audit log cannot be updated'
               ELSE 'FAIL T07: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T08 expect error: the audit log cannot be deleted from
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    DELETE FROM audit.AuditLog WHERE AuditId = (SELECT MAX(AuditId) FROM audit.AuditLog);
    ROLLBACK;
    PRINT 'FAIL T08: an audit row was deleted';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CASE WHEN ERROR_MESSAGE() LIKE '%append-only%' THEN 'PASS T08: audit log cannot be deleted from'
               ELSE 'FAIL T08: wrong error: ' + ERROR_MESSAGE() END;
END CATCH
GO

-- T09 a DELETE on a user becomes a soft delete, and both changes are audited
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    DECLARE @t int = SCOPE_IDENTITY();
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t, N'chk-t09@example.test', N'Nine');
    DECLARE @u bigint = SCOPE_IDENTITY();
    DELETE FROM iam.Users WHERE UserId = @u;
    DECLARE @stillThere int = (SELECT COUNT(*) FROM iam.Users WHERE UserId = @u AND IsDeleted = 1);
    DECLARE @ins int = (SELECT COUNT(*) FROM audit.AuditLog WHERE EntityType = 'iam.Users' AND EntityId = CONVERT(varchar(100), @u) AND Action = 'INSERT');
    DECLARE @soft int = (SELECT COUNT(*) FROM audit.AuditLog WHERE EntityType = 'iam.Users' AND EntityId = CONVERT(varchar(100), @u) AND Action = 'SOFT_DELETE');
    ROLLBACK;
    PRINT CASE WHEN @stillThere = 1 AND @ins = 1 AND @soft = 1 THEN 'PASS T09: soft delete works and is audited'
               ELSE 'FAIL T09: soft-deleted rows=' + CONVERT(varchar(10), @stillThere) + ', INSERT audits=' + CONVERT(varchar(10), @ins) + ', SOFT_DELETE audits=' + CONVERT(varchar(10), @soft) END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT 'FAIL T09: ' + ERROR_MESSAGE();
END CATCH
GO

-- T10 the audit row records the acting user from SESSION_CONTEXT
BEGIN TRY
    BEGIN TRAN;
    INSERT iam.TenantPools (Name, Tier, ConnectionAlias, MaxTenants) VALUES (N'chk-pool', 'Pooled', 'ChkPool', 10);
    DECLARE @pool int = SCOPE_IDENTITY();
    INSERT iam.Tenants (Slug, Name, PoolId) VALUES ('acme', N'Acme', @pool);
    DECLARE @t int = SCOPE_IDENTITY();
    INSERT iam.Users (TenantId, Email, DisplayName) VALUES (@t, N'chk-t10@example.test', N'Ten');
    DECLARE @u bigint = SCOPE_IDENTITY();
    EXEC sp_set_session_context N'actor_user_id', 42;
    UPDATE iam.Users SET DisplayName = N'Ten (edited)', Version = Version + 1 WHERE UserId = @u;
    DECLARE @hit int = (SELECT COUNT(*) FROM audit.AuditLog WHERE EntityType = 'iam.Users' AND EntityId = CONVERT(varchar(100), @u) AND Action = 'UPDATE' AND ActorUserId = 42);
    EXEC sp_set_session_context N'actor_user_id', NULL;
    ROLLBACK;
    PRINT CASE WHEN @hit = 1 THEN 'PASS T10: audit captures the acting user'
               ELSE 'FAIL T10: expected 1 audit row with actor 42, got ' + CONVERT(varchar(10), @hit) END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC sp_set_session_context N'actor_user_id', NULL;
    PRINT 'FAIL T10: ' + ERROR_MESSAGE();
END CATCH
GO

-- T11 credentials are never audited: there must be no trigger on iam.UserCredentials
IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE parent_id = OBJECT_ID(N'iam.UserCredentials'))
    PRINT 'PASS T11: no audit trigger on iam.UserCredentials, so hashes never reach the audit log';
ELSE
    PRINT 'FAIL T11: a trigger exists on iam.UserCredentials';
GO

-- T12 reference data is present (needs migration 0008)
DECLARE @perms int = (SELECT COUNT(*) FROM iam.Permissions);
DECLARE @roles int = (SELECT COUNT(*) FROM iam.Roles WHERE IsSystem = 1 AND TenantId IS NULL);
DECLARE @adminPerms int = (SELECT COUNT(*) FROM iam.RolePermissions rp JOIN iam.Roles r ON r.RoleId = rp.RoleId WHERE r.Name = N'TenantAdmin' AND r.TenantId IS NULL);
PRINT CASE WHEN @perms = 12 AND @roles = 4 AND @adminPerms = 10 THEN 'PASS T12: 12 permissions, 4 system roles, TenantAdmin has 10 permissions'
           ELSE 'FAIL T12: permissions=' + CONVERT(varchar(10), @perms) + ', system roles=' + CONVERT(varchar(10), @roles) + ', TenantAdmin permissions=' + CONVERT(varchar(10), @adminPerms) END;
GO
