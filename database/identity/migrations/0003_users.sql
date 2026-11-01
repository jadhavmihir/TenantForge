-- users and their credentials (credentials are kept in a separate table on purpose)

-- needed for the filtered index and the persisted computed column
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE TABLE iam.Users
(
    UserId          bigint IDENTITY(1,1) NOT NULL,
    TenantId        int                  NOT NULL,
    PublicId        uniqueidentifier     NOT NULL CONSTRAINT DF_Users_PublicId DEFAULT (NEWID()),
    Email           nvarchar(320)        NOT NULL,
    EmailNormalized AS (LOWER(LTRIM(RTRIM(Email)))) PERSISTED,
    DisplayName     nvarchar(200)        NOT NULL,
    Status          varchar(20)          NOT NULL CONSTRAINT DF_Users_Status DEFAULT ('Active'),
    IsDeleted       bit                  NOT NULL CONSTRAINT DF_Users_IsDeleted DEFAULT (0),
    PermVersion     int                  NOT NULL CONSTRAINT DF_Users_PermVersion DEFAULT (1),
    Version         bigint               NOT NULL CONSTRAINT DF_Users_Version DEFAULT (1),
    CreatedAt       datetime2(3)         NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       datetime2(3)         NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    RowVer          rowversion           NOT NULL,
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT UQ_Users_PublicId UNIQUE (PublicId),
    CONSTRAINT FK_Users_Tenants FOREIGN KEY (TenantId) REFERENCES iam.Tenants (TenantId),
    CONSTRAINT CK_Users_Status CHECK (Status IN ('Active', 'Disabled')),
    CONSTRAINT CK_Users_Email CHECK (CHARINDEX('@', Email) > 1)
);
GO

-- one email per tenant, deleted users don't count
CREATE UNIQUE INDEX UX_Users_Tenant_Email ON iam.Users (TenantId, EmailNormalized) WHERE IsDeleted = 0;
CREATE INDEX IX_Users_TenantId ON iam.Users (TenantId);
GO

CREATE TABLE iam.UserCredentials
(
    UserId             bigint        NOT NULL,
    PasswordHash       varchar(200)  NOT NULL,   -- pbkdf2-sha256$600000$salt$hash
    FailedAttemptCount int           NOT NULL CONSTRAINT DF_UserCredentials_Failed DEFAULT (0),
    LockedUntil        datetime2(3)  NULL,
    LastLoginAt        datetime2(3)  NULL,
    PasswordChangedAt  datetime2(3)  NOT NULL CONSTRAINT DF_UserCredentials_Changed DEFAULT (SYSUTCDATETIME()),
    RowVer             rowversion    NOT NULL,
    CONSTRAINT PK_UserCredentials PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_UserCredentials_Users FOREIGN KEY (UserId) REFERENCES iam.Users (UserId),
    CONSTRAINT CK_UserCredentials_Failed CHECK (FailedAttemptCount >= 0),
    CONSTRAINT CK_UserCredentials_Hash CHECK (CHARINDEX('$', PasswordHash) > 1)
);
GO
