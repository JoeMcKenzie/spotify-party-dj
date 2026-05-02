USE PartyDJ;
GO

IF OBJECT_ID('dbo.SessionParticipants', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.SessionParticipants (
    SessionParticipantID INT IDENTITY(1,1) NOT NULL,
    SessionID INT NOT NULL,
    UserID INT NOT NULL,
    Role NVARCHAR(20) NOT NULL CONSTRAINT DF_SessionParticipants_Role DEFAULT 'Guest',
    JoinedAt DATETIME2 NOT NULL CONSTRAINT DF_SessionParticipants_JoinedAt DEFAULT SYSUTCDATETIME(),
    LeftAt DATETIME2 NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_SessionParticipants_IsActive DEFAULT 1,

    CONSTRAINT PK_SessionParticipants PRIMARY KEY (SessionParticipantID),

    CONSTRAINT FK_SessionParticipants_Session
      FOREIGN KEY (SessionID) REFERENCES dbo.Sessions(SessionID),
    
    CONSTRAINT FK_SessionParticipants_User
      FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID),

    CONSTRAINT UQ_SessionParticipants_SessionID_UserID
      UNIQUE (SessionID, UserID),

    CONSTRAINT CK_SessionParticipants_Role
      CHECK (Role IN ('Host', 'Guest', 'Moderator'))
  );
END;
GO