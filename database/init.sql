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

USE PartyDJ;
GO

-- =============================================
-- USERS (45 rows)
-- =============================================
INSERT INTO dbo.Users (Username, PasswordHash, FirstName, LastName, DisplayName) VALUES
('djmike',      'hash_a1b2c3', 'Mike',     'Torres',    'DJ Mike'),
('sarahk',      'hash_d4e5f6', 'Sarah',    'Kim',       'Sarah K'),
('beat_luca',   'hash_g7h8i9', 'Luca',     'Mancini',   'Luca Beats'),
('nova_jay',    'hash_j1k2l3', 'Jasmine',  'Okafor',    'Nova Jay'),
('tomwaves',    'hash_m4n5o6', 'Tom',      'Walsh',     'Tomwaves'),
('ravi_mix',    'hash_p7q8r9', 'Ravi',     'Patel',     'Ravi Mix'),
('luna_drop',   'hash_s1t2u3', 'Luna',     'Reyes',     'Luna Drop'),
('bassking',    'hash_v4w5x6', 'Devon',    'Brooks',    'Bass King'),
('zara_bpm',    'hash_y7z8a9', 'Zara',     'Nguyen',    'Zara BPM'),
('hype_cole',   'hash_b1c2d3', 'Cole',     'Jackson',   'Hype Cole'),
('ellie_v',     'hash_e4f5g6', 'Eleanor',  'Vasquez',   'Ellie V'),
('spinz_mo',    'hash_h7i8j9', 'Mohammed', 'Al-Rashid', 'Spinz Mo'),
('priya_wav',   'hash_k1l2m3', 'Priya',    'Sharma',    'Priya Wav'),
('guest_alex',  'hash_n4o5p6', 'Alex',     'Chen',      'Alex'),
('guest_pat',   'hash_q7r8s9', 'Pat',      'Morgan',    NULL),
('djsam',       'hash_r1s2t3', 'Sam',      'Carter',    'DJ Sam'),
('beatrix',     'hash_u4v5w6', 'Beatrix',  'Hall',      'Beatrix'),
('waveform',    'hash_x7y8z9', 'Jordan',   'Lee',       'Waveform'),
('pulse_kim',   'hash_a2b3c4', 'Kimani',   'Osei',      'Pulse Kim'),
('mixmaster',   'hash_d5e6f7', 'Marco',    'Ferrari',   'Mixmaster'),
('aurora_dj',   'hash_g8h9i0', 'Aurora',   'Lindqvist', 'Aurora DJ'),
('subwoofer',   'hash_j3k4l5', 'Jake',     'Thornton',  'Subwoofer'),
('echo_finn',   'hash_m6n7o8', 'Finn',     'O''Brien',  'Echo Finn'),
('tempo_leo',   'hash_p9q0r1', 'Leo',      'Marchetti', 'Tempo Leo'),
('groove_ana',  'hash_s2t3u4', 'Ana',      'Pereira',   'Groove Ana'),
('vinyl_rex',   'hash_v5w6x7', 'Rex',      'Yamamoto',  'Vinyl Rex'),
('drop_zone',   'hash_y8z9a0', 'Dani',     'Soto',      'Drop Zone'),
('neon_kira',   'hash_b3c4d5', 'Kira',     'Ivanova',   'Neon Kira'),
('bass_elle',   'hash_e6f7g8', 'Elle',     'Dubois',    'Bass Elle'),
('hype_max',    'hash_h9i0j1', 'Max',      'Weber',     'Hype Max'),
('synth_joe',   'hash_k2l3m4', 'Joe',      'Nakamura',  'Synth Joe'),
('decibel',     'hash_n5o6p7', 'Nadia',    'Petrov',    'Decibel'),
('treble_t',    'hash_q8r9s0', 'Theo',     'Adeyemi',   'Treble T'),
('pitch_nia',   'hash_t1u2v3', 'Nia',      'Owusu',     'Pitch Nia'),
('cadence',     'hash_w4x5y6', 'Cam',      'Delacroix', 'Cadence'),
('rhythm_bo',   'hash_z7a8b9', 'Bo',       'Santana',   'Rhythm Bo'),
('sample_sue',  'hash_c0d1e2', 'Sue',      'Johansson', 'Sample Sue'),
('track_dan',   'hash_f3g4h5', 'Dan',      'Kowalski',  'Track Dan'),
('loop_gus',    'hash_i6j7k8', 'Gus',      'Ferreira',  'Loop Gus'),
('fade_mia',    'hash_l9m0n1', 'Mia',      'Andersen',  'Fade Mia'),
('reverb_ed',   'hash_o2p3q4', 'Ed',       'Tanaka',    'Reverb Ed'),
('chorus_li',   'hash_r5s6t7', 'Li',       'Zhang',     'Chorus Li'),
('bridge_nm',   'hash_u8v9w0', 'Nomi',     'Abebe',     'Bridge Nm'),
('hook_raj',    'hash_x1y2z3', 'Raj',      'Gupta',     'Hook Raj'),
('outro_dev',   'hash_a4b5c6', 'Dev',      'Chandra',   'Outro Dev');
GO

