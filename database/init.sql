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

INSERT INTO Users (Username, PasswordHash, FirstName, LastName, DisplayName) VALUES
('djmike',    'hash_abc123', 'Mike',    'Torres',   'DJ Mike'),
('sarahk',    'hash_def456', 'Sarah',   'Kim',      'Sarah K'),
('beat_luca', 'hash_ghi789', 'Luca',    'Mancini',  'Luca Beats'),
('nova_jay',  'hash_jkl012', 'Jasmine', 'Okafor',   'Nova Jay'),
('tomwaves',  'hash_mno345', 'Tom',     'Walsh',     'Tomwaves');
GO

INSERT INTO Artists (ArtistName, SpotifyArtistID) VALUES
('Daft Punk',       '4tZwfgrHOc3mvqYlEYSvVi'),
('Kendrick Lamar',  '2YZyLoL8N0Wb9xBt1NhZWg'),
('Tame Impala',     '5INjqkS1o8h1imAzPqGZng'),
('Billie Eilish',   '6qqNVTkY8uBg9cP3Jd7DAH'),
('Doja Cat',        '5cj0lLjcoR7YOSnhnX0Po5');
GO

INSERT INTO Songs (SpotifyTrackID, SongName, ArtistID, AlbumName, DurationSeconds, IsExplicit) VALUES
('track_001', 'Get Lucky',            1, 'Random Access Memories', 248, 0),
('track_002', 'One More Time',        1, 'Discovery',              321, 0),
('track_003', 'HUMBLE.',              2, 'DAMN.',                  177, 1),
('track_004', 'DNA.',                 2, 'DAMN.',                  185, 1),
('track_005', 'The Less I Know',      3, 'Currents',               216, 0),
('track_006', 'Let It Happen',        3, 'Currents',               467, 0),
('track_007', 'bad guy',              4, 'When We All Fall Asleep',194, 0),
('track_008', 'Happier Than Ever',    4, 'Happier Than Ever',      295, 0),
('track_009', 'Say So',               5, 'Hot Pink',               238, 0),
('track_010', 'Woman',                5, 'Planet Her',             212, 0);
GO

INSERT INTO Sessions (SessionCode, SessionName, CreatedByUserID, StartedAt, Status) VALUES
('PRTY-001', 'Friday Night Kickback', 1, '2025-04-25 21:00:00', 'Active'),
('PRTY-002', 'Rooftop Session',       2, '2025-04-26 20:00:00', 'Ended'),
('PRTY-003', 'Chill Sunday Vibes',    3, NULL,                  'Pending'),
('PRTY-004', 'Office Happy Hour',     1, '2025-04-25 17:00:00', 'Cancelled');
GO

INSERT INTO SessionParticipants (SessionID, UserID, Role, LeftAt) VALUES
(1, 1, 'Host',        NULL),
(1, 2, 'Participant', NULL),
(1, 3, 'Participant', NULL),
(1, 4, 'Guest',       NULL),
(2, 2, 'Host',        '2025-04-26 23:00:00'),
(2, 1, 'Participant', '2025-04-26 23:00:00'),
(2, 5, 'Guest',       '2025-04-26 22:30:00'),
(3, 3, 'Host',        NULL),
(3, 4, 'Participant', NULL),
(4, 1, 'Host',        '2025-04-25 17:30:00');
GO

INSERT INTO QueueItems (SessionID, SongID, AddedByUserID, Position, Status, StartedAt, EndedAt) VALUES
(1, 1, 1, 1, 'Played',   '2025-04-25 21:01:00', '2025-04-25 21:05:08'),
(1, 3, 2, 2, 'Played',   '2025-04-25 21:05:08', '2025-04-25 21:08:05'),
(1, 7, 3, 3, 'Playing',  '2025-04-25 21:08:05', NULL),
(1, 5, 4, 4, 'Queued',   NULL,                  NULL),
(1, 9, 2, 5, 'Queued',   NULL,                  NULL),
(2, 2, 2, 1, 'Played',   '2025-04-26 20:02:00', '2025-04-26 20:07:21'),
(2, 6, 1, 2, 'Played',   '2025-04-26 20:07:21', '2025-04-26 20:15:08'),
(2, 8, 5, 3, 'Played',   '2025-04-26 20:15:08', '2025-04-26 20:20:03'),
(3, 10, 3, 1, 'Queued',  NULL,                  NULL),
(3, 4,  4, 2, 'Queued',  NULL,                  NULL);
GO

INSERT INTO Votes (QueueItemID, UserID, VoteType, VoteValue) VALUES
(1, 2, 'Upvote',   1),
(1, 3, 'Upvote',   1),
(1, 4, 'Downvote', -1),
(2, 1, 'Upvote',   1),
(2, 4, 'Upvote',   1),
(3, 2, 'Upvote',   1),
(3, 3, 'Downvote', -1),
(4, 1, 'Upvote',   1),
(4, 2, 'Upvote',   1),
(4, 3, 'Upvote',   1),
(9, 4, 'Upvote',   1);
GO