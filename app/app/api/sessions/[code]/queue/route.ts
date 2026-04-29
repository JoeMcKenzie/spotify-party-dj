import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function GET(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const user = await getCurrentUser();
    const pool = await getDbPool();

    const result = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .input('UserID', user?.UserID ?? null)
      .query(`
        SELECT
          qi.QueueItemID,
          qi.Position,
          qi.Status,
          qi.QueuedAt,
          s.SongName,
          s.DurationSeconds,
          s.AlbumName,
          a.ArtistName,
          u.Username AS AddedBy,
          COUNT(v.VoteID) AS VoteCount,
          MAX(CASE WHEN v.UserID = @UserID THEN 1 ELSE 0 END) AS UserHasVoted
        FROM QueueItems qi
        JOIN Songs s ON s.SongID = qi.SongID
        JOIN Artists a ON a.ArtistID = s.ArtistID
        JOIN Users u ON u.UserID = qi.AddedByUserID
        LEFT JOIN Votes v ON v.QueueItemID = qi.QueueItemID
        WHERE qi.SessionID = (
          SELECT SessionID FROM Sessions WHERE SessionCode = @SessionCode
        )
        GROUP BY
          qi.QueueItemID, qi.Position, qi.Status, qi.QueuedAt,
          s.SongName, s.DurationSeconds, s.AlbumName,
          a.ArtistName, u.Username
        ORDER BY VoteCount DESC, qi.QueuedAt ASC
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
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json({ success: false, error: 'You must be logged in to add songs.' }, { status: 401 });
    }

    const body = await req.json();
    const { song } = body;

    if (!song?.id || !song?.name || !song?.artist) {
      return NextResponse.json({ success: false, error: 'Spotify track ID, song name, and artist are required' }, { status: 400 });
    }

    const durationSeconds = Number(song.durationSeconds) || 1;
    const pool = await getDbPool();

    const sessionResult = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .query(`SELECT SessionID FROM Sessions WHERE SessionCode = @SessionCode AND Status IN ('Pending', 'Active', 'Paused')`);

    const session = sessionResult.recordset[0];

    if (!session) {
      return NextResponse.json({ success: false, error: 'Session not found or has ended' }, { status: 404 });
    }

    await pool
      .request()
      .input('ArtistName', song.artist)
      .query(`
      IF NOT EXISTS (SELECT 1 FROM Artists WHERE ArtistName = @ArtistName)
        INSERT INTO Artists (ArtistName) VALUES (@ArtistName)
      `);

    const artistResult = await pool
      .request()
      .input('ArtistName', song.artist)
      .query(`SELECT ArtistID FROM Artists WHERE ArtistName = @ArtistName`);

    const artistID = artistResult.recordset[0]?.ArtistID;

    if (!artistID) {
      return NextResponse.json(
        { success: false, error: 'Could not create or find artist' },
        { status: 500 }
      );
    }

    await pool.request()
      .input('SpotifyTrackID', song.id)
      .input('SongName', song.name)
      .input('ArtistID', artistID)
      .input('AlbumName', song.album || null)
      .input('DurationSeconds', durationSeconds)
      .query(`
        IF NOT EXISTS (SELECT 1 FROM Songs WHERE SpotifyTrackID = @SpotifyTrackID)
          INSERT INTO Songs (SpotifyTrackID, SongName, ArtistID, AlbumName, DurationSeconds)
          VALUES (@SpotifyTrackID, @SongName, @ArtistID, @AlbumName, @DurationSeconds)
      `);

    const songResult = await pool.request()
      .input('SongName', song.name)
      .input('ArtistID', artistID)
      .query(`SELECT SongID FROM Songs WHERE SongName = @SongName AND ArtistID = @ArtistID`);

    const songID = songResult.recordset[0].SongID;

    if (!songID) {
      return NextResponse.json(
        { success: false, error: 'Could not create or find song' },
        { status: 500 }
      );
    }

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
