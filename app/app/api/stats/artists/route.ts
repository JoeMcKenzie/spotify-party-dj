import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function GET(request: NextRequest) {
  try {
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'You must be logged in.' },
        { status: 401 }
      );
    }

    const startDate = request.nextUrl.searchParams.get('startDate');
    const endDate = request.nextUrl.searchParams.get('endDate');

    const pool = await getDbPool();

    const result = await pool
      .request()
      .input('StartDate', startDate || null)
      .input('EndDate', endDate || null)
      .query(`
        SELECT TOP 10
          a.ArtistName,
          COUNT(qi.QueueItemID) AS SongsQueued,
          SUM(s.DurationSeconds) AS TotalPlayTimeSeconds,
          CAST(AVG(CAST(s.DurationSeconds AS FLOAT)) AS DECIMAL(10, 2)) AS AverageSongDurationSeconds
        FROM dbo.QueueItems qi
        INNER JOIN dbo.Songs s
          ON s.SongID = qi.SongID
        INNER JOIN dbo.Artists a
          ON a.ArtistID = s.ArtistID
        WHERE
          (@StartDate IS NULL OR qi.QueuedAt >= CAST(@StartDate AS DATETIME2))
          AND (
            @EndDate IS NULL
            OR qi.QueuedAt < DATEADD(DAY, 1, CAST(@EndDate AS DATETIME2))
          )
        GROUP BY
          a.ArtistID,
          a.ArtistName
        ORDER BY
          COUNT(qi.QueueItemID) DESC,
          SUM(s.DurationSeconds) DESC,
          a.ArtistName ASC
      `);

    return NextResponse.json({
      success: true,
      data: result.recordset,
    });
  } catch (error: any) {
    console.error('Artist analysis error:', error);

    return NextResponse.json(
      { success: false, error: error.message || 'Failed to load artist analysis.' },
      { status: 500 }
    );
  }
}