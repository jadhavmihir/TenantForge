-- finds a user by tenant and email and returns what login needs, including the password hash.
-- this is the only place the hash leaves the database. the app role can't select UserCredentials
-- directly, it reaches it through this procedure (ownership chaining).

CREATE OR ALTER PROCEDURE iam.User_GetForLogin
    @TenantId int,
    @Email    nvarchar(320)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.UserId,
           u.PublicId,
           u.TenantId,
           u.Email,
           u.DisplayName,
           u.Status,
           u.PermVersion,
           c.PasswordHash,
           c.FailedAttemptCount,
           c.LockedUntil
    FROM iam.Users AS u
    JOIN iam.UserCredentials AS c ON c.UserId = u.UserId
    WHERE u.TenantId = @TenantId
      AND u.EmailNormalized = LOWER(LTRIM(RTRIM(@Email)))
      AND u.IsDeleted = 0;
END
GO
