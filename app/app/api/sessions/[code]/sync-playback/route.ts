import { NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

async function getSpotifyAccessToken(pool: any, userID: number) {
  const result = await pool
    .request()
    .input('UserID', userID)
    .query(`
      SELECT AccessToken
      FROM dbo.UserSpotifyTokens
      WHERE UserID = @UserID
        AND ExpiresAt > SYSUTCDATETIME()
    `);

  return result.recordset[0]?.AccessToken ?? null;
}

export async function POST(request: Request, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
      );
    }

    const pool = await getDbPool();

    const hostResult = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .input('UserID', user.UserID)
      .query(`
        SELECT s.SessionID
        FROM dbo.Sessions s
        INNER JOIN dbo.SessionParticipants sp
          ON sp.SessionID = s.SessionID
        WHERE s.SessionCode = @SessionCode
          AND sp.UserID = @UserID
          AND sp.Role = 'Host'
          AND s.Status IN ('Active', 'Paused', 'Pending')
      `);

    const session = hostResult.recordset[0];

    if (!session) {
      return NextResponse.json(
        { success: false, error: 'Only the host can control playback.' },
        { status: 403 }
      );
    }

    const token = await getSpotifyAccessToken(pool, user.UserID);

    if (!token) {
      return NextResponse.json (
        { success: false, error: 'Spotify token missing or expired.' },
        { status: 401 }
      );
    }

    await pool
      .request()
      .input('SessionID', session.SessionID)
      .query(`
        UPDATE qi
        SET
          qi.Status = 'Played',
          qi.EndedAt = SYSUTCDATETIME()
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Songs s
          ON s.SongID = qi.SongID
        WHERE qi.SessionID = @SessionID
          AND qi.Status = 'Playing'
          AND qi.StartedAt IS NOT NULL
          AND DATEADD(SECOND, s.DurationSeconds, qi.StartedAt) <= SYSUTCDATETIME()
      `);

    const nextResult = await pool
      .request()
      .input('SessionID', session.SessionID)
      .query(`
        SELECT TOP 1
          qi.QueueItemID,
          s.SpotifyTrackURI,
          s.SongName,
          a.ArtistName,
          COUNT(v.VoteID) AS VoteCount
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Songs s
          ON s.SongID = qi.SongID
        INNER JOIN dbo.Artists a
          ON a.ArtistID = s.ArtistID
        LEFT JOIN dbo.Votes v
          ON v.QueueItemID = qi.QueueItemID
        WHERE qi.SessionID = @SessionID
          AND qi.Status = 'Queued'
          AND s.SpotifyTrackURI IS NOT NULL
        GROUP BY
          qi.QueueItemID,
          s.SpotifyTrackURI,
          s.SongName,
          a.ArtistName,
          qi.QueuedAt
        ORDER BY COUNT(v.VoteID) DESC, qi.QueuedAt ASC
      `);

    const nextSong = nextResult.recordset[0];

    await pool
      .request()
      .input('QueueItemID', nextSong.QueueItemID)
      .query(`
        UPDATE dbo.QueueItems
        SET
          Status = 'Playing'
          StartedAt = SYSUTCDATETIME(),
          EndedAt = NULL
        WHERE QueueItemID = @QueueItemID
      `);
    
    const spotifyResponse = await fetch('https://api.spotify.com/v1/me/player/play', {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        uris: [nextSong.SpotifyTrackURI],
      }),
    });

    return NextResponse.json({
      success: true,
      action: 'started_next_song',
      data: {
        QueueItemID: nextSong.QueueItemID,
        SongName: nextSong.SongName,
        ArtistName: nextSong.ArtistName,
      },
    });
  } catch (error: any) {
    console.error('Sync playback error:', error);
     
    return NextResponse.json(
      { success: false, error: error.message || 'Could not sync playback.' },
      { status: 500 }
    );
  }
}


















