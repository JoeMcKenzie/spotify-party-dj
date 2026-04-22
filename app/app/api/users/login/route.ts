import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
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

    const pool = await getDbPool();
    const result = await pool
      .request()
      .input('Username', username)
      .execute('dbo.GetUserByUsername');

    const user = result.recordset[0];

    if (!user) {
      return NextResponse.json(
        {
          success: false,
          error: 'Invalid username or password',
        },
        { status: 401 }
      );
    }
    const passwordMatches = await bcrypt.compare(password, user.PasswordHash);

    if (!passwordMatches) {
      return NextResponse.json(
        {
          success: false,
          error: 'Invalid username or password',
        },
        { status: 401 }
      );
    }

    return NextResponse.json({
      success: true,
      data: {
        UserID: user.UserID,
        Username: user.Username,
        CreatedAt: user.CreatedAt,
      },
    });
  } catch (error: any) {
    console.error('Login API error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' }, // debugging , if you hit this you probably haven't setup your local db with docker
      { status: 500 }
    );
  }
}