-- =============================================
-- USER SESSIONS (60 rows)
-- =============================================
INSERT INTO dbo.UserSessions (UserID, SessionTokenHash, CreatedAt, ExpiresAt, RevokedAt) VALUES
(1,  'tok_hash_001', '2025-04-20 18:00:00', '2025-04-21 18:00:00', NULL),
(1,  'tok_hash_002', '2025-04-25 20:00:00', '2025-04-26 20:00:00', NULL),
(2,  'tok_hash_003', '2025-04-21 09:00:00', '2025-04-22 09:00:00', '2025-04-21 14:00:00'),
(2,  'tok_hash_004', '2025-04-25 19:30:00', '2025-04-26 19:30:00', NULL),
(3,  'tok_hash_005', '2025-04-22 15:00:00', '2025-04-23 15:00:00', NULL),
(4,  'tok_hash_006', '2025-04-23 11:00:00', '2025-04-24 11:00:00', NULL),
(5,  'tok_hash_007', '2025-04-24 17:00:00', '2025-04-25 17:00:00', NULL),
(6,  'tok_hash_008', '2025-04-25 20:30:00', '2025-04-26 20:30:00', NULL),
(7,  'tok_hash_009', '2025-04-25 21:00:00', '2025-04-26 21:00:00', NULL),
(8,  'tok_hash_010', '2025-04-24 22:00:00', '2025-04-25 22:00:00', '2025-04-24 23:00:00'),
(9,  'tok_hash_011', '2025-04-25 20:00:00', '2025-04-26 20:00:00', NULL),
(10, 'tok_hash_012', '2025-04-25 19:00:00', '2025-04-26 19:00:00', NULL),
(11, 'tok_hash_013', '2025-04-23 14:00:00', '2025-04-24 14:00:00', NULL),
(12, 'tok_hash_014', '2025-04-25 21:30:00', '2025-04-26 21:30:00', NULL),
(13, 'tok_hash_015', '2025-04-22 10:00:00', '2025-04-23 10:00:00', NULL),
(14, 'tok_hash_016', '2025-04-25 20:15:00', '2025-04-26 20:15:00', NULL),
(15, 'tok_hash_017', '2025-04-25 20:45:00', '2025-04-26 20:45:00', NULL),
(1,  'tok_hash_018', '2025-04-26 08:00:00', '2025-04-27 08:00:00', NULL),
(3,  'tok_hash_019', '2025-04-26 09:00:00', '2025-04-27 09:00:00', NULL),
(6,  'tok_hash_020', '2025-04-26 10:00:00', '2025-04-27 10:00:00', NULL),
(16, 'tok_hash_021', '2025-04-25 18:00:00', '2025-04-26 18:00:00', NULL),
(17, 'tok_hash_022', '2025-04-25 18:30:00', '2025-04-26 18:30:00', NULL),
(18, 'tok_hash_023', '2025-04-25 19:00:00', '2025-04-26 19:00:00', NULL),
(19, 'tok_hash_024', '2025-04-25 19:15:00', '2025-04-26 19:15:00', NULL),
(20, 'tok_hash_025', '2025-04-25 19:45:00', '2025-04-26 19:45:00', NULL),
(21, 'tok_hash_026', '2025-04-26 20:00:00', '2025-04-27 20:00:00', NULL),
(22, 'tok_hash_027', '2025-04-26 20:10:00', '2025-04-27 20:10:00', NULL),
(23, 'tok_hash_028', '2025-04-26 20:20:00', '2025-04-27 20:20:00', NULL),
(24, 'tok_hash_029', '2025-04-26 20:30:00', '2025-04-27 20:30:00', NULL),
(25, 'tok_hash_030', '2025-04-26 20:40:00', '2025-04-27 20:40:00', NULL),
(26, 'tok_hash_031', '2025-04-26 21:00:00', '2025-04-27 21:00:00', NULL),
(27, 'tok_hash_032', '2025-04-26 21:10:00', '2025-04-27 21:10:00', NULL),
(28, 'tok_hash_033', '2025-04-26 21:20:00', '2025-04-27 21:20:00', NULL),
(29, 'tok_hash_034', '2025-04-26 21:30:00', '2025-04-27 21:30:00', NULL),
(30, 'tok_hash_035', '2025-04-26 21:40:00', '2025-04-27 21:40:00', NULL),
(31, 'tok_hash_036', '2025-04-26 22:00:00', '2025-04-27 22:00:00', NULL),
(32, 'tok_hash_037', '2025-04-26 22:10:00', '2025-04-27 22:10:00', '2025-04-26 23:00:00'),
(33, 'tok_hash_038', '2025-04-26 22:20:00', '2025-04-27 22:20:00', NULL),
(34, 'tok_hash_039', '2025-04-26 22:30:00', '2025-04-27 22:30:00', NULL),
(35, 'tok_hash_040', '2025-04-26 22:40:00', '2025-04-27 22:40:00', NULL),
(36, 'tok_hash_041', '2025-04-27 08:00:00', '2025-04-28 08:00:00', NULL),
(37, 'tok_hash_042', '2025-04-27 08:30:00', '2025-04-28 08:30:00', NULL),
(38, 'tok_hash_043', '2025-04-27 09:00:00', '2025-04-28 09:00:00', NULL),
(39, 'tok_hash_044', '2025-04-27 09:30:00', '2025-04-28 09:30:00', NULL),
(40, 'tok_hash_045', '2025-04-27 10:00:00', '2025-04-28 10:00:00', NULL),
(41, 'tok_hash_046', '2025-04-27 10:30:00', '2025-04-28 10:30:00', NULL),
(42, 'tok_hash_047', '2025-04-27 11:00:00', '2025-04-28 11:00:00', NULL),
(43, 'tok_hash_048', '2025-04-27 11:30:00', '2025-04-28 11:30:00', NULL),
(44, 'tok_hash_049', '2025-04-27 12:00:00', '2025-04-28 12:00:00', NULL),
(45, 'tok_hash_050', '2025-04-27 12:30:00', '2025-04-28 12:30:00', NULL),
(2,  'tok_hash_051', '2025-04-27 13:00:00', '2025-04-28 13:00:00', NULL),
(5,  'tok_hash_052', '2025-04-27 13:30:00', '2025-04-28 13:30:00', NULL),
(7,  'tok_hash_053', '2025-04-27 14:00:00', '2025-04-28 14:00:00', NULL),
(9,  'tok_hash_054', '2025-04-27 14:30:00', '2025-04-28 14:30:00', NULL),
(11, 'tok_hash_055', '2025-04-27 15:00:00', '2025-04-28 15:00:00', NULL),
(13, 'tok_hash_056', '2025-04-27 15:30:00', '2025-04-28 15:30:00', NULL),
(16, 'tok_hash_057', '2025-04-27 16:00:00', '2025-04-28 16:00:00', NULL),
(20, 'tok_hash_058', '2025-04-27 16:30:00', '2025-04-28 16:30:00', '2025-04-27 18:00:00'),
(25, 'tok_hash_059', '2025-04-27 17:00:00', '2025-04-28 17:00:00', NULL),
(30, 'tok_hash_060', '2025-04-27 17:30:00', '2025-04-28 17:30:00', NULL);
GO

-- =============================================
-- USER SPOTIFY TOKENS (24 rows)
-- =============================================
INSERT INTO dbo.UserSpotifyTokens (UserID, SpotifyUserID, AccessToken, RefreshToken, ExpiresAt, UpdatedAt) VALUES
(1,  'spotify_user_torres',    'acc_tok_long_001', 'ref_tok_long_001', '2025-04-26 21:00:00', '2025-04-25 20:00:00'),
(2,  'spotify_user_kim',       'acc_tok_long_002', 'ref_tok_long_002', '2025-04-26 20:30:00', '2025-04-25 19:30:00'),
(3,  'spotify_user_mancini',   'acc_tok_long_003', 'ref_tok_long_003', '2025-04-26 22:00:00', '2025-04-25 21:00:00'),
(6,  'spotify_user_patel',     'acc_tok_long_004', 'ref_tok_long_004', '2025-04-26 21:30:00', '2025-04-25 20:30:00'),
(7,  'spotify_user_reyes',     'acc_tok_long_005', 'ref_tok_long_005', '2025-04-27 00:00:00', '2025-04-26 23:00:00'),
(8,  'spotify_user_brooks',    'acc_tok_long_006', 'ref_tok_long_006', '2025-04-25 23:00:00', '2025-04-25 22:00:00'),
(11, 'spotify_user_vasquez',   'acc_tok_long_007', 'ref_tok_long_007', '2025-04-24 15:00:00', '2025-04-23 14:00:00'),
(12, 'spotify_user_alrashid',  'acc_tok_long_008', 'ref_tok_long_008', '2025-04-26 22:30:00', '2025-04-25 21:30:00'),
(4,  'spotify_user_okafor',    'acc_tok_long_009', 'ref_tok_long_009', '2025-04-27 20:00:00', '2025-04-26 19:00:00'),
(5,  'spotify_user_walsh',     'acc_tok_long_010', 'ref_tok_long_010', '2025-04-27 20:30:00', '2025-04-26 19:30:00'),
(9,  'spotify_user_nguyen',    'acc_tok_long_011', 'ref_tok_long_011', '2025-04-27 21:00:00', '2025-04-26 20:00:00'),
(10, 'spotify_user_jackson',   'acc_tok_long_012', 'ref_tok_long_012', '2025-04-27 21:30:00', '2025-04-26 20:30:00'),
(13, 'spotify_user_sharma',    'acc_tok_long_013', 'ref_tok_long_013', '2025-04-27 22:00:00', '2025-04-26 21:00:00'),
(16, 'spotify_user_carter',    'acc_tok_long_014', 'ref_tok_long_014', '2025-04-27 18:00:00', '2025-04-26 17:00:00'),
(17, 'spotify_user_hall',      'acc_tok_long_015', 'ref_tok_long_015', '2025-04-27 18:30:00', '2025-04-26 17:30:00'),
(18, 'spotify_user_lee',       'acc_tok_long_016', 'ref_tok_long_016', '2025-04-27 19:00:00', '2025-04-26 18:00:00'),
(19, 'spotify_user_osei',      'acc_tok_long_017', 'ref_tok_long_017', '2025-04-27 19:30:00', '2025-04-26 18:30:00'),
(20, 'spotify_user_ferrari',   'acc_tok_long_018', 'ref_tok_long_018', '2025-04-27 20:00:00', '2025-04-26 19:00:00'),
(21, 'spotify_user_lindqvist', 'acc_tok_long_019', 'ref_tok_long_019', '2025-04-27 20:30:00', '2025-04-26 19:30:00'),
(22, 'spotify_user_thornton',  'acc_tok_long_020', 'ref_tok_long_020', '2025-04-27 21:00:00', '2025-04-26 20:00:00'),
(24, 'spotify_user_marchetti', 'acc_tok_long_021', 'ref_tok_long_021', '2025-04-27 21:30:00', '2025-04-26 20:30:00'),
(25, 'spotify_user_pereira',   'acc_tok_long_022', 'ref_tok_long_022', '2025-04-27 22:00:00', '2025-04-26 21:00:00'),
(26, 'spotify_user_yamamoto',  'acc_tok_long_023', 'ref_tok_long_023', '2025-04-27 22:30:00', '2025-04-26 21:30:00'),
(27, 'spotify_user_soto',      'acc_tok_long_024', 'ref_tok_long_024', '2025-04-27 23:00:00', '2025-04-26 22:00:00');
GO

