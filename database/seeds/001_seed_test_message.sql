USE PartyDJ;
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TestMessage
    WHERE Id = 1
)
BEGIN
    INSERT INTO dbo.TestMessage (Id, Message)
    VALUES (1, 'Hello from SQL Server');
END;
GO