-- Identity database bootstrap.
-- Run ONCE, connected to master, as an administrator. This is not a numbered migration.
-- Migrations (database/identity/migrations) assume this database already exists.

IF DB_ID(N'TenantForge_Identity') IS NULL
    CREATE DATABASE TenantForge_Identity;
GO

-- Readers see the last committed row version instead of waiting on writers.
ALTER DATABASE TenantForge_Identity SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
