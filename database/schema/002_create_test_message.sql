USE PartyDJ;
GO

IF OBJECT_ID('dbo.TestMessage', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TestMessage (
        Id INT PRIMARY KEY,
        Message NVARCHAR(100) NOT NULL
    );
END;
GO