-- schemas. CREATE SCHEMA has to be alone in its batch, hence the EXEC.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'iam')
    EXEC (N'CREATE SCHEMA iam');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'audit')
    EXEC (N'CREATE SCHEMA audit');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sync')
    EXEC (N'CREATE SCHEMA sync');
GO
