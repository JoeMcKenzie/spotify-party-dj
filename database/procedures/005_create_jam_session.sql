USE PartyDJ;
GO

CREATE OR ALTER PROCEDURE dbo.CreateSession
  @SessionCode NVARCHAR(16),
  @SessionName NVARCHAR(255),
  @CreatedByUserID INT
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @SessionID INT;

  SET @SessionCode = UPPER(LTRIM(RTRIM(@SessionCode)));
  SET @SessionName = LTRIM(RTRIM(@SessionName));

  IF @SessionCode IS NULL OR LEN(@SessionCode) <> 5
  BEGIN
    THROW 51001, 'Session code must be 5 letters.', 1;
  END;

  IF EXISTS (
    SELECT 1
    FROM dbo.Sessions
    WHERE SessionCode = @SessionCode
      AND Status IN (N'Pending', N'Active', N'Paused')
  )
  BEGIN
    THROW 51002, 'That session code is already in use.', 1;
  END;

  INSERT INTO dbo.Sessions (
    SessionCode,
    SessionName,
    CreatedByUserID,
    StartedAt,
    Status
  )
  VALUES (
    @SessionCode,
    @SessionName,
    @CreatedByUserID,
    SYSUTCDATETIME(),
    N'Active'
  );

  SET @SessionID = SCOPE_IDENTITY();

  INSERT INTO dbo.SessionParticipants (
    SessionID,
    UserID,
    Role
  )
  VALUES (
    @SessionID,
    @CreatedByUserID,
    N'Host'
  );

  SELECT
    SessionID,
    SessionCode,
    SessionName,
    CreatedByUserID,
    StartedAt,
    Status
  FROM dbo.Sessions
  WHERE SessionID = @SessionID;
END;
GO