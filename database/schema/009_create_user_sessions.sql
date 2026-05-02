USE PartyDJ;
GO

IF OBJECT_ID('dbo.UserSessions', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.UserSessions (
    UserSessionID BIGINT IDENTITY(1,1) NOT NULL,
    UserID INT NOT NULL,
    SessionTokenHassh NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserSessions_CreatedAt DEFAULT SYSUTCDATETIME(),
    ExpiresAt DATETIME2 NOT NULL,
    RevokedAt DATETIME2 NULL,
    
    CONSTRAINT PK_UserSessions PRIMARY KEY (UserSessionID),
    CONSTRAINT FK_UserSessions_Users_UserID FOREIGN KEY (UserID)
      REFERENCES dbo.Users(UserID),
    CONSTRAINT UQ_UserSessions_SessionTokenHash UNIQUE (SessionTokenHash)
  );
END;
GO