import { NextRequest, NextResponse } from 'next/server';
import { getDbPool } from '@/lib/db';
import { getCurrentUser } from '@/lib/auth';

function generateSessionCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  let code = '';

  for (let i = 0; i < 5; i++) {
    code += letters[Math.floor(Math.random() * letters.length)];
  }

  return code;
}

export async function POST() {
  try {
    const user = await getCurrentUser();

    if (!user) {
      return NextResponse.json({ success: false, error: 'You must be logged in to host a session' }, { status: 401 });
    }

    const pool = await getDbPool();

    let lastError: any = null;

    for (let attempt = 0; attempt < 5; attempt++) {
      const sessionCode = generateSessionCode();

      try {


        const result = await pool
          .request()
          .input('SessionCode', sessionCode)
          .input('SessionName', `${user.Username}'s Jam`)
          .input('CreatedByUserID', user.UserID)
          .execute('dbo.CreateSession');

        return NextResponse.json({ success: true, data: result.recordset[0] }, { status: 201 });
      } catch (error: any) {
        lastError = error;

        if (!error.message?.toLowerCase().includes('already in use')) {
          throw error;
        }
      }
    }

    return NextResponse.json(
      {
        success: false,
        error: lastError?.message || 'Could not generate a unique session code.',
      },
      { status: 500 }
    );
  } catch (error: any) {
    console.error('Create session error:', error);
    return NextResponse.json({ success: false, error: 'Could not create session' }, { status: 500 });
  }
}
