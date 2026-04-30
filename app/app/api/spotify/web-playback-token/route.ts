import { NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function GET() {
  try {
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
      );
    }

    const pool = await getDbPool();

    const result = await pool
      .request()
      .input('UserID', user.UserID)
      .query(`
        SELECT AccessToken
        FROM dbo.UserSpotifyTokens
        WHERE UserID = @UserID
          AND ExpiresAt > SYSUTCDATETIME()
      `);
    
    const accessToken = result.recordset[0]?.AccessToken;

    if (!accessToken) {
      return NextResponse.json(
        { success: false, error: 'Spotify is not connected or token expired.' },
        { status: 401 }
      );
    }

    return NextResponse.json({
      success: true,
      accessToken,
    });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Could not get Spotify token.' },
      { status: 500 }
    );
  }
}