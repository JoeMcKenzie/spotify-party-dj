import { redirect } from 'next/navigation';
import { getCurrentUser } from '@/lib/auth';
import JoinSessionClient from './JoinSessionClient';

export default async function JoinSessionPage() {
  const user = await getCurrentUser();

  if (!user) {
    redirect('/login');
  }

  return <JoinSessionClient username={user.Username} />;
}
