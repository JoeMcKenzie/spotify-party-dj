import { NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ code: string }> }
) {
  const { code } = await params;
  const user = await getCurrentUser();
  
  if (!user) {
    return NextResponse.json(
      { success: false, error: 'Not logged in' },
      { status: 401 }
    );
  }

  const pool = await getDbPool();

  const result = await pool
    .request()
    .input('SessionCode', code.toUpperCase())
    .input('UserID', user.UserID)
    .query(`
      SELECT sp.Role
      FROM dbo.SessionParticipants sp
      INNER JOIN dbo.Sessions s
        ON s.SessionID = sp.SessionID
      WHERE s.SessionCode = @SessionCode
        AND sp.UserID = @UserID
        AND sp.LeftAt IS NULL
    `);

  return NextResponse.json({
    success: true,
    data: result.recordset[0] ?? null,
  });
}