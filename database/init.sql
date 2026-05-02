IF DB_ID('PartyDJ') IS NULL
BEGIN
    CREATE DATABASE PartyDJ;
END;
GO

USE PartyDJ;
GO

DROP TABLE IF EXISTS Votes;
DROP TABLE IF EXISTS QueueItems;
DROP TABLE IF EXISTS SessionParticipants;
DROP TABLE IF EXISTS [Sessions];
DROP TABLE IF EXISTS Songs;
DROP TABLE IF EXISTS Artists;
DROP TABLE IF EXISTS Users;
GO

CREATE TABLE Users (
    UserID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Users PRIMARY KEY,
    Username        NVARCHAR(50)    NOT NULL                CONSTRAINT UQ_Users_Username UNIQUE,
    PasswordHash    NVARCHAR(255)   NOT NULL,
    FirstName       NVARCHAR(100)   NULL,
    LastName        NVARCHAR(100)   NULL,
    DisplayName     NVARCHAR(100)   NULL,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE Artists (
    ArtistID        BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Artists PRIMARY KEY,
    ArtistName      NVARCHAR(255)   NOT NULL,
    SpotifyArtistID NVARCHAR(64)    NULL                    CONSTRAINT UQ_Artists_SpotifyArtistID UNIQUE,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Artists_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE Songs (
    SongID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Songs PRIMARY KEY,
    SpotifyTrackID  NVARCHAR(64)    NULL                    CONSTRAINT UQ_Songs_SpotifyTrackID UNIQUE,
    SongName        NVARCHAR(255)   NOT NULL,
    ArtistID        BIGINT          NOT NULL                CONSTRAINT FK_Songs_Artists_ArtistID REFERENCES Artists(ArtistID),
    AlbumName       NVARCHAR(255)   NULL,
    DurationSeconds INT             NOT NULL                CONSTRAINT CK_Songs_DurationSeconds CHECK (DurationSeconds > 0),
    IsExplicit      BIT             NOT NULL                CONSTRAINT DF_Songs_IsExplicit DEFAULT 0,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Songs_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE Sessions (
    SessionID       BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Sessions PRIMARY KEY,
    SessionCode     NVARCHAR(16)    NOT NULL                CONSTRAINT UQ_Sessions_SessionCode UNIQUE,
    SessionName     NVARCHAR(255)   NOT NULL,
    CreatedByUserID BIGINT          NOT NULL                CONSTRAINT FK_Sessions_Users_CreatedByUserID REFERENCES Users(UserID),
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Sessions_CreatedAt DEFAULT SYSUTCDATETIME(),
    StartedAt       DATETIME2(3)    NULL,
    EndedAt         DATETIME2(3)    NULL,
    Status          NVARCHAR(16)    NOT NULL                CONSTRAINT CK_Sessions_Status CHECK (Status IN (N'Pending', N'Active', N'Paused', N'Ended', N'Cancelled')),
    CONSTRAINT CK_Sessions_EndedAfterStarted
        CHECK (EndedAt IS NULL OR StartedAt IS NULL OR EndedAt >= StartedAt)
);

CREATE TABLE QueueItems (
    QueueItemID     BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_QueueItems PRIMARY KEY,
    SessionID       BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Sessions_SessionID REFERENCES Sessions(SessionID),
    SongID          BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Songs_SongID REFERENCES Songs(SongID),
    AddedByUserID   BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Users_AddedByUserID REFERENCES Users(UserID),
    Position        INT             NOT NULL,
    QueuedAt        DATETIME2(3)    NOT NULL                CONSTRAINT DF_QueueItems_QueuedAt DEFAULT SYSUTCDATETIME(),
    Status          NVARCHAR(32)    NOT NULL,
    StartedAt       DATETIME2(3)    NULL,
    EndedAt         DATETIME2(3)    NULL,
    CONSTRAINT UQ_QueueItems_SessionID_Position UNIQUE (SessionID, Position),
    CONSTRAINT CK_QueueItems_EndedAfterStarted
        CHECK (EndedAt IS NULL OR StartedAt IS NULL OR EndedAt >= StartedAt)
);

CREATE TABLE Votes (
    VoteID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Votes PRIMARY KEY,
    QueueItemID     BIGINT          NOT NULL                CONSTRAINT FK_Votes_QueueItems_QueueItemID REFERENCES QueueItems(QueueItemID),
    UserID          BIGINT          NOT NULL                CONSTRAINT FK_Votes_Users_UserID REFERENCES Users(UserID),
    VoteType        NVARCHAR(16)    NOT NULL,
    VoteValue       SMALLINT        NOT NULL,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Votes_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Votes_QueueItemID_UserID UNIQUE (QueueItemID, UserID)
);

CREATE TABLE SessionParticipants (
    SessionParticipantID BIGINT     NOT NULL IDENTITY(1,1)  CONSTRAINT PK_SessionParticipants PRIMARY KEY,
    SessionID       BIGINT          NOT NULL                CONSTRAINT FK_SessionParticipants_Sessions_SessionID REFERENCES Sessions(SessionID),
    UserID          BIGINT          NOT NULL                CONSTRAINT FK_SessionParticipants_Users_UserID REFERENCES Users(UserID),
    JoinedAt        DATETIME2(3)    NOT NULL                CONSTRAINT DF_SessionParticipants_JoinedAt DEFAULT SYSUTCDATETIME(),
    LeftAt          DATETIME2(3)    NULL,
    Role            NVARCHAR(16)    NOT NULL                CONSTRAINT CK_SessionParticipants_Role CHECK (Role IN (N'Host', N'Participant', N'Guest')),
    CONSTRAINT UQ_SessionParticipants_SessionID_UserID UNIQUE (SessionID, UserID),
    CONSTRAINT CK_SessionParticipants_LeftAfterJoined
        CHECK (LeftAt IS NULL OR LeftAt >= JoinedAt)
);
GO


CREATE OR ALTER PROCEDURE dbo.CreateUser
  @Username NVARCHAR(50),
  @PasswordHash NVARCHAR(255)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @UserID BIGINT;

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
    RETURN;
  END;

  INSERT INTO dbo.Users (Username, PasswordHash)
  VALUES (@Username, @PasswordHash);

  SET @UserID = SCOPE_IDENTITY();

  SELECT UserID, Username, CreatedAt
  FROM dbo.Users
  WHERE UserID = @UserID;
END;
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

  SELECT UserID, Username, PasswordHash, CreatedAt
  FROM dbo.Users
  WHERE Username = @Username;
END;
GO