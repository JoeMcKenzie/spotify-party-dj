USE PartyDJ;
GO

CREATE OR ALTER PROCEDURE dbo.GetUserByUsername
  @Username NVARCHAR(50)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  SET @Username = LTRIM(RTRIM(@Username));

  IF @Username IS NULL OR @Username = ''
  BEGIN
    RAISERROR ('Username is required.', 16, 1);
    RETURN;
  END;

  SELECT
    UserID,
    Username,
    PasswordHash,
    CreatedAt
  FROM dbo.Users
  WHERE Username = @Username;
END;
GO