-- =============================================
-- ARTISTS (30 rows)
-- =============================================
INSERT INTO dbo.Artists (ArtistName, SpotifyArtistID) VALUES
('Daft Punk',           '4tZwfgrHOc3mvqYlEYSvVi'),
('Kendrick Lamar',      '2YZyLoL8N0Wb9xBt1NhZWg'),
('Tame Impala',         '5INjqkS1o8h1imAzPqGZng'),
('Billie Eilish',       '6qqNVTkY8uBg9cP3Jd7DAH'),
('Doja Cat',            '5cj0lLjcoR7YOSnhnX0Po5'),
('The Weeknd',          '1Xyo4u8uXC1ZmMpatF05PJ'),
('SZA',                 '7tYKF4w9nC0nq9CsPZTHyP'),
('Tyler the Creator',   '4V8LLVI7s6OjdmXarkpo6b'),
('Jungle',              '4sTQVOfmore4wd61pG6KPQ'),
('Fred again..',        '4oLeXFyACqeem2VImYeBFe'),
('Drake',               '3TVXtAsR1Inumwj472S9r4'),
('Bad Bunny',           '4q3ewBCX7sLwd24euuV69X'),
('Taylor Swift',        '06HL4z0CvFAxyc27GXpf02'),
('Post Malone',         '246dkjvS1zLTtiykXe5h60'),
('Ariana Grande',       '66CXWjxzNUsdJxJ2JdwvnR'),
('Frank Ocean',         '2h93pZq0e7k5yf4dywlkpM'),
('Childish Gambino',    '5f7VJjfbwm532GiveGC0ZK'),
('J. Cole',             '6l3HvQ5sa6mXTsMTB6Tof8'),
('Lizzo',               '56oDe4LjkKxsDFt5doriFt'),
('Harry Styles',        '6KImCVD70vtIoJWnq6nGn3'),
('Olivia Rodrigo',      '1McMsnEElThX1knmY4oliG'),
('Lil Nas X',           '7jVv8c5Fj3E9VhNjxT4snq'),
('Glass Animals',       '4yvcSjfu4PC0CYQyLy4wSq'),
('Flume',               '6nxWCVXbOlEVRexSbLsTer'),
('Disclosure',          '6nS5roXSAGhTGr34W6n7Et'),
('Four Tet',            '7Eu1txygG6nJttLHbZdQOh'),
('Caribou',             '3nESbFMFcCRFvEOHQWJXfg'),
('Jamie xx',            '5MbkHqQDCQvGtAMnhEJI3q'),
('Kaytranada',          '5LHRHt1k9lMyONurDHEdrp'),
('Little Simz',         '5oCo5E9iQmWFTWBLbpPOOt');
GO

-- =============================================
-- SONGS (75 rows)
-- =============================================
INSERT INTO dbo.Songs (SpotifyTrackID, SongName, ArtistID, AlbumName, DurationSeconds, IsExplicit) VALUES
('track_001', 'Get Lucky',                      1,  'Random Access Memories', 248, 0),
('track_002', 'One More Time',                  1,  'Discovery',              321, 0),
('track_003', 'Harder Better Faster',           1,  'Discovery',              224, 0),
('track_004', 'HUMBLE.',                        2,  'DAMN.',                  177, 1),
('track_005', 'DNA.',                           2,  'DAMN.',                  185, 1),
('track_006', 'Alright',                        2,  'To Pimp a Butterfly',    219, 1),
('track_007', 'The Less I Know',                3,  'Currents',               216, 0),
('track_008', 'Let It Happen',                  3,  'Currents',               467, 0),
('track_009', 'Feels Like We Only Go Backwards',3,  'Lonerism',               203, 0),
('track_010', 'bad guy',                        4,  'When We All Fall Asleep',194, 0),
('track_011', 'Happier Than Ever',              4,  'Happier Than Ever',      295, 0),
('track_012', 'Say So',                         5,  'Hot Pink',               238, 0),
('track_013', 'Woman',                          5,  'Planet Her',             212, 1),
('track_014', 'Blinding Lights',                6,  'After Hours',            200, 0),
('track_015', 'Starboy',                        6,  'Starboy',                230, 1),
('track_016', 'Save Your Tears',                6,  'After Hours',            215, 0),
('track_017', 'Kill Bill',                      7,  'SOS',                    153, 1),
('track_018', 'Good Days',                      7,  'Good Days',              279, 0),
('track_019', 'Flower Boy',                     8,  'Flower Boy',             207, 1),
('track_020', 'See You Again',                  8,  'Flower Boy',             261, 1),
('track_021', 'Keep Moving',                    9,  'Jungle',                 220, 0),
('track_022', 'Heavy California',               9,  'For Emma',               198, 0),
('track_023', 'Danielle',                      10,  'USB',                    237, 0),
('track_024', 'Marea',                         10,  'USB',                    269, 0),
('track_025', 'Blouse',                         7,  'SOS',                    189, 1),
('track_026', 'Gods Plan',                     11,  'Scorpion',               198, 1),
('track_027', 'Hotline Bling',                 11,  'Views',                  267, 0),
('track_028', 'In My Feelings',                11,  'Scorpion',               218, 1),
('track_029', 'Titi Me Pregunto',              12,  'Un Verano Sin Ti',       238, 0),
('track_030', 'Me Porto Bonito',               12,  'Un Verano Sin Ti',       178, 1),
('track_031', 'Anti-Hero',                     13,  'Midnights',              200, 0),
('track_032', 'Shake It Off',                  13,  '1989',                   219, 0),
('track_033', 'Cruel Summer',                  13,  'Lover',                  178, 0),
('track_034', 'Circles',                       14,  "Hollywood's Bleeding",   215, 0),
('track_035', 'Sunflower',                     14,  'Hollywood Bleeding',     158, 0),
('track_036', 'Seven Rings',                   15,  'Thank U Next',           178, 1),
('track_037', 'Thank U Next',                  15,  'Thank U Next',           207, 0),
('track_038', 'Nights',                        16,  'Blonde',                 307, 1),
('track_039', 'Pink White',                    16,  'Blonde',                 182, 0),
('track_040', 'Redbone',                       17,  'Awaken My Love',         326, 0),
('track_041', 'This Is America',               17,  'Awaken My Love',         234, 1),
('track_042', 'No Role Modelz',                18,  '2014 Forest Hills Drive',293, 1),
('track_043', 'MIDDLE CHILD',                  18,  'KOD',                    222, 1),
('track_044', 'Good as Hell',                  19,  'Cuz I Love You',         162, 0),
('track_045', 'Juice',                         19,  'Cuz I Love You',         182, 0),
('track_046', 'As It Was',                     20,  "Harry's House",          167, 0),
('track_047', 'Watermelon Sugar',              20,  'Fine Line',              174, 0),
('track_048', 'Drivers License',               21,  'SOUR',                   242, 0),
('track_049', 'Good 4 U',                      21,  'SOUR',                   178, 0),
('track_050', 'MONTERO',                       22,  'MONTERO',                137, 1),
('track_051', 'Old Town Road',                 22,  '7 EP',                   113, 0),
('track_052', 'Heat Waves',                    23,  'Dreamland',              238, 0),
('track_053', 'Pork Soda',                     23,  'How to Be a Human Being',163, 0),
('track_054', 'Never Be Like You',             24,  'Skin',                   239, 0),
('track_055', 'Say It',                        24,  'Skin',                   205, 0),
('track_056', 'Latch',                         25,  'Settle',                 323, 0),
('track_057', 'You Me',                        25,  'Settle',                 389, 0),
('track_058', 'Two Thousand and Seventeen',    26,  'New Energy',             337, 0),
('track_059', 'Baby',                          26,  'Rounds',                 261, 0),
('track_060', 'Cant Do Without You',           27,  'Our Love',               338, 0),
('track_061', 'Sun',                           27,  'Swim',                   394, 0),
('track_062', 'Loud Places',                   28,  'In Colour',              239, 0),
('track_063', 'Gosh',                          28,  'In Colour',              262, 0),
('track_064', 'Ten Percent',                   29,  'BUBBLE T',               219, 0),
('track_065', 'Chances',                       29,  'BUBBLE T',               196, 0),
('track_066', 'Introvert',                     30,  'Sometimes I Might Be Introvert', 349, 0),
('track_067', 'Woman',                         30,  'Sometimes I Might Be Introvert', 212, 0),
('track_068', 'Cant Feel My Face',             6,   'Beauty Behind the Madness', 213, 0),
('track_069', 'Shirt',                         7,   'SOS',                    260, 1),
('track_070', 'EARFQUAKE',                     8,   'Igor',                   198, 0),
('track_071', 'Busy Earnin',                   9,   'Jungle',                 208, 0),
('track_072', 'Delilah',                       10,  'USB',                    252, 0),
('track_073', 'Within',                        1,   'Random Access Memories', 230, 0),
('track_074', 'Swimming Pools',                2,   'good kid m.A.A.d city',  313, 1),
('track_075', 'Borderline',                    3,   'The Slow Rush',          223, 0);
GO

