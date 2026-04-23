'use client'
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function JoinSessionPage() {
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setCode(e.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5));
    setError('');
  }

  async function handleJoin() {
    setLoading(true);
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
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex flex-col items-center justify-center bg-white text-black">
      <p className="mb-3 text-2xl font-bold tracking-widest">Enter Jam Code</p>
      <input
        className="border rounded px-3 py-2 text-center tracking-widest w-30"
        value={code}
        onChange={handleChange}
        maxLength={5}
        placeholder="XXXXX"
        onKeyDown={(e) => e.key === 'Enter' && code.length === 5 && handleJoin()}
      />
      {error && <p className="mt-2 text-sm text-red-500">{error}</p>}
      <button
        onClick={handleJoin}
        disabled={code.length < 5 || loading}
        className="mt-4 rounded-lg bg-black text-white py-3 px-8 text-sm font-medium hover:bg-gray-800 transition disabled:opacity-40 disabled:cursor-not-allowed"
      >
        {loading ? 'Joining...' : 'Join'}
      </button>
    </main>
  );
}
