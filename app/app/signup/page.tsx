'use client'
import { useState } from 'react';

export default function SignUpPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [createdUser, setCreatedUser] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setMessage('');
    setCreatedUser(null);

    try {
      const response = await fetch('/api/users/create', {
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
        setMessage(result.error || 'Failed to create user');
        return;
      }

      setCreatedUser(result.data);
      setMessage('User created successfully');
      setUsername('');
      setPassword('');

    } catch (error) {
      setMessage('Something went wrong');
    } finally {
      setLoading(false);
    }
  }
  return (
    <main className="p-8 max-w-xl">
      <div className="mx-auto max-w-md">
        <h1 className="text-3xl font-bold">
          Sign Up
        </h1>
        <p className="mt-2 text-sm text-gray-500">
          Create your PartyDJ account.
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
              className="w-full border rounded px-3 py-2"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <button type="submit" disabled={loading} className="border rounded px-4 py-2">
            {loading ? 'Creating...' : 'Sign Up'}
          </button>
        </form>

        {message && (
          <p className="mt-4">{message}</p>
        )}
        {createdUser && (
          <div className="mt-6 border rounded p-4">
            <h2 className="font-bold">Created User</h2>
            <p>UserID: {createdUser.UserID}</p>
            <p>Username: {createdUser.Username}</p>
            <p>Password: {createdUser.Password}</p>
            <p>CreatedAt: {createdUser.CreatedAt}</p>
          </div>
        )}
      </div>
    </main>
  );
}