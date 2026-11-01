-- refresh tokens, jwt signing keys, login attempts

CREATE TABLE iam.RefreshTokens
(
    TokenId           bigint IDENTITY(1,1) NOT NULL,
    FamilyId          uniqueidentifier     NOT NULL,   -- every token from one login shares a family
    UserId            bigint               NOT NULL,
    TenantId          int                  NOT NULL,
    TokenHash         binary(32)           NOT NULL,   -- sha-256 of the token, the token itself is never stored
    IssuedAt          datetime2(3)         NOT NULL CONSTRAINT DF_RefreshTokens_IssuedAt DEFAULT (SYSUTCDATETIME()),
    ExpiresAt         datetime2(3)         NOT NULL,
    AbsoluteExpiresAt datetime2(3)         NOT NULL,
    UsedAt            datetime2(3)         NULL,
    ReplacedByTokenId bigint               NULL,
    RevokedAt         datetime2(3)         NULL,
    RevokedReason     varchar(50)          NULL,
    CreatedByIp       varchar(45)          NULL,
    CONSTRAINT PK_RefreshTokens PRIMARY KEY CLUSTERED (TokenId),
    CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE (TokenHash),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES iam.Users (UserId),
    CONSTRAINT FK_RefreshTokens_Tenants FOREIGN KEY (TenantId) REFERENCES iam.Tenants (TenantId),
    CONSTRAINT FK_RefreshTokens_ReplacedBy FOREIGN KEY (ReplacedByTokenId) REFERENCES iam.RefreshTokens (TokenId),
    CONSTRAINT CK_RefreshTokens_Expiry CHECK (ExpiresAt > IssuedAt AND ExpiresAt <= AbsoluteExpiresAt),
    CONSTRAINT CK_RefreshTokens_Reason CHECK
    (
        RevokedReason IS NULL
        OR RevokedReason IN ('Logout', 'LogoutAll', 'ReuseDetected', 'AdminRevoke', 'PasswordChanged')
    )
);
GO

CREATE INDEX IX_RefreshTokens_FamilyId ON iam.RefreshTokens (FamilyId);
CREATE INDEX IX_RefreshTokens_UserId ON iam.RefreshTokens (UserId) INCLUDE (RevokedAt, ExpiresAt);
CREATE INDEX IX_RefreshTokens_TenantId ON iam.RefreshTokens (TenantId);
CREATE INDEX IX_RefreshTokens_ExpiresAt ON iam.RefreshTokens (ExpiresAt);
CREATE INDEX IX_RefreshTokens_ReplacedBy ON iam.RefreshTokens (ReplacedByTokenId) WHERE ReplacedByTokenId IS NOT NULL;
GO

CREATE TABLE iam.SigningKeys
(
    Kid                 varchar(64)    NOT NULL,
    Algorithm           varchar(10)    NOT NULL CONSTRAINT DF_SigningKeys_Algorithm DEFAULT ('RS256'),
    PublicKey           nvarchar(max)  NOT NULL,
    PrivateKeyProtected varbinary(max) NOT NULL,   -- encrypted before it gets here
    Status              varchar(20)    NOT NULL CONSTRAINT DF_SigningKeys_Status DEFAULT ('Active'),
    CreatedAt           datetime2(3)   NOT NULL CONSTRAINT DF_SigningKeys_CreatedAt DEFAULT (SYSUTCDATETIME()),
    NotAfter            datetime2(3)   NULL,
    CONSTRAINT PK_SigningKeys PRIMARY KEY CLUSTERED (Kid),
    CONSTRAINT CK_SigningKeys_Algorithm CHECK (Algorithm = 'RS256'),
    CONSTRAINT CK_SigningKeys_Status CHECK (Status IN ('Active', 'Retiring', 'Retired'))
);
GO

-- at most one active key, enforced here and not in app code
CREATE UNIQUE INDEX UX_SigningKeys_OneActive ON iam.SigningKeys (Status) WHERE Status = 'Active';
GO

CREATE TABLE iam.LoginAttempts
(
    AttemptId       bigint IDENTITY(1,1) NOT NULL,
    TenantId        int                  NULL,     -- null when the tenant slug didn't exist, so no foreign key
    EmailNormalized nvarchar(320)        NULL,
    Ip              varchar(45)          NULL,
    Success         bit                  NOT NULL,
    Reason          varchar(50)          NULL,
    At              datetime2(3)         NOT NULL CONSTRAINT DF_LoginAttempts_At DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_LoginAttempts PRIMARY KEY NONCLUSTERED (AttemptId)
);
GO

-- clustered on time so purging old attempts is a cheap range delete
CREATE CLUSTERED INDEX CX_LoginAttempts_At ON iam.LoginAttempts (At, AttemptId);
CREATE INDEX IX_LoginAttempts_Lookup ON iam.LoginAttempts (TenantId, EmailNormalized, At);
GO
