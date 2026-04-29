import { NextResponse } from 'next/server';
import crypto from 'crypto';
import { getCurrentUser } from '@/lib/auth';

const scopes = [
  'user-read-playback-state',
  'user-modify-playback-state',
  'user-read-currently-playing',
].join(' ');

export async function GET() {
  const user = await getCurrentUser();

  console.log('Spotify redirect URI:', process.env.SPOTIFY_REDIRECT_URI);
  
  if (!user) {
    return NextResponse.redirect(new URL('/login', process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'));
  }

  const state = crypto.randomBytes(16).toString('hex');

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: process.env.SPOTIFY_CLIENT_ID!,
    scope: scopes,
    redirect_uri: process.env.SPOTIFY_REDIRECT_URI!,
    state,
  });

  const response = NextResponse.redirect(
    `https://accounts.spotify.com/authorize?${params.toString()}`
  );

  response.cookies.set('spotify_oauth_state', state, {
    httpOnly: true,
    secure: process.env.NODE_ENV == 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 10,
  });

  return response;
}