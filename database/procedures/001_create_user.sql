USE PartyDJ
GO

CREATE OR ALTER PROCEDURE dbo.CreateUser
  @Username NVARCHAR(50),
  @PasswordHash NVARCHAR(255)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @UserID INT;

  SET @Username = LTRIM(RTRIM(@Username));
  SET @PasswordHash = LTRIM(RTRIM(@PasswordHash));

  IF @Username IS NULL OR @Username = ''
  BEGIN
    RAISERROR ('Username is required.', 16, 1);
    RETURN;
  END;

  IF @PasswordHash IS NULL OR @PasswordHash = ''
  BEGIN
    RAISERROR ('Password is required.', 16, 1);
    RETURN;
  END;

  IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username)
  BEGIN
    RAISERROR ('That username is already taken', 16, 1);
  END;

  INSERT INTO dbo.Users (
    Username,
    PasswordHash
  )
  VALUES (
    @Username,
    @PasswordHash
  )

  SET @UserID = SCOPE_IDENTITY();

  SELECT
    Username,
    CreatedAt
  FROM dbo.Users
  WHERE UserID = @UserID
END;
GO