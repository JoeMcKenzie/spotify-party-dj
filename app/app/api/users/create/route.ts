import { NextRequest, NextResponse } from 'next/server'
import { getDbPool } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {   
    const body = await request.json();

    const username = body.username?.trim();
    const password = body.password;

    if (!username || !password) {
      return NextResponse.json(
        {
          success: false,
          error: 'username and password are required'
        },
        { status: 400 }
      );
    }

    if (password.length < 8) {
      return NextResponse.json(
        {
          success: false,
          error: 'password must be at least 8 characters long'
        },
        { status: 400 }
      );
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const pool = await getDbPool();
    const result = await pool
      .request()
      .input('Username', username)
      .input('PasswordHash', passwordHash)
      .execute('dbo.CreateUser');

    return NextResponse.json(
      {
        success: true,
        data: result.recordset[0]
      },
      { status: 201 }
    );
  } catch (error: any) {
    console.error('CreateUser API error:', error);
   
    const message = error?.message || 'Failed to create user';

    if (message.toLowerCase().includes('already taken')) {
      return NextResponse.json(
        {
          success: false;
          error: 'That username is already taken'
        },
        { status: 409 }
      );
    }

    return NextResponse.json(
      {
        success: false,
        error: error.message
      },
      { status: 500 }
    );
  }
};


