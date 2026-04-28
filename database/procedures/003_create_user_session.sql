USE PartyDJ;
GO

CREATE OR ALTER PROCEDURE dbo.CreateUserSession
  @UserID INT,
  @SessionTokenHash NVARCHAR(255),
  @ExpiresAt DATETIME2
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  INSERT INTO dbo.UserSessions (
    UserID,
    SessionTokenHash,
    ExpiresAt
  )
  VALUES (
    @UserID,
    @SessionTokenHash,
    @ExpiresAt
  );

  SELECT
    UserSessionID,
    UserID,
    ExpiresAt
  FROM dbo.UserSessions
  WHERE UserSessionID = SCOPE_IDENTITY();
END;
GO