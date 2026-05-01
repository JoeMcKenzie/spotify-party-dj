import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function GET(request: NextResponse) {
  try {
    const user = await getCurrentUser();
    
    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
      );
    }

    const sessionCode = request.nextUrl.searchParams.get('sessionCode')?.trim().toUpperCase();

    if (!sessionCode) {
      return NextResponse.json(
        { success: false, error: 'Session code is required.' },
        { status: 400 }
      );
    }

    const pool = await getDbPool();

    const result = await pool
      .request()
      .input('SessionCode', sessionCode)
      .query(`
        SELECT
          COUNT(qi.QueueItemID) AS TotalSongsPlayed,
          ISNULL(SUM(s.DurationSeconds), 0) AS TotalPlaybackDurationSeconds,
          CAST(
            ISNULL(AVG(CAST(s.DurationSeconds AS FLOAT)), 0)
            AS DECIMAL(10, 2)
          ) AS AverageSongLengthSeconds
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Sessions js
          ON js.SessionID = qi.SessionID
        INNER JOIN dbo.Songs s
          ON s.SongID = qi.SongID
        WHERE js.SessionCode = @SessionCode
          AND qi.Status = 'Played'
      `);

    return NextResponse.json({
      success: true,
      data: result.recordset[0],
    });
  } catch (error: any) {
    console.error('Session analysis error:', error);
  
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to load session analysis.'},
      { status: 500 }
    );
  }
}