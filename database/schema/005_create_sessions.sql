USE PartyDJ;
GO

IF OBJECT_ID('dbo.Sessions', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.Sessions (
    SessionID INT IDENTITY(1,1) NOT NULL,
    SessionCode NVARCHAR(20) NOT NULL,
    SessionName NVARCHAR(100) NOT NULL,
    CreatedByUserID INT NOT NULL,
    HostUserID INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Sessions_CreatedAt DEFAULT SYSUTCDATETIME(),
    StartedAt DATETIME2 NULL,
    EndedAt DATETIME2 NULL,
    Status NVARCHAR(20) NOT NULL CONSTRAINT DF_Sessions_Status DEFAULT 'Active',

    CONSTRAINT PK_Sessions PRIMARY KEY (SessionID),
    CONSTRAINT UQ_Sessions_SessionCode UNIQUE (SessionCode),
    CONSTRAINT FK_Sessions_CreatedByUser
      FOREIGN KEY (CreatedByUserID) REFERENCES dbo.Users(UserID),
  );
END;
GO