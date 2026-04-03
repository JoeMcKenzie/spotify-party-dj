USE PartyDJ
GO

CREATE OR ALTER PROCEDURE dbo.CreateUser
  @FirstName NVARCHAR(50),
  @LastName NVARCHAR(50),
  @DisplayName NVARCHAR(50)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @UserID INT;

  SET @FirstName = LTRIM(RTRIM(@FirstName));
  SET @LastName = LTRIM(RTRIM(@LastName));
  SET @DisplayName = LTRIM(RTRIM(@DisplayName));

  IF @FirstName IS NULL OR @FirstName = ''
  BEGIN
    RAISERROR ('First name is required.', 16, 1);
    RETURN;
  END;

  IF @LastName IS NULL OR @LastName = ''
  BEGIN
    RAISERROR ('Last name is required.', 16, 1);
    RETURN;
  END;

  IF @DisplayName IS NULL OR @DisplayName = ''
  BEGIN
    RAISERROR ('Display name is required.', 16, 1);
    RETURN;
  END;

  INSERT INTO dbo.Users (
    FirstName,
    LastName,
    DisplayName
  )
  VALUES (
    @FirstName,
    @LastName,
    @DisplayName
  )

  SET @UserID = SCOPE_IDENTITY();

  SELECT
    UserID,
    FirstName,
    LastName,
    DisplayName,
    CreatedAt
  FROM dbo.Users
  WHERE UserID = @UserID
END;
GO