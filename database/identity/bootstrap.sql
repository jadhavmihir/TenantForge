-- run once against master as an admin. migrations assume this database exists.

IF DB_ID(N'TenantForge_Identity') IS NULL
    CREATE DATABASE TenantForge_Identity;
GO

-- readers get the last committed version of a row instead of waiting on writers
ALTER DATABASE TenantForge_Identity SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
