-- permission catalog and the four built-in roles

INSERT iam.Permissions (Code, Description)
SELECT v.Code, v.Description
  FROM (VALUES
        ('tenants:read',    N'List and view tenants (platform level)'),
        ('tenants:manage',  N'Create, suspend and delete tenants (platform level)'),
        ('users:read',      N'View users in the tenant'),
        ('users:create',    N'Create users in the tenant'),
        ('users:update',    N'Edit users in the tenant'),
        ('users:delete',    N'Delete users in the tenant'),
        ('roles:read',      N'View roles in the tenant'),
        ('roles:manage',    N'Create roles and change their permissions'),
        ('projects:read',   N'View projects'),
        ('projects:write',  N'Create and edit projects'),
        ('projects:delete', N'Delete projects'),
        ('audit:read',      N'View the audit trail for the tenant')
       ) AS v (Code, Description)
 WHERE NOT EXISTS (SELECT 1 FROM iam.Permissions AS p WHERE p.Code = v.Code);
GO

INSERT iam.Roles (TenantId, Name, IsSystem)
SELECT NULL, v.Name, 1
  FROM (VALUES (N'PlatformAdmin'), (N'TenantAdmin'), (N'Member'), (N'Viewer')) AS v (Name)
 WHERE NOT EXISTS (SELECT 1 FROM iam.Roles AS r WHERE r.TenantId IS NULL AND r.Name = v.Name);
GO

-- tenants:* stays with PlatformAdmin, a customer's admin must never see other customers
INSERT iam.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
  FROM (VALUES
        (N'PlatformAdmin', 'tenants:read'),
        (N'PlatformAdmin', 'tenants:manage'),
        (N'TenantAdmin',   'users:read'),
        (N'TenantAdmin',   'users:create'),
        (N'TenantAdmin',   'users:update'),
        (N'TenantAdmin',   'users:delete'),
        (N'TenantAdmin',   'roles:read'),
        (N'TenantAdmin',   'roles:manage'),
        (N'TenantAdmin',   'projects:read'),
        (N'TenantAdmin',   'projects:write'),
        (N'TenantAdmin',   'projects:delete'),
        (N'TenantAdmin',   'audit:read'),
        (N'Member',        'projects:read'),
        (N'Member',        'projects:write'),
        (N'Viewer',        'projects:read')
       ) AS m (RoleName, PermCode)
  JOIN iam.Roles       AS r ON r.TenantId IS NULL AND r.Name = m.RoleName
  JOIN iam.Permissions AS p ON p.Code = m.PermCode
 WHERE NOT EXISTS (SELECT 1 FROM iam.RolePermissions AS rp WHERE rp.RoleId = r.RoleId AND rp.PermissionId = p.PermissionId);
GO
