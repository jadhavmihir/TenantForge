-- dev only: throws the identity database away so you can rebuild it from the scripts.
-- run against master, then run bootstrap.sql, the migrations in order, and the triggers.
USE master;
GO

IF DB_ID(N'TenantForge_Identity') IS NOT NULL
BEGIN
    ALTER DATABASE TenantForge_Identity SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TenantForge_Identity;
END
GO
