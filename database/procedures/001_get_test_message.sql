USE PartyDJ;
GO

CREATE OR ALTER PROCEDURE dbo.GetTestMessage
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Message
    FROM dbo.TestMessage
    WHERE Id = 1;
END;
GO