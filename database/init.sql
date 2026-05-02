-- =============================================
-- PartyDJ — Full Reset + Seed Script
-- =============================================

IF DB_ID('PartyDJ') IS NULL
BEGIN
    CREATE DATABASE PartyDJ;
END;
GO

USE PartyDJ;
GO

-- =============================================
-- DROP (reverse FK order)
-- =============================================
DROP TABLE IF EXISTS dbo.Votes;
DROP TABLE IF EXISTS dbo.QueueItems;
DROP TABLE IF EXISTS dbo.SessionParticipants;
DROP TABLE IF EXISTS dbo.Sessions;
DROP TABLE IF EXISTS dbo.Songs;
DROP TABLE IF EXISTS dbo.Artists;
DROP TABLE IF EXISTS dbo.UserSpotifyTokens;
DROP TABLE IF EXISTS dbo.UserSessions;
DROP TABLE IF EXISTS dbo.Users;
GO

-- =============================================
-- CREATE TABLES
-- =============================================

CREATE TABLE dbo.Users (
    UserID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Users PRIMARY KEY,
    Username        NVARCHAR(50)    NOT NULL                CONSTRAINT UQ_Users_Username UNIQUE,
    PasswordHash    NVARCHAR(255)   NOT NULL,
    FirstName       NVARCHAR(100)   NULL,
    LastName        NVARCHAR(100)   NULL,
    DisplayName     NVARCHAR(100)   NULL,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.UserSessions (
    UserSessionID       BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_UserSessions PRIMARY KEY,
    UserID              BIGINT          NOT NULL                CONSTRAINT FK_UserSessions_Users_UserID REFERENCES dbo.Users(UserID),
    SessionTokenHash    NVARCHAR(255)   NOT NULL                CONSTRAINT UQ_UserSessions_SessionTokenHash UNIQUE,
    CreatedAt           DATETIME2(3)    NOT NULL                CONSTRAINT DF_UserSessions_CreatedAt DEFAULT SYSUTCDATETIME(),
    ExpiresAt           DATETIME2(3)    NOT NULL,
    RevokedAt           DATETIME2(3)    NULL
);

CREATE TABLE dbo.UserSpotifyTokens (
    UserID          BIGINT          NOT NULL                CONSTRAINT PK_UserSpotifyTokens PRIMARY KEY,
    SpotifyUserID   NVARCHAR(255)   NULL,
    AccessToken     NVARCHAR(MAX)   NOT NULL,
    RefreshToken    NVARCHAR(MAX)   NOT NULL,
    ExpiresAt       DATETIME2(3)    NOT NULL,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_UserSpotifyTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_UserSpotifyTokens_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_UserSpotifyTokens_Users_UserID FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID)
);

