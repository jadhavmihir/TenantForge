-- permissions, roles and who holds what

CREATE TABLE iam.Permissions
(
    PermissionId int IDENTITY(1,1) NOT NULL,
    Code         varchar(100)      NOT NULL,   -- resource:action, e.g. projects:write
    Description  nvarchar(300)     NOT NULL,
    CONSTRAINT PK_Permissions PRIMARY KEY CLUSTERED (PermissionId),
    CONSTRAINT UQ_Permissions_Code UNIQUE (Code),
    CONSTRAINT CK_Permissions_Code CHECK
    (
        Code COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^a-z0-9:_]%'
        AND CHARINDEX(':', Code) > 1
        AND CHARINDEX(':', Code) < LEN(Code)
    )
);
GO

CREATE TABLE iam.Roles
(
    RoleId    int IDENTITY(1,1) NOT NULL,
    TenantId  int               NULL,          -- null means a system role shared by every tenant
    Name      nvarchar(100)     NOT NULL,
    IsSystem  bit               NOT NULL CONSTRAINT DF_Roles_IsSystem DEFAULT (0),
    Version   bigint            NOT NULL CONSTRAINT DF_Roles_Version DEFAULT (1),
    CreatedAt datetime2(3)      NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt datetime2(3)      NOT NULL CONSTRAINT DF_Roles_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    RowVer    rowversion        NOT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (RoleId),
    CONSTRAINT FK_Roles_Tenants FOREIGN KEY (TenantId) REFERENCES iam.Tenants (TenantId),
    CONSTRAINT CK_Roles_SystemTenant CHECK
    (
        (IsSystem = 1 AND TenantId IS NULL)
        OR (IsSystem = 0 AND TenantId IS NOT NULL)
    )
);
GO

-- null counts as a value in a unique index here, so system role names stay unique too
CREATE UNIQUE INDEX UX_Roles_Tenant_Name ON iam.Roles (TenantId, Name);
GO

CREATE TABLE iam.RolePermissions
(
    RoleId       int          NOT NULL,
    PermissionId int          NOT NULL,
    GrantedAt    datetime2(3) NOT NULL CONSTRAINT DF_RolePermissions_GrantedAt DEFAULT (SYSUTCDATETIME()),
    GrantedBy    bigint       NULL,
    CONSTRAINT PK_RolePermissions PRIMARY KEY CLUSTERED (RoleId, PermissionId),
    CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES iam.Roles (RoleId),
    CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES iam.Permissions (PermissionId),
    CONSTRAINT FK_RolePermissions_GrantedBy FOREIGN KEY (GrantedBy) REFERENCES iam.Users (UserId)
);
GO

CREATE INDEX IX_RolePermissions_PermissionId ON iam.RolePermissions (PermissionId);
GO

-- note: nothing here stops a user getting another tenant's role. User_AssignRole will check that.
CREATE TABLE iam.UserRoles
(
    UserId     bigint       NOT NULL,
    RoleId     int          NOT NULL,
    AssignedAt datetime2(3) NOT NULL CONSTRAINT DF_UserRoles_AssignedAt DEFAULT (SYSUTCDATETIME()),
    AssignedBy bigint       NULL,
    CONSTRAINT PK_UserRoles PRIMARY KEY CLUSTERED (UserId, RoleId),
    CONSTRAINT FK_UserRoles_Users FOREIGN KEY (UserId) REFERENCES iam.Users (UserId),
    CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleId) REFERENCES iam.Roles (RoleId),
    CONSTRAINT FK_UserRoles_AssignedBy FOREIGN KEY (AssignedBy) REFERENCES iam.Users (UserId)
);
GO

CREATE INDEX IX_UserRoles_RoleId ON iam.UserRoles (RoleId);
GO
