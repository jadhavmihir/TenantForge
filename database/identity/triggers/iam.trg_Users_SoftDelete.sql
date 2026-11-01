-- a DELETE on Users flags the row instead of removing it.
-- tokens, roles and audit rows still point at the user.
CREATE OR ALTER TRIGGER iam.trg_Users_SoftDelete
ON iam.Users
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u
       SET IsDeleted = 1,
           UpdatedAt = SYSUTCDATETIME(),
           Version   = u.Version + 1
      FROM iam.Users AS u
      JOIN deleted   AS d ON d.UserId = u.UserId
     WHERE u.IsDeleted = 0;
END
GO
