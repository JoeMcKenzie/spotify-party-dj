import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';

export async function GET(_req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const pool = await getDbPool();

    const result = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .query(`
        SELECT
          qi.QueueItemID,
          qi.Position,
          qi.Status,
          s.SongName,
          s.DurationSeconds,
          s.AlbumName,
          a.ArtistName,
          u.Username AS AddedBy
        FROM QueueItems qi
        JOIN Songs s ON s.SongID = qi.SongID
        JOIN Artists a ON a.ArtistID = s.ArtistID
        JOIN Users u ON u.UserID = qi.AddedByUserID
        WHERE qi.SessionID = (
          SELECT SessionID FROM Sessions WHERE SessionCode = @SessionCode
        )
        ORDER BY qi.Position ASC
      `);

    return NextResponse.json({ success: true, data: result.recordset });
  } catch (error: any) {
    console.error('GET queue error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const body = await req.json();
    const { song, userID } = body;

    if (!song?.name || !song?.artist) {
      return NextResponse.json({ success: false, error: 'Song name and artist are required' }, { status: 400 });
    }
    if (!userID) {
      return NextResponse.json({ success: false, error: 'You must be logged in to add songs' }, { status: 401 });
    }

    const durationSeconds = song.duration
      ? song.duration.split(':').reduce((acc: number, val: string, i: number, arr: string[]) =>
          i === arr.length - 1 ? acc + parseInt(val) : acc + parseInt(val) * 60, 0)
      : 0;

    const pool = await getDbPool();

    const sessionResult = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .query(`SELECT SessionID FROM Sessions WHERE SessionCode = @SessionCode AND Status IN ('Pending', 'Active')`);

    const session = sessionResult.recordset[0];
    if (!session) {
      return NextResponse.json({ success: false, error: 'Session not found or has ended' }, { status: 404 });
    }

    // Upsert artist
    await pool.request().input('ArtistName', song.artist).query(`
      IF NOT EXISTS (SELECT 1 FROM Artists WHERE ArtistName = @ArtistName)
        INSERT INTO Artists (ArtistName) VALUES (@ArtistName)
    `);
    const artistResult = await pool
      .request()
      .input('ArtistName', song.artist)
      .query(`SELECT ArtistID FROM Artists WHERE ArtistName = @ArtistName`);
    const artistID = artistResult.recordset[0].ArtistID;

    // Upsert song
    await pool.request()
      .input('SongName', song.name)
      .input('ArtistID', artistID)
      .input('AlbumName', song.album || null)
      .input('DurationSeconds', durationSeconds || 1)
      .query(`
        IF NOT EXISTS (SELECT 1 FROM Songs WHERE SongName = @SongName AND ArtistID = @ArtistID)
          INSERT INTO Songs (SongName, ArtistID, AlbumName, DurationSeconds)
          VALUES (@SongName, @ArtistID, @AlbumName, @DurationSeconds)
      `);
    const songResult = await pool.request()
      .input('SongName', song.name)
      .input('ArtistID', artistID)
      .query(`SELECT SongID FROM Songs WHERE SongName = @SongName AND ArtistID = @ArtistID`);
    const songID = songResult.recordset[0].SongID;

    // Get next position
    const posResult = await pool.request()
      .input('SessionID', session.SessionID)
      .query(`SELECT ISNULL(MAX(Position), 0) + 1 AS NextPos FROM QueueItems WHERE SessionID = @SessionID`);
    const nextPos = posResult.recordset[0].NextPos;

    await pool.request()
      .input('SessionID', session.SessionID)
      .input('SongID', songID)
      .input('UserID', userID)
      .input('Position', nextPos)
      .query(`
        INSERT INTO QueueItems (SessionID, SongID, AddedByUserID, Position, Status)
        VALUES (@SessionID, @SongID, @UserID, @Position, 'Queued')
      `);

    return NextResponse.json({ success: true }, { status: 201 });
  } catch (error: any) {
    console.error('POST queue error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
