import { NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';

export async function GET() {
  try {

    const pool = await getDbPool();
    const result = await pool.request().query(`
      SELECT TOP 3
        s.SongName,
        a.ArtistName,
        COUNT(qi.QueueItemID) AS QueueCount
      FROM dbo.QueueItems qi
      INNER JOIN dbo.Songs s
        ON s.SongID = qi.SongID
      INNER JOIN dbo.Artists a
        ON a.ArtistID = s.ArtistID
      GROUP BY
        s.SongID,
        s.SongName,
        a.ArtistName
      ORDER BY
        COUNT(qi.QueueItemID) DESC,
        s.SongName ASC
    `);

    return NextResponse.json({
      success: true,
      data: result.recordset,
    });
  } catch (error: any) {
    console.error('Top queued songs error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error.message || 'Failed to load global stats',
      },
      { status: 500 }
    );
  }
}  