-- =============================================
-- SESSIONS (30 rows)
-- =============================================
INSERT INTO dbo.Sessions (SessionCode, SessionName, CreatedByUserID, CreatedAt, StartedAt, EndedAt, Status) VALUES
(N'PARTY', 'Friday Night Kickback',   1,  '2025-04-25 20:50:00', '2025-04-25 21:00:00', NULL,                    N'Active'),
(N'RFTOP', 'Rooftop Session',         2,  '2025-04-24 19:45:00', '2025-04-24 20:00:00', '2025-04-24 23:30:00',  N'Ended'),
(N'CHILL', 'Chill Sunday Vibes',      3,  '2025-04-26 14:00:00', NULL,                  NULL,                    N'Pending'),
(N'OFFCE', 'Office Happy Hour',       1,  '2025-04-23 16:45:00', '2025-04-23 17:00:00', '2025-04-23 19:00:00',  N'Ended'),
(N'BSMNT', 'Basement Bangers',        6,  '2025-04-25 21:50:00', '2025-04-25 22:00:00', NULL,                    N'Active'),
(N'LUNAT', 'Luna Late Night',         7,  '2025-04-26 22:50:00', '2025-04-26 23:00:00', NULL,                    N'Active'),
(N'BDAYY', 'Birthday Bash',           8,  '2025-04-22 17:50:00', '2025-04-22 18:00:00', '2025-04-23 00:00:00',  N'Ended'),
(N'STUDY', 'Study Lo-fi Session',    11,  '2025-04-21 13:55:00', '2025-04-21 14:00:00', '2025-04-21 18:00:00',  N'Ended'),
(N'RAAVE', 'Mini Rave Friday',       12,  '2025-04-25 22:50:00', '2025-04-25 23:00:00', NULL,                    N'Paused'),
(N'SUMRV', 'Summer Vibes Warmup',     2,  '2025-04-26 17:00:00', NULL,                  NULL,                    N'Pending'),
(N'DANCE', 'Saturday Night Dance',   16,  '2025-04-26 20:50:00', '2025-04-26 21:00:00', NULL,                    N'Active'),
(N'GROVY', 'Groovy Afternoon',       17,  '2025-04-26 14:50:00', '2025-04-26 15:00:00', '2025-04-26 18:00:00',  N'Ended'),
(N'WAVEZ', 'Wave Check Session',     18,  '2025-04-27 20:00:00', '2025-04-27 20:10:00', NULL,                    N'Active'),
(N'MIXES', 'Mix Tape Night',          4,  '2025-04-27 21:00:00', NULL,                  NULL,                    N'Pending'),
(N'BEATS', 'Beat Battle',             5,  '2025-04-20 18:50:00', '2025-04-20 19:00:00', '2025-04-20 22:00:00',  N'Ended'),
(N'TUNES', 'Tune In Tuesday',         9,  '2025-04-22 19:50:00', '2025-04-22 20:00:00', NULL,                    N'Active'),
(N'HIPHP', 'Hip-Hop Cypher',         10,  '2025-04-23 21:50:00', '2025-04-23 22:00:00', '2025-04-24 01:00:00',  N'Ended'),
(N'INDIE', 'Indie Night',            13,  '2025-04-24 21:50:00', '2025-04-24 22:00:00', NULL,                    N'Paused'),
(N'NEONS', 'Neon Lights Party',      19,  '2025-04-26 22:50:00', '2025-04-26 23:00:00', NULL,                    N'Active'),
(N'JAZZY', 'Jazz and Chill',         20,  '2025-04-25 17:50:00', '2025-04-25 18:00:00', '2025-04-25 21:00:00',  N'Ended'),
(N'SOULZ', 'Soul Sunday',            21,  '2025-04-27 14:50:00', '2025-04-27 15:00:00', NULL,                    N'Active'),
(N'FUNKY', 'Funky Fresh Queue',      22,  '2025-04-27 18:00:00', NULL,                  NULL,                    N'Pending'),
(N'POPPY', 'Pop Hits Only',           4,  '2025-04-19 19:50:00', '2025-04-19 20:00:00', '2025-04-19 23:00:00',  N'Ended'),
(N'AMBNT', 'Ambient Lounge',         24,  '2025-04-27 20:50:00', '2025-04-27 21:00:00', NULL,                    N'Active'),
(N'HOUSE', 'House Heads Only',       25,  '2025-04-26 23:50:00', '2025-04-27 00:00:00', '2025-04-27 03:00:00',  N'Ended'),
(N'DUBST', 'Dubstep Drop Zone',      26,  '2025-04-27 21:50:00', '2025-04-27 22:00:00', NULL,                    N'Active'),
(N'TECHX', 'Techno Thursday',        27,  '2025-04-24 22:50:00', '2025-04-24 23:00:00', NULL,                    N'Paused'),
(N'VIBEX', 'Good Vibes Only',        24,  '2025-04-27 19:50:00', '2025-04-27 20:00:00', NULL,                    N'Active'),
(N'LOFIX', 'Lo-Fi Study Hall',       25,  '2025-04-21 09:50:00', '2025-04-21 10:00:00', '2025-04-21 14:00:00',  N'Ended'),
(N'DISCS', 'Disco Fever Night',       5,  '2025-04-28 19:00:00', NULL,                  NULL,                    N'Pending');
GO

