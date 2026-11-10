-- records one login try. on a known user it also updates the failure counter and the lock.
-- the counter is changed with a single UPDATE (no read-then-write), so two bad tries at the same moment both count.
-- the api checks LockedUntil before it checks the password. this procedure only keeps the numbers.

CREATE OR ALTER PROCEDURE iam.Login_RecordAttempt
    @TenantId int           = NULL,   -- null when the tenant slug didn't exist
    @Email    nvarchar(320),
    @UserId   bigint        = NULL,   -- null when no user matched
    @Success  bit,
    @Reason   varchar(50)   = NULL,
    @Ip       varchar(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @maxFailures int = 5;
    DECLARE @lockMinutes int = 15;

    BEGIN TRANSACTION;

    INSERT INTO iam.LoginAttempts (TenantId, EmailNormalized, Ip, Success, Reason)
    VALUES (@TenantId, LOWER(LTRIM(RTRIM(@Email))), @Ip, @Success, @Reason);

    IF @UserId IS NOT NULL
    BEGIN
        IF @Success = 1
        BEGIN
            UPDATE iam.UserCredentials
            SET FailedAttemptCount = 0,
                LockedUntil        = NULL,
                LastLoginAt        = SYSUTCDATETIME()
            WHERE UserId = @UserId;
        END
        ELSE
        BEGIN
            -- in an UPDATE the right side sees the old values, so FailedAttemptCount + 1 is the new count
            UPDATE iam.UserCredentials
            SET FailedAttemptCount = FailedAttemptCount + 1,
                LockedUntil = CASE WHEN FailedAttemptCount + 1 >= @maxFailures
                                   THEN DATEADD(MINUTE, @lockMinutes, SYSUTCDATETIME())
                                   ELSE LockedUntil END
            WHERE UserId = @UserId;
        END

        SELECT FailedAttemptCount, LockedUntil
        FROM iam.UserCredentials
        WHERE UserId = @UserId;
    END

    COMMIT TRANSACTION;
END
GO
