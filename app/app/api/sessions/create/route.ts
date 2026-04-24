import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const sessionCode = body.sessionCode?.trim().toUpperCase();
    const userID = body.userID;

    if (!sessionCode || sessionCode.length !== 5) {
      return NextResponse.json({ success: false, error: 'A 5-letter session code is required' }, { status: 400 });
    }

    if (!userID) {
      return NextResponse.json({ success: false, error: 'You must be logged in to host a session' }, { status: 401 });
    }

    const pool = await getDbPool();

    const existing = await pool
      .request()
      .input('SessionCode', sessionCode)
      .query(`SELECT 1 FROM Sessions WHERE SessionCode = @SessionCode AND Status IN ('Pending', 'Active')`);

    if (existing.recordset.length > 0) {
      return NextResponse.json({ success: false, error: 'That session code is already in use' }, { status: 409 });
    }

    const result = await pool
      .request()
      .input('SessionCode', sessionCode)
      .input('SessionName', `${sessionCode}'s Jam`)
      .input('CreatedByUserID', userID)
      .query(`
        INSERT INTO Sessions (SessionCode, SessionName, CreatedByUserID, Status)
        VALUES (@SessionCode, @SessionName, @CreatedByUserID, 'Active');

        SELECT SessionID, SessionCode, SessionName, Status
        FROM Sessions
        WHERE SessionID = SCOPE_IDENTITY();
      `);

    return NextResponse.json({ success: true, data: result.recordset[0] }, { status: 201 });
  } catch (error: any) {
    console.error('Create session error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
