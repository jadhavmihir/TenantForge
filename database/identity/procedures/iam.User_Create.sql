-- creates a user and their credentials row together, or neither.
-- the password is hashed by the api before it gets here. this procedure only ever sees the hash.

CREATE OR ALTER PROCEDURE iam.User_Create
    @TenantId     int,
    @Email        nvarchar(320),
    @DisplayName  nvarchar(200),
    @PasswordHash varchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @userId bigint;

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM iam.Tenants WHERE TenantId = @TenantId AND Status = 'Active')
        THROW 50002, 'Tenant not found or not active.', 1;

    INSERT INTO iam.Users (TenantId, Email, DisplayName)
    VALUES (@TenantId, @Email, @DisplayName);

    SET @userId = SCOPE_IDENTITY();

    INSERT INTO iam.UserCredentials (UserId, PasswordHash)
    VALUES (@userId, @PasswordHash);

    COMMIT TRANSACTION;

    SELECT UserId, PublicId, TenantId, Email, DisplayName, Status
    FROM iam.Users
    WHERE UserId = @userId;
END
GO
