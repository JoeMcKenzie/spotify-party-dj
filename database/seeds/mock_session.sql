USE PartyDJ;
GO

IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'mockhost')
BEGIN
  INSERT INTO Users (Username, PasswordHash)
  VALUES ('mockhost', 'not-a-real-hash');
END;

DECLARE @HostID BIGINT = (SELECT UserID FROM Users WHERE Username = 'mockhost');

DELETE FROM Sessions WHERE SessionCode = 'TESTX';

INSERT INTO Sessions (SessionCode, SessionName, CreatedByUserID, Status)
VALUES ('TESTX', 'Mock Jam Session', @HostID, 'Active');

SELECT SessionID, SessionCode, SessionName, Status
FROM Sessions
WHERE SessionCode = 'TESTX';
GO
