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
        WITH UserVotesCast AS (
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
        ),
        VotesReceivedBySession AS (
          SELECT 
            qi.SessionID,
            COUNT(v.VoteID) AS VotesReceived
          FROM dbo.QueueItems qi
          LEFT JOIN dbo.Votes v
            ON v.QueueItemID = qi.QueueItemID
          WHERE qi.AddedByUserID = @UserID
          GROUP BY qi.SessionID
        )
        SELECT
          uvc.TotalVotes,
          uvc.AverageSessionVotes,
          ISNULL(MAX(vrbs.VotesReceived), 0) AS MaxVotesReceivedSingleSession
        FROM UserVotesCast uvc
        LEFT JOIN VotesReceivedBySession vrbs
          ON 1 = 1
        GROUP BY
          uvc.TotalVotes,
          uvc.AverageSessionVotes
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
