import { NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function POST(
  request: Request,
  { params }:  { params: Promise<{ code: string }> }
) {
  try {
    const { code } = await params;
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
      );
    }

    const body = await request.json().catch(() => ({}));
    const deviceId = body.deviceId;

    if (!deviceId) {
      return NextResponse.json(
        { success: false, error: 'Missing Spotify device ID.' },
        { status: 400 }
      );
    }

    const pool = await getDbPool();

    const tokenResult = await pool
      .request()
      .input('UserID', user.UserID)
      .query(`
        SELECT AccessToken
        FROM dbo.UserSpotifyTokens
        WHERE UserID = @UserID
          AND ExpiresAt > SYSUTCDATETIME()
      `);

    const accessToken = tokenResult.recordset[0]?.AccessToken;

    if (!accessToken) {
      return NextResponse.json(
        { success: false, error: 'Spotify is not connected or token expired.' },
        { status: 401 }
      );
    }

    const sessionResult = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .query(`
        SELECT SessionID
        FROM dbo.Sessions
        WHERE SessionCode = @SessionCode
          AND Status IN ('Pending', 'Active', 'Paused')
      `);
      
    const session = sessionResult.recordset[0];

    if (!session) {
      return NextResponse.json(
        { success: false, error: 'Session not found.' },
        { status: 404 }
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
          AND DATEADD(SECOND, s.DurationSeconds, qi.StartedAt) < SYSUTCDATETIME()
      `);

    const currentResult = await pool
      .request()
      .input('SessionID', session.SessionID)
      .query(`
        SELECT TOP 1
          qi.QueueItemID,
          s.SongName,
          a.ArtistName
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Songs s ON s.SongID = qi.SongID
        INNER JOIN dbo.Artists a ON a.ArtistID = s.ArtistID
        WHERE qi.SessionID = @SessionID
          AND qi.Status = 'Playing'
      `);

    const currentSong = currentResult.recordset[0];

    if (currentSong) {
      return NextResponse.json({
        success: true,
        action: 'still_playing',
        data: currentSong,
      });
    }

    const topSongResult = await pool
      .request()
      .input('SessionID', session.SessionID)
      .query(`
        SELECT TOP 1
          qi.QueueItemID,
          qi.SessionID,
          s.SpotifyTrackURI,
          s.SongName,
          a.ArtistName,
          COUNT(v.VoteID) AS VoteCount
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Songs s ON s.SongID = qi.SongID
        INNER JOIN dbo.Artists a ON a.ArtistID = s.ArtistID
        LEFT JOIN dbo.Votes v ON v.QueueItemID = qi.QueueItemID
        WHERE qi.SessionID = @SessionID
          AND qi.Status = 'Queued'
          AND s.SpotifyTrackURI IS NOT NULL
        GROUP BY
          qi.QueueItemID,
          qi.SessionID,
          s.SpotifyTrackURI,
          s.SongName,
          a.ArtistName,
          qi.QueuedAt
        ORDER BY COUNT(v.VoteID) DESC, qi.QueuedAt ASC
      `);

    const topSong = topSongResult.recordset[0];

    if (!topSong) {
      return NextResponse.json({
        success: true,
        action: 'nothing_to_play',
      });
    }

    const spotifyUrl = new URL('https://api.spotify.com/v1/me/player/play');
    spotifyUrl.searchParams.set('device_id', deviceId);

    const spotifyResponse = await fetch(spotifyUrl.toString(), {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        uris: [topSong.SpotifyTrackURI],
      }),
    });
    
    if (!spotifyResponse.ok) {
      const text = await spotifyResponse.text();
      console.error('Spotify play-test error:', text);

      return NextResponse.json(
        {
          success: false,
          error:
            spotifyResponse.status === 404
              ? 'No active Spotify device found. Open Spotify'
              : `Spotify playback failed: ${text}`,
        },
        { status: spotifyResponse.status }
      );
    }

    await pool
      .request()
      .input('SessionID', topSong.SessionID)
      .query(`
        UPDATE dbo.QueueItems
        SET
          Status = 'Played',
          EndedAt = SYSUTCDATETIME()
        WHERE SessionID = @SessionID
          AND Status = 'Playing'
      `);
  
    await pool
      .request()
      .input('QueueItemID', topSong.QueueItemID)
      .query(`
        UPDATE dbo.QueueItems
        SET 
          Status = 'Playing',
          StartedAt = SYSUTCDATETIME(),
          EndedAt = NULL
        WHERE QueueItemID = @QueueItemID
      `);
    
    return NextResponse.json({
      success: true,
      data: {
        QueueItemID: topSong.QueueItemID,
        SongName: topSong.SongName,
        ArtistName: topSong.ArtistName,
      },
    });
  } catch (error: any) {
    console.error('Play test error:', error);
    
    return NextResponse.json(
      { success: false, error: error.message || 'Play test failed.' },
      { status: 500 }
    );
  }
}