-- =============================================
-- SESSION PARTICIPANTS (84 rows)
-- =============================================
INSERT INTO dbo.SessionParticipants (SessionID, UserID, JoinedAt, LeftAt, Role) VALUES
-- Session 1: Friday Night Kickback
(1,  1,  '2025-04-25 21:00:00', NULL,                   N'Host'),
(1,  2,  '2025-04-25 21:05:00', NULL,                   N'Participant'),
(1,  4,  '2025-04-25 21:08:00', NULL,                   N'Participant'),
(1,  9,  '2025-04-25 21:12:00', NULL,                   N'Guest'),
(1,  14, '2025-04-25 21:20:00', NULL,                   N'Guest'),
-- Session 2: Rooftop Session (Ended)
(2,  2,  '2025-04-24 20:00:00', '2025-04-24 23:30:00',  N'Host'),
(2,  1,  '2025-04-24 20:05:00', '2025-04-24 23:30:00',  N'Participant'),
(2,  5,  '2025-04-24 20:10:00', '2025-04-24 22:30:00',  N'Guest'),
(2,  10, '2025-04-24 20:15:00', '2025-04-24 23:30:00',  N'Participant'),
-- Session 3: Chill Sunday (Pending)
(3,  3,  '2025-04-26 14:00:00', NULL,                   N'Host'),
(3,  7,  '2025-04-26 14:02:00', NULL,                   N'Participant'),
-- Session 4: Office Happy Hour (Ended)
(4,  1,  '2025-04-23 17:00:00', '2025-04-23 19:00:00',  N'Host'),
(4,  11, '2025-04-23 17:05:00', '2025-04-23 18:30:00',  N'Participant'),
(4,  13, '2025-04-23 17:10:00', '2025-04-23 19:00:00',  N'Participant'),
-- Session 5: Basement Bangers
(5,  6,  '2025-04-25 22:00:00', NULL,                   N'Host'),
(5,  3,  '2025-04-25 22:05:00', NULL,                   N'Participant'),
(5,  8,  '2025-04-25 22:10:00', NULL,                   N'Participant'),
(5,  15, '2025-04-25 22:15:00', NULL,                   N'Guest'),
-- Session 6: Luna Late Night
(6,  7,  '2025-04-26 23:00:00', NULL,                   N'Host'),
(6,  4,  '2025-04-26 23:05:00', NULL,                   N'Participant'),
(6,  9,  '2025-04-26 23:08:00', NULL,                   N'Guest'),
-- Session 7: Birthday Bash (Ended)
(7,  8,  '2025-04-22 18:00:00', '2025-04-23 00:00:00',  N'Host'),
(7,  2,  '2025-04-22 18:10:00', '2025-04-22 23:45:00',  N'Participant'),
(7,  5,  '2025-04-22 18:15:00', '2025-04-23 00:00:00',  N'Participant'),
-- Session 8: Study Lo-fi (Ended)
(8,  11, '2025-04-21 14:00:00', '2025-04-21 18:00:00',  N'Host'),
(8,  13, '2025-04-21 14:10:00', '2025-04-21 17:30:00',  N'Participant'),
-- Session 9: Mini Rave (Paused)
(9,  12, '2025-04-25 23:00:00', NULL,                   N'Host'),
(9,  10, '2025-04-25 23:05:00', NULL,                   N'Participant'),
-- Session 11: Saturday Night Dance
(11, 16, '2025-04-26 21:00:00', NULL,                   N'Host'),
(11, 17, '2025-04-26 21:05:00', NULL,                   N'Participant'),
(11, 18, '2025-04-26 21:08:00', NULL,                   N'Participant'),
(11, 19, '2025-04-26 21:10:00', NULL,                   N'Guest'),
(11, 33, '2025-04-26 21:15:00', NULL,                   N'Guest'),
-- Session 12: Groovy Afternoon (Ended)
(12, 17, '2025-04-26 15:00:00', '2025-04-26 18:00:00',  N'Host'),
(12, 20, '2025-04-26 15:05:00', '2025-04-26 18:00:00',  N'Participant'),
(12, 21, '2025-04-26 15:10:00', '2025-04-26 17:30:00',  N'Guest'),
-- Session 13: Wave Check
(13, 18, '2025-04-27 20:10:00', NULL,                   N'Host'),
(13, 22, '2025-04-27 20:15:00', NULL,                   N'Participant'),
(13, 23, '2025-04-27 20:18:00', NULL,                   N'Participant'),
(13, 34, '2025-04-27 20:20:00', NULL,                   N'Guest'),
-- Session 14: Mix Tape Night (Pending)
(14, 4,  '2025-04-27 21:00:00', NULL,                   N'Host'),
(14, 35, '2025-04-27 21:02:00', NULL,                   N'Participant'),
-- Session 15: Beat Battle (Ended)
(15, 5,  '2025-04-20 19:00:00', '2025-04-20 22:00:00',  N'Host'),
(15, 6,  '2025-04-20 19:05:00', '2025-04-20 22:00:00',  N'Participant'),
(15, 24, '2025-04-20 19:10:00', '2025-04-20 21:30:00',  N'Participant'),
(15, 36, '2025-04-20 19:15:00', '2025-04-20 22:00:00',  N'Guest'),
-- Session 16: Tune In Tuesday
(16, 9,  '2025-04-22 20:00:00', NULL,                   N'Host'),
(16, 25, '2025-04-22 20:05:00', NULL,                   N'Participant'),
(16, 37, '2025-04-22 20:08:00', NULL,                   N'Guest'),
-- Session 17: Hip-Hop Cypher (Ended)
(17, 10, '2025-04-23 22:00:00', '2025-04-24 01:00:00',  N'Host'),
(17, 26, '2025-04-23 22:05:00', '2025-04-24 01:00:00',  N'Participant'),
(17, 38, '2025-04-23 22:10:00', '2025-04-24 00:30:00',  N'Guest'),
-- Session 18: Indie Night (Paused)
(18, 13, '2025-04-24 22:00:00', NULL,                   N'Host'),
(18, 27, '2025-04-24 22:05:00', NULL,                   N'Participant'),
(18, 39, '2025-04-24 22:08:00', NULL,                   N'Guest'),
-- Session 19: Neon Lights Party
(19, 19, '2025-04-26 23:00:00', NULL,                   N'Host'),
(19, 28, '2025-04-26 23:05:00', NULL,                   N'Participant'),
(19, 40, '2025-04-26 23:08:00', NULL,                   N'Guest'),
-- Session 20: Jazz and Chill (Ended)
(20, 20, '2025-04-25 18:00:00', '2025-04-25 21:00:00',  N'Host'),
(20, 29, '2025-04-25 18:05:00', '2025-04-25 21:00:00',  N'Participant'),
(20, 41, '2025-04-25 18:10:00', '2025-04-25 20:30:00',  N'Guest'),
-- Session 21: Soul Sunday
(21, 21, '2025-04-27 15:00:00', NULL,                   N'Host'),
(21, 30, '2025-04-27 15:05:00', NULL,                   N'Participant'),
(21, 42, '2025-04-27 15:08:00', NULL,                   N'Guest'),
-- Session 23: Pop Hits Only (Ended)
(23, 4,  '2025-04-19 20:00:00', '2025-04-19 23:00:00',  N'Host'),
(23, 31, '2025-04-19 20:05:00', '2025-04-19 23:00:00',  N'Participant'),
(23, 43, '2025-04-19 20:10:00', '2025-04-19 22:45:00',  N'Guest'),
-- Session 24: Ambient Lounge
(24, 24, '2025-04-27 21:00:00', NULL,                   N'Host'),
(24, 32, '2025-04-27 21:05:00', NULL,                   N'Participant'),
-- Session 25: House Heads Only (Ended)
(25, 25, '2025-04-27 00:00:00', '2025-04-27 03:00:00',  N'Host'),
(25, 44, '2025-04-27 00:05:00', '2025-04-27 03:00:00',  N'Participant'),
(25, 45, '2025-04-27 00:10:00', '2025-04-27 02:30:00',  N'Guest'),
-- Session 26: Dubstep Drop Zone
(26, 26, '2025-04-27 22:00:00', NULL,                   N'Host'),
(26, 33, '2025-04-27 22:05:00', NULL,                   N'Participant'),
-- Session 27: Techno Thursday (Paused)
(27, 27, '2025-04-24 23:00:00', NULL,                   N'Host'),
(27, 34, '2025-04-24 23:05:00', NULL,                   N'Participant'),
-- Session 28: Good Vibes Only
(28, 24, '2025-04-27 20:00:00', NULL,                   N'Host'),
(28, 35, '2025-04-27 20:05:00', NULL,                   N'Participant'),
(28, 44, '2025-04-27 20:08:00', NULL,                   N'Guest'),
-- Session 29: Lo-Fi Study Hall (Ended)
(29, 25, '2025-04-21 10:00:00', '2025-04-21 14:00:00',  N'Host'),
(29, 36, '2025-04-21 10:05:00', '2025-04-21 13:30:00',  N'Participant');
GO

