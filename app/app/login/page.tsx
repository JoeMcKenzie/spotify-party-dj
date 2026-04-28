'use client'

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [loggedInUser, setLoggedInUser] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setMessage('');
    setLoggedInUser(null);

    try {
      const response = await fetch('/api/users/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          username,
          password,
        })
      });

      const result = await response.json();
      if (!response.ok) {
        setMessage(result.error || 'Failed to log in');
        return;
      }
      
      setLoggedInUser(result.data);
      localStorage.setItem('user', JSON.stringify(result.data));
      setMessage('Logged in successfully');
      setUsername('');
      setPassword('');
      router.push('/joinSession');
    } catch {
      setMessage('Something went wrong');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center bg-gray-100">
      <div className="w-full max-w-md">
        
        {/* Card */}
        <div className="bg-white p-8 rounded-2xl shadow-md">
          <h1 className="text-3xl font-bold text-center">
            Log In
          </h1>
          <p className="mt-2 text-sm text-gray-500 text-center">
            Sign in to your PartyDJ account.
          </p>

          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            <div>
              <label className="block mb-1 font-medium">Username</label>
              <input
                className="w-full border rounded px-3 py-2"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </div>

            <div>
              <label className="block mb-1 font-medium">Password</label>
              <input
                type="password"
                className="w-full border rounded px-3 py-2"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            <button 
              type="submit" 
              disabled={loading} 
              className="w-full bg-black text-white rounded px-4 py-2 hover:bg-gray-800 transition"
            >
              {loading ? 'Logging in...' : 'Log In'}
            </button>
          </form>

          {message && (
            <p className="mt-4 text-center text-sm text-red-500">{message}</p>
          )}
        </div>

        {/* Sign Up Link */}
        <p className="mt-4 text-center text-sm text-gray-600">
          Don't Have An Account?{' '}
          <Link href="/signup" className="text-blue-600 hover:underline">
            Sign Up
          </Link>
        </p>

      </div>
    </main>
  );
}