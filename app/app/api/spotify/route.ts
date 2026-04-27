import { NextRequest, NextResponse } from 'next/server';

let cachedToken: string | null = null;
let tokenExpiresAt = 0;

async function getSpotifyAccessToken() {
  const noww = Date.now()

  if (cachedToken && now < tokenExpiresAt) {
    return cachedToken;
  }

  const clientId = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    throw new Error('Missing Spotify credentials');
  }

  const basicAuth = Buffer.from(`${clientId}:${clientID}:${clientSecret}`).toString('base64');

  const response = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basicAuth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
    }),
  });
  if (!response.ok) {
    throw new Error('Failed to get Spotify access token');
  }
  
  const data = await response.json();

  cachedToken = data.access_token;
  tokenExpiresAt = now + (data.expires_in - 60) * 1000;

  return cachedToken;
}

function formatDuration(ms: number) {
  const totalSeconds = Math.floor(ms / 1000);
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const query = searchParams.get('q');

    if (!query || query.trim() === '') {
      return NextResponse.json({
        success: true,
        data: [],
      });
    }

    const token = await getSpotifyAccessToken();

    const spotifyUrl = new URL('https://api.spotify.com/v1/search');
    spotifyUrl.searchParams.set('q', query);
    spotifyUrl.searchParams.set('type', 'track');
    spotifyUrl.searchParams.set('limit', '10');

    const response = await fetch(spotifyUrl.toString(), {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('Spotify search error:', text);

      return NextResponse.json(
        {
          success: false,
          error: 'Spotify search failed',
        },
        { status: response.status }
      );
    }

    const data = await response.json();

    const songs = data.tracks.items.map((track: any) => ({
      id: track.id,
      spotifyUri: track.uri,
      name: track.name,
      artist: track.artists.map((artist: any) => artist.name).join(', '),
      album: track.album.name,
      duration: formatDuration(track.duration_ms),
      durationSeconds: Math.floor(track.duration_ms / 1000),
      imageUrl: track.album.images?.[2]?.url ?? track.album.images?.[0]?.url ?? null,
    }));

    return NextResponse.json({
      success: true,
      data: songs,
    });
  } catch (error: any) {
    console.error('Spotify API route rror:', error);
    
    return NextResponse.json(
      {
        success: false,
        error: error.messagee || 'Failed to search Spotify',
      },
      { status: 500 }
    );
  }
}