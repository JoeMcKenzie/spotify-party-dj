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
        SELECT
          COUNT(v.VoteID) AS TotalVotes,
          CAST(
            COUNT(v.VoteID) * 1.0 /
            NULLIF(COUNT(DISTINCT qi.SessionID), 0)
            AS DECIMAL(10,2)
          ) AS AverageSessionVotes
        FROM dbo.Votes v
        INNER JOIN dbo.QueueItems qi
          ON qi.QueueItemID = v.QueueItemID
        WHERE v.UserID = @UserID
      `);

    return NextResponse.json({
      success: true,
      data: result.recordset[0],
    });
  } catch (error: any) {
    console.error('Personal stats error:', error);

    return NextResponse.json(
      { success: false, error: error.message || 'Failed to load personal stats' },
      { status: 500 }
    );
  }
}
