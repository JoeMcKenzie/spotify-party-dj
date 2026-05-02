USE PartyDJ;
GO

IF OBJECT_ID('dbo.UserSpotifyTokens', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.UserSpotifyTokens (
    UserID INT NOT NULL,
    SpotifyUserID NVARCHAR(255) NULL,
    AccessToken NVARCHAR(MAX) NOT NULL,
    RefreshToken NVARCHAR(MAX) NOT NULL,
    ExpiresAt DATETIME2 NOT NULL,
    CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserSpotifyTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserSpotifyTokens_UpdatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_UserSpotifyTokens PRIMARY KEY (UserID),
    CONSTRAINT FK_UserSpotifyTokens_Users_UserID FOREIGN KEY (UserID)
      REFERENCES dbo.Users(UserID)
  );
END;
GO