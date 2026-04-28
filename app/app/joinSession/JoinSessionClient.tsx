'use client'
import { useState } from 'react';
import { useRouter } from 'next/navigation';

type JoinSessionClientProps = {
  username: string;
};

export default function JoinSessionClient({ username }: JoinSessionClientProps) {
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState<'join' | 'host' | null>(null);

  const router = useRouter();

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setCode(e.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5));
    setError('');
  }

  async function handleJoin() {
    setLoading('join');
    setError('');

    try {
      const res = await fetch('/api/sessions/join', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sessionCode: code }),
      });

      const json = await res.json();

      if (!res.ok) {
        setError(json.error || 'Invalid session code');
        return;
      }

      router.push(`/Jam/${json.data.SessionCode}`);
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(null);
    }
  }

  async function handleHost() {
    setLoading('host');
    setError('');

    try {
      const res = await fetch('/api/sessions/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });

      const json = await res.json();

      if (!res.ok) {
        setError(json.error || 'Could not create session');
        return;
      }

      router.push(`/Jam/${json.data.SessionCode}`);
    } catch {
      setError('Something went wrong. Please try again.');
    } finally {
      setLoading(null);
    }
  }

  const ready = code.length === 5;

  return (
    <main className="min-h-screen bg-gray-100 text-black px-6 py-10">
      <div className="mx-auto grid max-w-6xl grid-cols-1 gap-6 lg:grid-cols-[2fr_1fr]">
        <section className="rounded-2xl bg-white p-10 shadow-md flex flex-col justify-center">
          <h1 className="text-4xl font-bold tracking-tight">
            Hello, {username}
          </h1>

          <p className="mt-2 text-sm text-gray-500">
            Host a new jam or enter a code to join an existing one.
          </p>

          <div className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
  
          {/* Join Card */}
            <div className="border rounded-xl p-6 flex flex-col">
              <h2 className="text-lg font-semibold">Join a Session</h2>

                <label className="block text-sm font-medium mt-4 mb-2">
                  Jam Code
                </label>

                <input
                  className="border rounded px-3 py-2 text-center tracking-widest"
                  value={code}
                  onChange={handleChange}
                  maxLength={5}
                  placeholder="XXXXX"
                  onKeyDown={(e) => e.key === 'Enter' && ready && handleJoin()}
                />

                {error && (
                  <p className="mt-3 text-sm text-red-500">
                {error}
              </p>
            )}

            <button
              onClick={handleJoin}
              disabled={!ready || loading !== null}
              className="mt-6 rounded-lg bg-black text-white py-3 text-sm font-medium hover:bg-gray-800 transition disabled:opacity-40 disabled:cursor-not-allowed"
              >
              {loading === 'join' ? 'Joining...' : 'Join'}
            </button>
          </div>

          {/* Host Card */}
          <div className="border rounded-xl p-6 flex flex-col">
            <h2 className="text-lg font-semibold">Host a Session</h2>

              <p className="text-sm text-gray-500 mt-4">
                Create a new jam session and invite others with your code.
              </p>

              <button
                onClick={handleHost}
                disabled={loading !== null}
                className="mt-auto rounded-lg border border-black text-black py-3 text-sm font-medium hover:bg-gray-100 transition disabled:opacity-40 disabled:cursor-not-allowed"
                >
                {loading === 'host' ? 'Creating...' : 'Host Session'}
              </button>
            </div>

          </div>
        </section>
        <aside className="flex flex-col gap-6">
          <section className="rounded-2xl bg-white p-6 shadow-md min-h-48">
            <h2 className="text-xl font-semibold">Personal Stats</h2>
            <p className="mt-2 text-sm text-gray-500">
              Your stats will appear here.
            </p>
          </section>

          <section className="rounded-2xl bg-white p-6 shadow-md min-h-48">
            <h2 className="text-xl font-semibold">Global Stats</h2>
            <p className="mt-2 text-sm text-gray-500">
              Global stats will appear here.
            </p>
          </section>
        </aside>
      </div>
    </main>
  );
}