CREATE TABLE dbo.Artists (
    ArtistID        BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Artists PRIMARY KEY,
    ArtistName      NVARCHAR(255)   NOT NULL,
    SpotifyArtistID NVARCHAR(64)    NULL                    CONSTRAINT UQ_Artists_SpotifyArtistID UNIQUE,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Artists_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Songs (
    SongID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Songs PRIMARY KEY,
    SpotifyTrackID  NVARCHAR(64)    NULL                    CONSTRAINT UQ_Songs_SpotifyTrackID UNIQUE,
    SongName        NVARCHAR(255)   NOT NULL,
    ArtistID        BIGINT          NOT NULL                CONSTRAINT FK_Songs_Artists_ArtistID REFERENCES dbo.Artists(ArtistID),
    AlbumName       NVARCHAR(255)   NULL,
    DurationSeconds INT             NOT NULL                CONSTRAINT CK_Songs_DurationSeconds CHECK (DurationSeconds > 0),
    IsExplicit      BIT             NOT NULL                CONSTRAINT DF_Songs_IsExplicit DEFAULT 0,
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Songs_CreatedAt DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Sessions (
    SessionID       BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Sessions PRIMARY KEY,
    SessionCode     NCHAR(5)        NOT NULL                CONSTRAINT UQ_Sessions_SessionCode UNIQUE,
    SessionName     NVARCHAR(255)   NOT NULL,
    CreatedByUserID BIGINT          NOT NULL                CONSTRAINT FK_Sessions_Users_CreatedByUserID REFERENCES dbo.Users(UserID),
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Sessions_CreatedAt DEFAULT SYSUTCDATETIME(),
    StartedAt       DATETIME2(3)    NULL,
    EndedAt         DATETIME2(3)    NULL,
    Status          NVARCHAR(16)    NOT NULL                CONSTRAINT CK_Sessions_Status CHECK (Status IN (N'Pending', N'Active', N'Paused', N'Ended', N'Cancelled')),
    CONSTRAINT CK_Sessions_SessionCode
        CHECK (SessionCode LIKE N'[A-Z][A-Z][A-Z][A-Z][A-Z]'),
    CONSTRAINT CK_Sessions_EndedAfterStarted
        CHECK (EndedAt IS NULL OR StartedAt IS NULL OR EndedAt >= StartedAt)
);

CREATE TABLE dbo.SessionParticipants (
    SessionParticipantID BIGINT     NOT NULL IDENTITY(1,1)  CONSTRAINT PK_SessionParticipants PRIMARY KEY,
    SessionID       BIGINT          NOT NULL                CONSTRAINT FK_SessionParticipants_Sessions_SessionID REFERENCES dbo.Sessions(SessionID),
    UserID          BIGINT          NOT NULL                CONSTRAINT FK_SessionParticipants_Users_UserID REFERENCES dbo.Users(UserID),
    JoinedAt        DATETIME2(3)    NOT NULL                CONSTRAINT DF_SessionParticipants_JoinedAt DEFAULT SYSUTCDATETIME(),
    LeftAt          DATETIME2(3)    NULL,
    Role            NVARCHAR(16)    NOT NULL                CONSTRAINT CK_SessionParticipants_Role CHECK (Role IN (N'Host', N'Participant', N'Guest')),
    CONSTRAINT UQ_SessionParticipants_SessionID_UserID UNIQUE (SessionID, UserID),
    CONSTRAINT CK_SessionParticipants_LeftAfterJoined
        CHECK (LeftAt IS NULL OR LeftAt >= JoinedAt)
);

CREATE TABLE dbo.QueueItems (
    QueueItemID     BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_QueueItems PRIMARY KEY,
    SessionID       BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Sessions_SessionID REFERENCES dbo.Sessions(SessionID),
    SongID          BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Songs_SongID REFERENCES dbo.Songs(SongID),
    AddedByUserID   BIGINT          NOT NULL                CONSTRAINT FK_QueueItems_Users_AddedByUserID REFERENCES dbo.Users(UserID),
    Position        INT             NOT NULL,
    QueuedAt        DATETIME2(3)    NOT NULL                CONSTRAINT DF_QueueItems_QueuedAt DEFAULT SYSUTCDATETIME(),
    Status          NVARCHAR(32)    NOT NULL,
    StartedAt       DATETIME2(3)    NULL,
    EndedAt         DATETIME2(3)    NULL,
    CONSTRAINT UQ_QueueItems_SessionID_Position UNIQUE (SessionID, Position),
    CONSTRAINT CK_QueueItems_EndedAfterStarted
        CHECK (EndedAt IS NULL OR StartedAt IS NULL OR EndedAt >= StartedAt)
);

CREATE TABLE dbo.Votes (
    VoteID          BIGINT          NOT NULL IDENTITY(1,1)  CONSTRAINT PK_Votes PRIMARY KEY,
    QueueItemID     BIGINT          NOT NULL                CONSTRAINT FK_Votes_QueueItems_QueueItemID REFERENCES dbo.QueueItems(QueueItemID),
    UserID          BIGINT          NOT NULL                CONSTRAINT FK_Votes_Users_UserID REFERENCES dbo.Users(UserID),
    CreatedAt       DATETIME2(3)    NOT NULL                CONSTRAINT DF_Votes_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Votes_QueueItemID_UserID UNIQUE (QueueItemID, UserID)
);
GO

-- =============================================
-- STORED PROCEDURES
-- =============================================

CREATE OR ALTER PROCEDURE dbo.CreateUser
  @Username     NVARCHAR(50),
  @PasswordHash NVARCHAR(255)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @UserID BIGINT;

  SET @Username     = LTRIM(RTRIM(@Username));
  SET @PasswordHash = LTRIM(RTRIM(@PasswordHash));

  IF @Username IS NULL OR @Username = ''
  BEGIN
    RAISERROR('Username is required.', 16, 1);
    RETURN;
  END;

  IF @PasswordHash IS NULL OR @PasswordHash = ''
  BEGIN
    RAISERROR('Password is required.', 16, 1);
    RETURN;
  END;

  IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username)
  BEGIN
    RAISERROR('That username is already taken.', 16, 1);
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
    RAISERROR('Username is required.', 16, 1);
    RETURN;
  END;

  SELECT UserID, Username, PasswordHash, CreatedAt
  FROM dbo.Users
  WHERE Username = @Username;
END;
GO

-- =============================================
-- SEED DATA
-- =============================================

-- Users (UserID 1–6)
INSERT INTO dbo.Users (Username, PasswordHash, FirstName, LastName, DisplayName, CreatedAt) VALUES
('djmike',    'hash_abc123', 'Mike',    'Torres',  'DJ Mike',    '2025-01-01 00:00:00'),
('sarahk',    'hash_def456', 'Sarah',   'Kim',     'Sarah K',    '2025-01-02 00:00:00'),
('beat_luca', 'hash_ghi789', 'Luca',    'Mancini', 'Luca Beats', '2025-01-03 00:00:00'),
('nova_jay',  'hash_jkl012', 'Jasmine', 'Okafor',  'Nova Jay',   '2025-01-04 00:00:00'),
('tomwaves',  'hash_mno345', 'Tom',     'Walsh',   'Tomwaves',   '2025-01-05 00:00:00'),
('renegade',  'hash_pqr678', 'Riley',   'Nash',    'Renegade',   '2025-01-06 00:00:00');
GO

-- UserSessions
INSERT INTO dbo.UserSessions (UserID, SessionTokenHash, CreatedAt, ExpiresAt, RevokedAt) VALUES
(1, 'tok_hash_aaa111', '2025-04-01 10:00:00', '2025-04-08 10:00:00', NULL),
(2, 'tok_hash_bbb222', '2025-04-02 11:00:00', '2025-04-09 11:00:00', NULL),
(3, 'tok_hash_ccc333', '2025-04-03 12:00:00', '2025-04-10 12:00:00', NULL),
(1, 'tok_hash_ddd444', '2025-03-01 08:00:00', '2025-03-08 08:00:00', '2025-03-05 09:00:00'),
(4, 'tok_hash_eee555', '2025-04-04 09:00:00', '2025-04-11 09:00:00', NULL),
(5, 'tok_hash_fff666', '2025-04-05 14:00:00', '2025-04-12 14:00:00', '2025-04-06 10:00:00');
GO

-- UserSpotifyTokens
INSERT INTO dbo.UserSpotifyTokens (UserID, SpotifyUserID, AccessToken, RefreshToken, ExpiresAt, CreatedAt, UpdatedAt) VALUES
(1, 'spotify_user_mike',  'access_tok_mike_xyz',  'refresh_tok_mike_abc',  '2025-04-27 22:00:00', '2025-01-10 00:00:00', '2025-04-27 21:00:00'),
(2, 'spotify_user_sarah', 'access_tok_sarah_xyz', 'refresh_tok_sarah_abc', '2025-04-27 23:00:00', '2025-01-15 00:00:00', '2025-04-27 22:00:00'),
(3, 'spotify_user_luca',  'access_tok_luca_xyz',  'refresh_tok_luca_abc',  '2025-04-28 00:00:00', '2025-02-01 00:00:00', '2025-04-27 23:00:00');
GO

-- Artists (ArtistID 1–6)
INSERT INTO dbo.Artists (ArtistName, SpotifyArtistID, CreatedAt) VALUES
('Daft Punk',         '4tZwfgrHOc3mvqYlEYSvVi', '2025-01-01 00:00:00'),
('Kendrick Lamar',    '2YZyLoL8N0Wb9xBt1NhZWg', '2025-01-01 00:00:00'),
('Tame Impala',       '5INjqkS1o8h1imAzPqGZng', '2025-01-01 00:00:00'),
('Billie Eilish',     '6qqNVTkY8uBg9cP3Jd7DAH', '2025-01-01 00:00:00'),
('Doja Cat',          '5cj0lLjcoR7YOSnhnX0Po5', '2025-01-01 00:00:00'),
('Tyler the Creator', '4V8LLVI7PbaPR9LKe3Ii5T', '2025-01-01 00:00:00');
GO

-- Songs (SongID 1–12)
INSERT INTO dbo.Songs (SpotifyTrackID, SongName, ArtistID, AlbumName, DurationSeconds, IsExplicit, CreatedAt) VALUES
('track_001', 'Get Lucky',         1, 'Random Access Memories',  248, 0, '2025-01-01 00:00:00'),
('track_002', 'One More Time',     1, 'Discovery',               321, 0, '2025-01-01 00:00:00'),
('track_003', 'HUMBLE.',           2, 'DAMN.',                   177, 1, '2025-01-01 00:00:00'),
('track_004', 'DNA.',              2, 'DAMN.',                   185, 1, '2025-01-01 00:00:00'),
('track_005', 'Alright',           2, 'To Pimp a Butterfly',     215, 0, '2025-01-01 00:00:00'),
('track_006', 'The Less I Know',   3, 'Currents',                216, 0, '2025-01-01 00:00:00'),
('track_007', 'Let It Happen',     3, 'Currents',                467, 0, '2025-01-01 00:00:00'),
('track_008', 'bad guy',           4, 'When We All Fall Asleep', 194, 0, '2025-01-01 00:00:00'),
('track_009', 'Happier Than Ever', 4, 'Happier Than Ever',       295, 0, '2025-01-01 00:00:00'),
('track_010', 'Say So',            5, 'Hot Pink',                238, 0, '2025-01-01 00:00:00'),
('track_011', 'Woman',             5, 'Planet Her',              212, 0, '2025-01-01 00:00:00'),
('track_012', 'EARFQUAKE',         6, 'IGOR',                    193, 0, '2025-01-01 00:00:00');
GO

-- Sessions (SessionID 1–4)
INSERT INTO dbo.Sessions (SessionCode, SessionName, CreatedByUserID, CreatedAt, StartedAt, EndedAt, Status) VALUES
('FRNIT', 'Friday Night Kickback', 1, '2025-03-14 20:00:00', '2025-03-14 21:00:00', '2025-03-15 01:00:00', 'Ended'),
('RFTOP', 'Rooftop Session',       2, '2025-04-04 19:00:00', '2025-04-04 20:00:00', '2025-04-05 00:00:00', 'Ended'),
('CHILL', 'Chill Sunday Vibes',    3, '2025-04-27 14:00:00', '2025-04-27 15:00:00',  NULL,                 'Active'),
('OFFIC', 'Office Happy Hour',     1, '2025-04-25 16:00:00',  NULL,                   NULL,                'Pending');
GO

-- SessionParticipants
INSERT INTO dbo.SessionParticipants (SessionID, UserID, Role, JoinedAt, LeftAt) VALUES
(1, 1, 'Host',        '2025-03-14 21:00:00', '2025-03-15 01:00:00'),
(1, 2, 'Participant', '2025-03-14 21:05:00', '2025-03-15 00:45:00'),
(1, 3, 'Participant', '2025-03-14 21:10:00', '2025-03-15 00:50:00'),
(1, 4, 'Guest',       '2025-03-14 21:30:00', '2025-03-15 00:30:00'),
(1, 5, 'Guest',       '2025-03-14 22:00:00', '2025-03-14 23:30:00'),
(2, 2, 'Host',        '2025-04-04 20:00:00', '2025-04-05 00:00:00'),
(2, 1, 'Participant', '2025-04-04 20:10:00', '2025-04-04 23:50:00'),
(2, 5, 'Guest',       '2025-04-04 20:20:00', '2025-04-04 22:30:00'),
(2, 6, 'Guest',       '2025-04-04 20:30:00', '2025-04-04 23:00:00'),
(3, 3, 'Host',        '2025-04-27 15:00:00', NULL),
(3, 4, 'Participant', '2025-04-27 15:10:00', NULL),
(3, 6, 'Guest',       '2025-04-27 15:20:00', NULL),
(4, 1, 'Host',        '2025-04-25 16:00:00', NULL);
GO

-- QueueItems
-- Session 1: QueueItemID 1–8   (all Played)
-- Session 2: QueueItemID 9–14  (all Played)
-- Session 3: QueueItemID 15–18 (Played / Playing / Queued)
-- Session 4: QueueItemID 19–20 (Queued, session Pending)
INSERT INTO dbo.QueueItems (SessionID, SongID, AddedByUserID, Position, QueuedAt, Status, StartedAt, EndedAt) VALUES
(1,  1, 1, 1, '2025-03-14 21:00:00', 'Played',  '2025-03-14 21:01:00', '2025-03-14 21:05:08'),
(1,  3, 2, 2, '2025-03-14 21:04:00', 'Played',  '2025-03-14 21:05:08', '2025-03-14 21:08:05'),
(1,  8, 3, 3, '2025-03-14 21:06:00', 'Played',  '2025-03-14 21:08:05', '2025-03-14 21:11:19'),
(1,  6, 4, 4, '2025-03-14 21:09:00', 'Played',  '2025-03-14 21:11:19', '2025-03-14 21:15:00'),
(1,  2, 1, 5, '2025-03-14 21:13:00', 'Played',  '2025-03-14 21:15:00', '2025-03-14 21:20:21'),
(1, 10, 2, 6, '2025-03-14 21:17:00', 'Played',  '2025-03-14 21:20:21', '2025-03-14 21:24:19'),
(1,  4, 5, 7, '2025-03-14 21:20:00', 'Played',  '2025-03-14 21:24:19', '2025-03-14 21:27:24'),
(1, 12, 3, 8, '2025-03-14 21:24:00', 'Played',  '2025-03-14 21:27:24', '2025-03-14 21:30:37'),
(2,  2, 2, 1, '2025-04-04 20:00:00', 'Played',  '2025-04-04 20:02:00', '2025-04-04 20:07:21'),
(2,  7, 1, 2, '2025-04-04 20:05:00', 'Played',  '2025-04-04 20:07:21', '2025-04-04 20:15:08'),
(2,  9, 5, 3, '2025-04-04 20:09:00', 'Played',  '2025-04-04 20:15:08', '2025-04-04 20:20:03'),
(2,  3, 6, 4, '2025-04-04 20:14:00', 'Played',  '2025-04-04 20:20:03', '2025-04-04 20:23:00'),
(2,  1, 2, 5, '2025-04-04 20:19:00', 'Played',  '2025-04-04 20:23:00', '2025-04-04 20:27:08'),
(2, 11, 6, 6, '2025-04-04 20:23:00', 'Played',  '2025-04-04 20:27:08', '2025-04-04 20:30:40'),
(3,  5, 3, 1, '2025-04-27 15:00:00', 'Played',  '2025-04-27 15:01:00', '2025-04-27 15:04:35'),
(3,  6, 4, 2, '2025-04-27 15:03:00', 'Playing', '2025-04-27 15:04:35',  NULL),
(3, 12, 6, 3, '2025-04-27 15:05:00', 'Queued',   NULL,                   NULL),
(3,  8, 3, 4, '2025-04-27 15:06:00', 'Queued',   NULL,                   NULL),
(4,  1, 1, 1, '2025-04-25 16:05:00', 'Queued',   NULL,                   NULL),
(4,  3, 1, 2, '2025-04-25 16:06:00', 'Queued',   NULL,                   NULL);
GO

-- Votes
INSERT INTO dbo.Votes (QueueItemID, UserID, CreatedAt) VALUES
(1,  2, '2025-03-14 21:01:30'),
(1,  3, '2025-03-14 21:01:45'),
(1,  4, '2025-03-14 21:02:00'),
(2,  1, '2025-03-14 21:05:30'),
(2,  4, '2025-03-14 21:05:45'),
(2,  5, '2025-03-14 21:06:00'),
(3,  1, '2025-03-14 21:08:30'),
(3,  2, '2025-03-14 21:08:45'),
(4,  1, '2025-03-14 21:11:45'),
(4,  2, '2025-03-14 21:12:00'),
(4,  3, '2025-03-14 21:12:15'),
(4,  5, '2025-03-14 21:12:30'),
(5,  3, '2025-03-14 21:15:30'),
(5,  4, '2025-03-14 21:15:45'),
(6,  1, '2025-03-14 21:20:45'),
(6,  3, '2025-03-14 21:21:00'),
(7,  2, 'Upvote',    1, '2025-03-14 21:24:45'),
(7,  5, 'Downvote', -1, '2025-03-14 21:25:00'),
(8,  1, 'Upvote',    1, '2025-03-14 21:27:45'),
(8,  4, 'Upvote',    1, '2025-03-14 21:28:00'),
(9,  1, 'Upvote',    1, '2025-04-04 20:02:30'),
(9,  3, 'Upvote',    1, '2025-04-04 20:02:45'),
(10, 2, 'Upvote',    1, '2025-04-04 20:07:45'),
(10, 5, 'Upvote',    1, '2025-04-04 20:08:00'),
(10, 6, 'Downvote', -1, '2025-04-04 20:08:15'),
(11, 1, 'Upvote',    1, '2025-04-04 20:15:30'),
(11, 2, 'Upvote',    1, '2025-04-04 20:15:45'),
(12, 1, 'Upvote',    1, '2025-04-04 20:20:30'),
(12, 5, 'Upvote',    1, '2025-04-04 20:20:45'),
(13, 2, 'Upvote',    1, '2025-04-04 20:23:30'),
(13, 6, 'Upvote',    1, '2025-04-04 20:23:45'),
(14, 3, 'Upvote',    1, '2025-04-04 20:27:30'),
(15, 4, 'Upvote',    1, '2025-04-27 15:01:30'),
(15, 6, 'Upvote',    1, '2025-04-27 15:01:45'),
(16, 3, 'Upvote',    1, '2025-04-27 15:05:00'),
(16, 4, 'Downvote', -1, '2025-04-27 15:05:15');
GO
