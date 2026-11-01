-- pools hold tenant data, a tenant lives in exactly one pool

CREATE TABLE iam.TenantPools
(
    PoolId          int IDENTITY(1,1) NOT NULL,
    Name            nvarchar(100)     NOT NULL,
    Tier            varchar(20)       NOT NULL,
    ConnectionAlias varchar(100)      NOT NULL,   -- a name like Pool01, never a real connection string
    MaxTenants      int               NOT NULL,
    CurrentTenants  int               NOT NULL CONSTRAINT DF_TenantPools_CurrentTenants DEFAULT (0),
    Status          varchar(20)       NOT NULL CONSTRAINT DF_TenantPools_Status DEFAULT ('Active'),
    CreatedAt       datetime2(3)      NOT NULL CONSTRAINT DF_TenantPools_CreatedAt DEFAULT (SYSUTCDATETIME()),
    RowVer          rowversion        NOT NULL,
    CONSTRAINT PK_TenantPools PRIMARY KEY CLUSTERED (PoolId),
    CONSTRAINT UQ_TenantPools_Name UNIQUE (Name),
    CONSTRAINT CK_TenantPools_Tier CHECK (Tier IN ('Pooled', 'Dedicated')),
    CONSTRAINT CK_TenantPools_Status CHECK (Status IN ('Active', 'Draining', 'Disabled')),
    CONSTRAINT CK_TenantPools_Max CHECK (MaxTenants > 0),
    CONSTRAINT CK_TenantPools_Current CHECK (CurrentTenants >= 0 AND CurrentTenants <= MaxTenants)
);
GO

CREATE TABLE iam.Tenants
(
    TenantId  int IDENTITY(1000,1) NOT NULL,
    PublicId  uniqueidentifier     NOT NULL CONSTRAINT DF_Tenants_PublicId DEFAULT (NEWID()),
    Slug      varchar(63)          NOT NULL,
    Name      nvarchar(200)        NOT NULL,
    Status    varchar(20)          NOT NULL CONSTRAINT DF_Tenants_Status DEFAULT ('Active'),
    PoolId    int                  NOT NULL,
    Version   bigint               NOT NULL CONSTRAINT DF_Tenants_Version DEFAULT (1),
    CreatedAt datetime2(3)         NOT NULL CONSTRAINT DF_Tenants_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt datetime2(3)         NOT NULL CONSTRAINT DF_Tenants_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    RowVer    rowversion           NOT NULL,
    CONSTRAINT PK_Tenants PRIMARY KEY CLUSTERED (TenantId),
    CONSTRAINT UQ_Tenants_PublicId UNIQUE (PublicId),
    CONSTRAINT UQ_Tenants_Slug UNIQUE (Slug),
    CONSTRAINT FK_Tenants_TenantPools FOREIGN KEY (PoolId) REFERENCES iam.TenantPools (PoolId),
    CONSTRAINT CK_Tenants_Status CHECK (Status IN ('Active', 'Suspended', 'Deleting')),
    -- the database collation ignores case, so the lowercase rule needs a binary collation to mean anything
    CONSTRAINT CK_Tenants_Slug CHECK
    (
        LEN(Slug) >= 3
        AND Slug COLLATE Latin1_General_100_BIN2 = LOWER(Slug) COLLATE Latin1_General_100_BIN2
        AND Slug COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^a-z0-9-]%'
    )
);
GO

CREATE INDEX IX_Tenants_PoolId ON iam.Tenants (PoolId);
GO
