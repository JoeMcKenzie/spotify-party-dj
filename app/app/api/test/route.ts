import { NextResponse } from 'next/server';
import sql from 'mssql';
import { getDbPool } from '@/lib/db';

export async function GET() {
  try {
    const pool = await getDbPool();

    const result = await pool.request().execute('dbo.GetTestMessage');

    return NextResponse.json({
      success: true,
      data: result.recordset,
    });
  } catch (error) {
    console.error('Database error:', error);

    return NextResponse.json(
      {
        success: false,
        error: 'Failed to fetch data from SQL Server',
      },
      { status: 500 }
    );
  }
};
