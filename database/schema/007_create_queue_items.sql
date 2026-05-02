USE PartyDJ;
GO

IF OBJECT_ID('dbo.QueueItems', 'U') IS NULL
BEGIN
  CREATE TABLE QueueItems (
    QueueItemID BIGINT NOT NULL IDENTITY(1,1)  CONSTRAINT PK_QueueItems PRIMARY KEY,
    SessionID BIGINT NOT NULL CONSTRAINT FK_QueueItems_Sessions_SessionID REFERENCES Sessions(SessionID),
    SongID BIGINT NOT NULL CONSTRAINT FK_QueueItems_Songs_SongID REFERENCES Songs(SongID),
    AddedByUserID BIGINT NOT NULL CONSTRAINT FK_QueueItems_Users_AddedByUserID REFERENCES Users(UserID),
    Position INT NOT NULL,
    QueuedAt DATETIME2(3) NOT NULL CONSTRAINT DF_QueueItems_QueuedAt DEFAULT SYSUTCDATETIME(),
    Status NVARCHAR(32) NOT NULL,
    StartedAt DATETIME2(3) NULL,
    EndedAt DATETIME2(3) NULL,
    CONSTRAINT UQ_QueueItems_SessionID_Position UNIQUE (SessionID, Position),
    CONSTRAINT CK_QueueItems_EndedAfterStarted
        CHECK (EndedAt IS NULL OR StartedAt IS NULL OR EndedAt >= StartedAt)
  );
END;
GO