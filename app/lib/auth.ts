import crypto from 'crypto';
import { cookies } from 'next/headers';
import { getDbPool } from '@/lib/db';

export const SESSION_COOKIE_NAME = 'party_dj_session';

export function createSessionToken() {
  return crypto.randomBytes(32).toString('hex');
}

export function hashSessionToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export async function getCurrentUser() {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  if (!token) {
    return null;
  }

  const tokenHash = hashSessionToken(token);

  const pool = await getDbPool();

  const result = await pool
    .request()
    .input('SessionTokenHash', tokenHash)
    .execute('dbo.GetUserBySessionTokenHash');

  return result.recordset[0] ?? null;
}