-- =============================================
-- QUEUE ITEMS (107 rows)
-- =============================================
INSERT INTO dbo.QueueItems (SessionID, SongID, AddedByUserID, Position, QueuedAt, Status, StartedAt, EndedAt) VALUES
-- Session 1: Active (6 items)
(1, 1,  1,  1, '2025-04-25 21:00:00', N'Played',  '2025-04-25 21:01:00', '2025-04-25 21:05:08'),
(1, 4,  2,  2, '2025-04-25 21:02:00', N'Played',  '2025-04-25 21:05:08', '2025-04-25 21:08:05'),
(1, 14, 1,  3, '2025-04-25 21:04:00', N'Playing', '2025-04-25 21:08:05', NULL),
(1, 7,  4,  4, '2025-04-25 21:06:00', N'Queued',  NULL,                  NULL),
(1, 12, 9,  5, '2025-04-25 21:07:00', N'Queued',  NULL,                  NULL),
(1, 23, 14, 6, '2025-04-25 21:09:00', N'Queued',  NULL,                  NULL),
-- Session 2: Ended (5 items)
(2, 2,  2,  1, '2025-04-24 20:00:00', N'Played',  '2025-04-24 20:02:00', '2025-04-24 20:07:21'),
(2, 8,  1,  2, '2025-04-24 20:03:00', N'Played',  '2025-04-24 20:07:21', '2025-04-24 20:15:09'),
(2, 11, 5,  3, '2025-04-24 20:05:00', N'Played',  '2025-04-24 20:15:09', '2025-04-24 20:20:04'),
(2, 15, 10, 4, '2025-04-24 20:08:00', N'Played',  '2025-04-24 20:20:04', '2025-04-24 20:24:14'),
(2, 18, 2,  5, '2025-04-24 20:10:00', N'Played',  '2025-04-24 20:24:14', '2025-04-24 20:29:03'),
-- Session 3: Pending (2 items)
(3, 24, 3,  1, '2025-04-26 14:00:00', N'Queued',  NULL,                  NULL),
(3, 5,  7,  2, '2025-04-26 14:01:00', N'Queued',  NULL,                  NULL),
-- Session 4: Ended (4 items)
(4, 3,  1,  1, '2025-04-23 17:00:00', N'Played',  '2025-04-23 17:01:00', '2025-04-23 17:04:44'),
(4, 16, 13, 2, '2025-04-23 17:02:00', N'Played',  '2025-04-23 17:04:44', '2025-04-23 17:08:19'),
(4, 9,  11, 3, '2025-04-23 17:03:00', N'Played',  '2025-04-23 17:08:19', '2025-04-23 17:11:42'),
(4, 21, 1,  4, '2025-04-23 17:05:00', N'Skipped', '2025-04-23 17:11:42', '2025-04-23 17:12:10'),
-- Session 5: Active (5 items)
(5, 6,  6,  1, '2025-04-25 22:00:00', N'Played',  '2025-04-25 22:01:00', '2025-04-25 22:04:39'),
(5, 13, 3,  2, '2025-04-25 22:02:00', N'Played',  '2025-04-25 22:04:39', '2025-04-25 22:08:12'),
(5, 4,  8,  3, '2025-04-25 22:03:00', N'Playing', '2025-04-25 22:08:12', NULL),
(5, 20, 6,  4, '2025-04-25 22:05:00', N'Queued',  NULL,                  NULL),
(5, 25, 15, 5, '2025-04-25 22:06:00', N'Queued',  NULL,                  NULL),
-- Session 6: Active (3 items)
(6, 10, 7,  1, '2025-04-26 23:00:00', N'Played',  '2025-04-26 23:01:00', '2025-04-26 23:04:14'),
(6, 17, 4,  2, '2025-04-26 23:02:00', N'Playing', '2025-04-26 23:04:14', NULL),
(6, 22, 9,  3, '2025-04-26 23:03:00', N'Queued',  NULL,                  NULL),
-- Session 7: Ended (3 items)
(7, 14, 8,  1, '2025-04-22 18:00:00', N'Played',  '2025-04-22 18:01:00', '2025-04-22 18:04:20'),
(7, 1,  2,  2, '2025-04-22 18:02:00', N'Played',  '2025-04-22 18:04:20', '2025-04-22 18:08:28'),
(7, 19, 5,  3, '2025-04-22 18:03:00', N'Played',  '2025-04-22 18:08:28', '2025-04-22 18:11:55'),
-- Session 8: Ended (3 items)
(8, 9,  11, 1, '2025-04-21 14:00:00', N'Played',  '2025-04-21 14:01:00', '2025-04-21 14:04:43'),
(8, 22, 13, 2, '2025-04-21 14:02:00', N'Played',  '2025-04-21 14:04:43', '2025-04-21 14:08:01'),
(8, 24, 11, 3, '2025-04-21 14:03:00', N'Played',  '2025-04-21 14:08:01', '2025-04-21 14:12:29'),
-- Session 9: Paused (4 items)
(9, 5,  12, 1, '2025-04-25 23:00:00', N'Played',  '2025-04-25 23:01:00', '2025-04-25 23:04:05'),
(9, 6,  10, 2, '2025-04-25 23:02:00', N'Played',  '2025-04-25 23:04:05', '2025-04-25 23:07:39'),
(9, 4,  12, 3, '2025-04-25 23:03:00', N'Paused',  '2025-04-25 23:07:39', NULL),
(9, 15, 10, 4, '2025-04-25 23:05:00', N'Queued',  NULL,                  NULL),
-- Session 11: Saturday Night Dance (5 items)
(11, 31, 16, 1, '2025-04-26 21:00:00', N'Played',  '2025-04-26 21:01:00', '2025-04-26 21:04:20'),
(11, 46, 17, 2, '2025-04-26 21:02:00', N'Played',  '2025-04-26 21:04:20', '2025-04-26 21:07:07'),
(11, 52, 16, 3, '2025-04-26 21:03:00', N'Playing', '2025-04-26 21:07:07', NULL),
(11, 26, 19, 4, '2025-04-26 21:05:00', N'Queued',  NULL,                  NULL),
(11, 33, 18, 5, '2025-04-26 21:06:00', N'Queued',  NULL,                  NULL),
-- Session 12: Groovy Afternoon Ended (4 items)
(12, 40, 17, 1, '2025-04-26 15:00:00', N'Played',  '2025-04-26 15:01:00', '2025-04-26 15:06:26'),
(12, 64, 20, 2, '2025-04-26 15:02:00', N'Played',  '2025-04-26 15:06:26', '2025-04-26 15:10:05'),
(12, 71, 21, 3, '2025-04-26 15:03:00', N'Played',  '2025-04-26 15:10:05', '2025-04-26 15:13:33'),
(12, 57, 17, 4, '2025-04-26 15:04:00', N'Played',  '2025-04-26 15:13:33', '2025-04-26 15:20:02'),
-- Session 13: Wave Check (4 items)
(13, 54, 18, 1, '2025-04-27 20:10:00', N'Played',  '2025-04-27 20:11:00', '2025-04-27 20:15:59'),
(13, 62, 22, 2, '2025-04-27 20:12:00', N'Playing', '2025-04-27 20:15:59', NULL),
(13, 58, 23, 3, '2025-04-27 20:13:00', N'Queued',  NULL,                  NULL),
(13, 61, 18, 4, '2025-04-27 20:14:00', N'Queued',  NULL,                  NULL),
-- Session 15: Beat Battle Ended (5 items)
(15, 4,  5,  1, '2025-04-20 19:00:00', N'Played',  '2025-04-20 19:01:00', '2025-04-20 19:03:57'),
(15, 5,  6,  2, '2025-04-20 19:02:00', N'Played',  '2025-04-20 19:03:57', '2025-04-20 19:07:02'),
(15, 42, 24, 3, '2025-04-20 19:03:00', N'Played',  '2025-04-20 19:07:02', '2025-04-20 19:11:55'),
(15, 43, 5,  4, '2025-04-20 19:04:00', N'Played',  '2025-04-20 19:11:55', '2025-04-20 19:15:37'),
(15, 74, 6,  5, '2025-04-20 19:05:00', N'Played',  '2025-04-20 19:15:37', '2025-04-20 19:20:30'),
-- Session 16: Tune In Tuesday (4 items)
(16, 7,  9,  1, '2025-04-22 20:00:00', N'Played',  '2025-04-22 20:01:00', '2025-04-22 20:04:36'),
(16, 75, 25, 2, '2025-04-22 20:02:00', N'Played',  '2025-04-22 20:04:36', '2025-04-22 20:08:19'),
(16, 8,  9,  3, '2025-04-22 20:03:00', N'Playing', '2025-04-22 20:08:19', NULL),
(16, 60, 37, 4, '2025-04-22 20:04:00', N'Queued',  NULL,                  NULL),
-- Session 17: Hip-Hop Cypher Ended (4 items)
(17, 26, 10, 1, '2025-04-23 22:00:00', N'Played',  '2025-04-23 22:01:00', '2025-04-23 22:04:18'),
(17, 42, 26, 2, '2025-04-23 22:02:00', N'Played',  '2025-04-23 22:04:18', '2025-04-23 22:09:11'),
(17, 6,  10, 3, '2025-04-23 22:03:00', N'Played',  '2025-04-23 22:09:11', '2025-04-23 22:12:51'),
(17, 74, 38, 4, '2025-04-23 22:04:00', N'Played',  '2025-04-23 22:12:51', '2025-04-23 22:18:04'),
-- Session 18: Indie Night Paused (3 items)
(18, 52, 13, 1, '2025-04-24 22:00:00', N'Played',  '2025-04-24 22:01:00', '2025-04-24 22:04:58'),
(18, 48, 27, 2, '2025-04-24 22:02:00', N'Paused',  '2025-04-24 22:04:58', NULL),
(18, 49, 39, 3, '2025-04-24 22:03:00', N'Queued',  NULL,                  NULL),
-- Session 19: Neon Lights Party (3 items)
(19, 14, 19, 1, '2025-04-26 23:00:00', N'Played',  '2025-04-26 23:01:00', '2025-04-26 23:04:20'),
(19, 68, 28, 2, '2025-04-26 23:02:00', N'Playing', '2025-04-26 23:04:20', NULL),
(19, 16, 19, 3, '2025-04-26 23:03:00', N'Queued',  NULL,                  NULL),
-- Session 20: Jazz and Chill Ended (4 items)
(20, 39, 20, 1, '2025-04-25 18:00:00', N'Played',  '2025-04-25 18:01:00', '2025-04-25 18:04:02'),
(20, 38, 29, 2, '2025-04-25 18:02:00', N'Played',  '2025-04-25 18:04:02', '2025-04-25 18:09:07'),
(20, 59, 20, 3, '2025-04-25 18:03:00', N'Played',  '2025-04-25 18:09:07', '2025-04-25 18:13:28'),
(20, 73, 41, 4, '2025-04-25 18:04:00', N'Played',  '2025-04-25 18:13:28', '2025-04-25 18:17:10'),
-- Session 21: Soul Sunday (3 items)
(21, 67, 21, 1, '2025-04-27 15:00:00', N'Played',  '2025-04-27 15:01:00', '2025-04-27 15:04:32'),
(21, 44, 30, 2, '2025-04-27 15:02:00', N'Playing', '2025-04-27 15:04:32', NULL),
(21, 45, 21, 3, '2025-04-27 15:03:00', N'Queued',  NULL,                  NULL),
-- Session 23: Pop Hits Only Ended (4 items)
(23, 31, 4,  1, '2025-04-19 20:00:00', N'Played',  '2025-04-19 20:01:00', '2025-04-19 20:04:20'),
(23, 33, 31, 2, '2025-04-19 20:02:00', N'Played',  '2025-04-19 20:04:20', '2025-04-19 20:07:18'),
(23, 46, 43, 3, '2025-04-19 20:03:00', N'Played',  '2025-04-19 20:07:18', '2025-04-19 20:10:05'),
(23, 47, 4,  4, '2025-04-19 20:04:00', N'Played',  '2025-04-19 20:10:05', '2025-04-19 20:12:54'),
-- Session 24: Ambient Lounge (3 items)
(24, 58, 24, 1, '2025-04-27 21:00:00', N'Played',  '2025-04-27 21:01:00', '2025-04-27 21:06:37'),
(24, 61, 32, 2, '2025-04-27 21:02:00', N'Playing', '2025-04-27 21:06:37', NULL),
(24, 73, 24, 3, '2025-04-27 21:03:00', N'Queued',  NULL,                  NULL),
-- Session 25: House Heads Only Ended (4 items)
(25, 56, 25, 1, '2025-04-27 00:00:00', N'Played',  '2025-04-27 00:01:00', '2025-04-27 00:06:23'),
(25, 57, 44, 2, '2025-04-27 00:02:00', N'Played',  '2025-04-27 00:06:23', '2025-04-27 00:12:52'),
(25, 64, 25, 3, '2025-04-27 00:03:00', N'Played',  '2025-04-27 00:12:52', '2025-04-27 00:16:31'),
(25, 65, 45, 4, '2025-04-27 00:04:00', N'Played',  '2025-04-27 00:16:31', '2025-04-27 00:19:47'),
-- Session 26: Dubstep Drop Zone (3 items)
(26, 63, 26, 1, '2025-04-27 22:00:00', N'Played',  '2025-04-27 22:01:00', '2025-04-27 22:05:22'),
(26, 55, 33, 2, '2025-04-27 22:02:00', N'Playing', '2025-04-27 22:05:22', NULL),
(26, 54, 26, 3, '2025-04-27 22:03:00', N'Queued',  NULL,                  NULL),
-- Session 27: Techno Thursday Paused (3 items)
(27, 62, 27, 1, '2025-04-24 23:00:00', N'Played',  '2025-04-24 23:01:00', '2025-04-24 23:04:59'),
(27, 63, 34, 2, '2025-04-24 23:02:00', N'Paused',  '2025-04-24 23:04:59', NULL),
(27, 66, 27, 3, '2025-04-24 23:03:00', N'Queued',  NULL,                  NULL),
-- Session 28: Good Vibes Only (3 items)
(28, 46, 24, 1, '2025-04-27 20:00:00', N'Played',  '2025-04-27 20:01:00', '2025-04-27 20:03:47'),
(28, 52, 35, 2, '2025-04-27 20:02:00', N'Playing', '2025-04-27 20:03:47', NULL),
(28, 75, 44, 3, '2025-04-27 20:03:00', N'Queued',  NULL,                  NULL),
-- Session 29: Lo-Fi Study Hall Ended (3 items)
(29, 60, 25, 1, '2025-04-21 10:00:00', N'Played',  '2025-04-21 10:01:00', '2025-04-21 10:06:38'),
(29, 61, 36, 2, '2025-04-21 10:02:00', N'Played',  '2025-04-21 10:06:38', '2025-04-21 10:13:14'),
(29, 58, 25, 3, '2025-04-21 10:03:00', N'Played',  '2025-04-21 10:13:14', '2025-04-21 10:18:57');
GO

