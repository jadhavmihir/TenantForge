-- finds a tenant by its slug and says which pool it lives in. login uses this first.

CREATE OR ALTER PROCEDURE iam.Tenant_GetBySlug
    @Slug varchar(63)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT t.TenantId,
           t.PublicId,
           t.Slug,
           t.Name,
           t.Status,
           t.PoolId,
           p.ConnectionAlias
    FROM iam.Tenants AS t
    JOIN iam.TenantPools AS p ON p.PoolId = t.PoolId
    WHERE t.Slug = @Slug;
END
GO
