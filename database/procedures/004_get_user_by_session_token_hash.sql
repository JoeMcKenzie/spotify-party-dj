USE PartyDJ;
GO

CREATE OR ALTER PROCEDURE dbo.GetUserBySessionTokenHash
  @SessionTokenHash NVARCHAR(255)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  SELECT
    u.UserID,
    u.Username,
    u.CreatedAt
  FROM dbo.UserSessions us
  INNER JOIN dbo.Users u
    ON u.UserID = us.UserID
  WHERE us.SessionTokenHash = @SessionTokenHash
    AND us.ExpiresAt > SYSUTCDATETIME()
    AND us.RevokedAt IS NULL;
END;
GO