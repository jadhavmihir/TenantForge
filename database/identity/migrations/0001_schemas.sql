-- 0001: schemas. Safe to run more than once.
-- CREATE SCHEMA must be the only statement in its batch, hence EXEC inside the IF.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'iam')
    EXEC (N'CREATE SCHEMA iam');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'audit')
    EXEC (N'CREATE SCHEMA audit');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sync')
    EXEC (N'CREATE SCHEMA sync');
GO
