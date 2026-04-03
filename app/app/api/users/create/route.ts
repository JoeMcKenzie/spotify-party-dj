import { NextRequest, NextResponse } from 'next/server'
import { getDbPool } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {   
    const body = await request.json();
    const firstName = body.firstName;
    const lastName = body.lastName;
    const displayName = body.displayName;

    if (!firstName || !lastName || !displayName) {
      return NextResponse.json(
        {
          success: false,
          error: 'firstName, lastName, and displayName are required'
        },
        { status: 400 }
      );
    }
    const pool = await getDbPool();
    const result = await pool
      .request()
      .input('FirstName', firstName)
      .input('LastName', lastName)
      .input('DisplayName', displayName)
      .execute('dbo.CreateUser');

    return NextResponse.json({
      success: true,
      data: result.recordset[0]
    });
  } catch (error: any) {
    console.error('CreateUser API error:', error);

    return NextResponse.json(
      {
        success: false,
        error: error.message || 'Failed to create user'
      },
      { status: 500 }
    );
  }
};  



