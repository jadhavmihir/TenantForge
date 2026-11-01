-- outbox rows are never edited. deleting old ones (retention) is allowed.
CREATE OR ALTER TRIGGER sync.trg_Outbox_NoUpdate
ON sync.Outbox
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50002, N'sync.Outbox rows are immutable.', 1;
END
GO
