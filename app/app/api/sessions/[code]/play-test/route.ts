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
    const body = await request.json().catch(() => ({}));
    const deviceId = body.deviceId;

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
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

    const topSongResult = await pool
      .request()
      .input('SessionCode', code.toUpperCase())
      .query(`
        SELECT TOP 1
          qi.QueueItemID,
          qi.SessionID,
          s.SpotifyTrackURI,
          s.SongName,
          a.ArtistName,
          COUNT(v.VoteID) AS VoteCount
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Sessions js
          ON js.SessionID = qi.SessionID
        INNER JOIN dbo.Songs s
          ON s.SongID = qi.SongID
        INNER JOIN dbo.Artists a
          ON a.ArtistID = s.ArtistID
        LEFT JOIN dbo.Votes v
          ON v.QueueItemID = qi.QueueItemID
        WHERE js.SessionCode = @SessionCode
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
      return NextResponse.json(
        { success: false, error: 'No queued songs with a Spotify URI to play.' },
        { status: 404 }
      );
    }

    const spotifyUrl = new URL('https://api.spotify.com/v1/me/player/play');

    if (deviceId) {
      spotifyUrl.searchParams.set('device_id', deviceId);
    }

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