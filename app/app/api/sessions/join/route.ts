import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const sessionCode = body.sessionCode?.trim().toUpperCase();

    if (!sessionCode) {
      return NextResponse.json({ success: false, error: 'Session code is required' }, { status: 400 });
    }

    const pool = await getDbPool();
    const result = await pool
      .request()
      .input('SessionCode', sessionCode)
      .query(`
        SELECT SessionID, SessionCode, SessionName, Status
        FROM Sessions
        WHERE SessionCode = @SessionCode
          AND Status IN ('Pending', 'Active')
      `);

    const session = result.recordset[0];

    if (!session) {
      return NextResponse.json({ success: false, error: 'Invalid or expired session code' }, { status: 404 });
    }

    return NextResponse.json({ success: true, data: session });
  } catch (error: any) {
    console.error('Join session error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