<<<<<<< HEAD
-- =============================================
-- VOTES (136 rows)
-- =============================================
INSERT INTO dbo.Votes (QueueItemID, UserID, CreatedAt) VALUES
-- Session 1 votes (items 1-6)
(1,  2,  '2025-04-25 21:01:30'),
(1,  4,  '2025-04-25 21:01:45'),
(1,  9,  '2025-04-25 21:02:00'),
(2,  1,  '2025-04-25 21:05:15'),
(2,  9,  '2025-04-25 21:05:20'),
(2,  14, '2025-04-25 21:05:30'),
(3,  2,  '2025-04-25 21:08:10'),
(3,  4,  '2025-04-25 21:08:20'),
(3,  9,  '2025-04-25 21:08:30'),
(3,  14, '2025-04-25 21:08:40'),
(4,  1,  '2025-04-25 21:09:00'),
(4,  2,  '2025-04-25 21:09:10'),
(4,  9,  '2025-04-25 21:09:20'),
(5,  4,  '2025-04-25 21:10:00'),
(5,  14, '2025-04-25 21:10:10'),
-- Session 2 votes (items 7-11)
(7,  1,  '2025-04-24 20:02:30'),
(7,  5,  '2025-04-24 20:02:45'),
(7,  10, '2025-04-24 20:03:00'),
(8,  2,  '2025-04-24 20:07:30'),
(8,  10, '2025-04-24 20:07:40'),
(9,  1,  '2025-04-24 20:15:20'),
(9,  5,  '2025-04-24 20:15:30'),
(10, 2,  '2025-04-24 20:20:10'),
(10, 10, '2025-04-24 20:20:20'),
-- Session 5 votes (items 18-22)
(18, 3,  '2025-04-25 22:01:30'),
(18, 8,  '2025-04-25 22:01:45'),
(18, 15, '2025-04-25 22:02:00'),
(19, 6,  '2025-04-25 22:04:50'),
(19, 15, '2025-04-25 22:05:00'),
(20, 3,  '2025-04-25 22:08:20'),
(20, 8,  '2025-04-25 22:08:30'),
-- Session 6 votes (items 23-25)
(23, 4,  '2025-04-26 23:01:20'),
(23, 9,  '2025-04-26 23:01:30'),
(24, 7,  '2025-04-26 23:04:20'),
(24, 9,  '2025-04-26 23:04:30'),
-- Session 7 votes (items 26-28)
(26, 2,  '2025-04-22 18:01:30'),
(26, 5,  '2025-04-22 18:01:40'),
(27, 8,  '2025-04-22 18:04:30'),
(27, 5,  '2025-04-22 18:04:40'),
-- Session 9 votes (items 32-35)
(32, 10, '2025-04-25 23:01:20'),
(33, 12, '2025-04-25 23:04:10'),
(33, 10, '2025-04-25 23:04:20'),
(34, 10, '2025-04-25 23:07:50'),
(34, 12, '2025-04-25 23:07:55'),
(35, 12, '2025-04-25 23:08:00'),
-- Session 11 votes (items 36-40)
(36, 17, '2025-04-26 21:01:20'),
(36, 18, '2025-04-26 21:01:30'),
(36, 19, '2025-04-26 21:01:45'),
(37, 16, '2025-04-26 21:04:30'),
(37, 19, '2025-04-26 21:04:40'),
(38, 17, '2025-04-26 21:07:20'),
(38, 18, '2025-04-26 21:07:30'),
(39, 16, '2025-04-26 21:08:00'),
(39, 19, '2025-04-26 21:08:10'),
(39, 33, '2025-04-26 21:08:20'),
-- Session 12 votes (items 41-44)
(41, 20, '2025-04-26 15:01:20'),
(41, 21, '2025-04-26 15:01:30'),
(42, 17, '2025-04-26 15:06:30'),
(42, 20, '2025-04-26 15:06:40'),
(43, 17, '2025-04-26 15:10:10'),
(43, 21, '2025-04-26 15:10:20'),
-- Session 13 votes (items 45-48)
(45, 22, '2025-04-27 20:11:20'),
(45, 23, '2025-04-27 20:11:30'),
(46, 18, '2025-04-27 20:16:00'),
(46, 23, '2025-04-27 20:16:10'),
(47, 22, '2025-04-27 20:17:00'),
(47, 34, '2025-04-27 20:17:10'),
-- Session 15 votes (items 49-53)
(49, 6,  '2025-04-20 19:01:20'),
(49, 24, '2025-04-20 19:01:30'),
(50, 5,  '2025-04-20 19:04:00'),
(50, 36, '2025-04-20 19:04:10'),
(51, 6,  '2025-04-20 19:07:10'),
(51, 24, '2025-04-20 19:07:20'),
(52, 5,  '2025-04-20 19:12:00'),
(53, 5,  '2025-04-20 19:15:40'),
(53, 6,  '2025-04-20 19:15:50'),
-- Session 16 votes (items 54-57)
(54, 25, '2025-04-22 20:01:20'),
(54, 37, '2025-04-22 20:01:30'),
(55, 9,  '2025-04-22 20:04:40'),
(55, 37, '2025-04-22 20:04:50'),
(56, 25, '2025-04-22 20:08:30'),
-- Session 17 votes (items 58-61)
(58, 26, '2025-04-23 22:01:20'),
(58, 38, '2025-04-23 22:01:30'),
(59, 10, '2025-04-23 22:04:30'),
(59, 38, '2025-04-23 22:04:40'),
(60, 26, '2025-04-23 22:09:20'),
(61, 10, '2025-04-23 22:13:00'),
(61, 38, '2025-04-23 22:13:10'),
-- Session 18 votes (items 62-64)
(62, 27, '2025-04-24 22:01:20'),
(62, 39, '2025-04-24 22:01:30'),
(63, 13, '2025-04-24 22:05:00'),
(63, 39, '2025-04-24 22:05:10'),
-- Session 19 votes (items 65-67)
(65, 28, '2025-04-26 23:01:20'),
(65, 40, '2025-04-26 23:01:30'),
(66, 19, '2025-04-26 23:04:30'),
(66, 40, '2025-04-26 23:04:40'),
-- Session 20 votes (items 68-71)
(68, 29, '2025-04-25 18:01:20'),
(68, 41, '2025-04-25 18:01:30'),
(69, 20, '2025-04-25 18:04:10'),
(69, 29, '2025-04-25 18:04:20'),
(70, 20, '2025-04-25 18:09:15'),
(71, 41, '2025-04-25 18:13:30'),
-- Session 21 votes (items 72-74)
(72, 30, '2025-04-27 15:01:20'),
(72, 42, '2025-04-27 15:01:30'),
(73, 21, '2025-04-27 15:04:40'),
(73, 42, '2025-04-27 15:04:50'),
-- Session 23 votes (items 75-78)
(75, 31, '2025-04-19 20:01:20'),
(75, 43, '2025-04-19 20:01:30'),
(76, 4,  '2025-04-19 20:04:30'),
(76, 31, '2025-04-19 20:04:40'),
(77, 43, '2025-04-19 20:07:25'),
(78, 4,  '2025-04-19 20:10:10'),
-- Session 24 votes (items 79-81)
(79, 32, '2025-04-27 21:01:20'),
(79, 24, '2025-04-27 21:01:30'),
(80, 24, '2025-04-27 21:06:45'),
(80, 32, '2025-04-27 21:06:55'),
-- Session 25 votes (items 82-85)
(82, 44, '2025-04-27 00:01:20'),
(82, 45, '2025-04-27 00:01:30'),
(83, 25, '2025-04-27 00:06:30'),
(83, 45, '2025-04-27 00:06:40'),
(84, 44, '2025-04-27 00:13:00'),
-- Session 26 votes (items 86-88)
(86, 33, '2025-04-27 22:01:20'),
(86, 26, '2025-04-27 22:01:30'),
(87, 26, '2025-04-27 22:05:30'),
(87, 33, '2025-04-27 22:05:40'),
-- Session 27 votes (items 89-91)
(89, 34, '2025-04-24 23:01:20'),
(89, 27, '2025-04-24 23:01:30'),
(90, 27, '2025-04-24 23:05:05'),
-- Session 28 votes (items 92-94)
(92, 35, '2025-04-27 20:01:20'),
(92, 44, '2025-04-27 20:01:30'),
(93, 24, '2025-04-27 20:03:55'),
(93, 35, '2025-04-27 20:04:05'),
-- Session 29 votes (items 95-97)
(95, 36, '2025-04-21 10:01:20'),
(95, 25, '2025-04-21 10:01:30'),
(96, 25, '2025-04-21 10:06:45'),
(97, 36, '2025-04-21 10:13:20');
GO
=======
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
(7,  2, '2025-03-14 21:24:45'),
(7,  5, '2025-03-14 21:25:00'),
(8,  1, '2025-03-14 21:27:45'),
(8,  4, '2025-03-14 21:28:00'),
(9,  1, '2025-04-04 20:02:30'),
(9,  3, '2025-04-04 20:02:45'),
(10, 2, '2025-04-04 20:07:45'),
(10, 5, '2025-04-04 20:08:00'),
(10, 6, '2025-04-04 20:08:15'),
(11, 1, '2025-04-04 20:15:30'),
(11, 2, '2025-04-04 20:15:45'),
(12, 1, '2025-04-04 20:20:30'),
(12, 5, '2025-04-04 20:20:45'),
(13, 2, '2025-04-04 20:23:30'),
(13, 6, '2025-04-04 20:23:45'),
(14, 3, '2025-04-04 20:27:30'),
(15, 4, '2025-04-27 15:01:30'),
(15, 6, '2025-04-27 15:01:45'),
(16, 3, '2025-04-27 15:05:00'),
(16, 4, '2025-04-27 15:05:15');
GO
>>>>>>> b90b1e281c9d21ba433142aae86a90661de61fbf
