import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';

export async function POST(req: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  try {
    const { code } = await params;
    const body = await req.json();
    const { queueItemID, userID } = body;

    if (!queueItemID || !userID) {
      return NextResponse.json({ success: false, error: 'queueItemID and userID are required' }, { status: 400 });
    }

    const pool = await getDbPool();

    const itemCheck = await pool.request()
      .input('QueueItemID', queueItemID)
      .input('SessionCode', code.toUpperCase())
      .query(`
        SELECT 1 FROM QueueItems qi
        JOIN Sessions s ON s.SessionID = qi.SessionID
        WHERE qi.QueueItemID = @QueueItemID AND s.SessionCode = @SessionCode
      `);

    if (itemCheck.recordset.length === 0) {
      return NextResponse.json({ success: false, error: 'Queue item not found' }, { status: 404 });
    }

    await pool.request()
      .input('QueueItemID', queueItemID)
      .input('UserID', userID)
      .query(`
        INSERT INTO Votes (QueueItemID, UserID, VoteType, VoteValue)
        VALUES (@QueueItemID, @UserID, 'up', 1)
      `);

    return NextResponse.json({ success: true });
  } catch (error: any) {
    if (error?.number === 2627 || error?.message?.includes('UQ_Votes')) {
      return NextResponse.json({ success: false, error: 'You have already voted for this song' }, { status: 409 });
    }
    console.error('Vote error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
