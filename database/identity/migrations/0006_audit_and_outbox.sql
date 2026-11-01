-- audit log, sync outbox, per-pool sync checkpoint

-- no foreign keys on purpose: an audit row has to outlive what it describes
CREATE TABLE audit.AuditLog
(
    AuditId       bigint IDENTITY(1,1) NOT NULL,
    TenantId      int                  NULL,
    ActorUserId   bigint               NULL,
    DbLogin       sysname              NOT NULL CONSTRAINT DF_AuditLog_DbLogin DEFAULT (SUSER_SNAME()),
    Action        varchar(50)          NOT NULL,
    EntityType    varchar(100)         NOT NULL,
    EntityId      varchar(100)         NOT NULL,
    OldValues     nvarchar(max)        NULL,
    NewValues     nvarchar(max)        NULL,
    CorrelationId uniqueidentifier     NULL,
    Ip            varchar(45)          NULL,
    OccurredAt    datetime2(3)         NOT NULL CONSTRAINT DF_AuditLog_OccurredAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditId),
    CONSTRAINT CK_AuditLog_OldValues CHECK (OldValues IS NULL OR ISJSON(OldValues) = 1),
    CONSTRAINT CK_AuditLog_NewValues CHECK (NewValues IS NULL OR ISJSON(NewValues) = 1)
);
GO

CREATE INDEX IX_AuditLog_Tenant_OccurredAt ON audit.AuditLog (TenantId, OccurredAt DESC);
CREATE INDEX IX_AuditLog_Entity ON audit.AuditLog (EntityType, EntityId);
GO

CREATE TABLE sync.Outbox
(
    Seq              rowversion       NOT NULL,
    EventId          uniqueidentifier NOT NULL CONSTRAINT DF_Outbox_EventId DEFAULT (NEWID()),
    TenantId         int              NULL,          -- null = global event
    AggregateType    varchar(50)      NOT NULL,
    AggregateId      bigint           NOT NULL,
    AggregateVersion bigint           NOT NULL,
    EventType        varchar(100)     NOT NULL,
    Payload          nvarchar(max)    NOT NULL,      -- full snapshot, not a diff
    CreatedAt        datetime2(3)     NOT NULL CONSTRAINT DF_Outbox_CreatedAt DEFAULT (SYSUTCDATETIME()),
    -- rowversion as the key is fine because these rows are never updated
    CONSTRAINT PK_Outbox PRIMARY KEY CLUSTERED (Seq),
    CONSTRAINT UQ_Outbox_EventId UNIQUE (EventId),
    CONSTRAINT CK_Outbox_Payload CHECK (ISJSON(Payload) = 1)
);
GO

-- not unique: a resync can send the same version again
CREATE INDEX IX_Outbox_Aggregate ON sync.Outbox (AggregateType, AggregateId, AggregateVersion);
GO

CREATE TABLE sync.PoolCheckpoint
(
    PoolId     int          NOT NULL,
    LastSeq    binary(8)    NOT NULL CONSTRAINT DF_PoolCheckpoint_LastSeq DEFAULT (0x0000000000000000),
    LastSeenAt datetime2(3) NULL,
    UpdatedAt  datetime2(3) NOT NULL CONSTRAINT DF_PoolCheckpoint_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_PoolCheckpoint PRIMARY KEY CLUSTERED (PoolId),
    CONSTRAINT FK_PoolCheckpoint_TenantPools FOREIGN KEY (PoolId) REFERENCES iam.TenantPools (PoolId)
);
GO
