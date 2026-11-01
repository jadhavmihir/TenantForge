-- audit rows can be added, never changed or removed
-- (the DENY in 0008 is the first layer, this is the second)
CREATE OR ALTER TRIGGER audit.trg_AuditLog_Immutable
ON audit.AuditLog
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50001, N'audit.AuditLog is append-only.', 1;
END
GO
