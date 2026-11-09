-- creates a tenant in the first pooled database that still has room.
-- the seat is taken with one UPDATE, so two sign-ups at the same moment can't both get the last seat.
-- XACT_ABORT makes any error undo everything, including the seat count.

CREATE OR ALTER PROCEDURE iam.Tenant_Create
    @Slug varchar(63),
    @Name nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @claimed TABLE (PoolId int NOT NULL);
    DECLARE @tenantId int;

    BEGIN TRANSACTION;

    WITH pick AS
    (
        SELECT TOP (1) PoolId, CurrentTenants
        FROM iam.TenantPools WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE Tier = 'Pooled'
          AND Status = 'Active'
          AND CurrentTenants < MaxTenants
        ORDER BY PoolId
    )
    UPDATE pick
    SET CurrentTenants = CurrentTenants + 1
    OUTPUT inserted.PoolId INTO @claimed (PoolId);

    IF NOT EXISTS (SELECT 1 FROM @claimed)
        THROW 50001, 'No pool has room for another tenant.', 1;

    INSERT INTO iam.Tenants (Slug, Name, PoolId)
    SELECT @Slug, @Name, PoolId
    FROM @claimed;

    SET @tenantId = SCOPE_IDENTITY();

    COMMIT TRANSACTION;

    SELECT t.TenantId,
           t.PublicId,
           t.Slug,
           t.Name,
           t.PoolId,
           p.ConnectionAlias
    FROM iam.Tenants AS t
    JOIN iam.TenantPools AS p ON p.PoolId = t.PoolId
    WHERE t.TenantId = @tenantId;
END
GO
