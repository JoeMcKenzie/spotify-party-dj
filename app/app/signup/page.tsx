'use client'
import { useState } from 'react';

export default function SignUpPage() {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [displayName, setDisplayName] = useState('');
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
          firstName,
          lastName,
          displayName
        })
      });

      const result = await response.json();

      if (!response.ok) {
        setMessage(result.error || 'Failed to create user');
        return;
      }

      setCreatedUser(result.data);
      setMessage('User created successfully');
      setFirstName('');
      setLastName('');
      setDisplayName('');

    } catch (error) {
      setMessage('Something went wrong');
    } finally {
      setLoading(false);
    }
  }
  return (
    <main className="p-8 max-w-xl">
      <h1 className="text-3xl font-bold">Create User</h1>

      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <div>
          <label className="block mb-1 font-medium">First Name</label>
          <input
            className="w-full border rounded px-3 py-2"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
          />
        </div>

        <div>
          <label className="block mb-1 font-medium">Last Name</label>
          <input
            className="w-full border rounded px-3 py-2"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
          />
        </div>

        <div>
          <label className="block mb-1 font-medium">Display Name</label>
          <input
            className="w-full border rounded px-3 py-2"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
          />
        </div>

        <button type="submit" disabled={loading} className="border rounded px-4 py-2">
          {loading ? 'Creating...' : 'Create User'}
        </button>
      </form>
      {message && (
        <p className="mt-4">{message}</p>
      )}
      {createdUser && (
        <div className="mt-6 border rounded p-4">
          <h2 className="font-bold">Created User</h2>
          <p>UserID: {createdUser.UserID}</p>
          <p>FirstName: {createdUser.FirstName}</p>
          <p>LastName: {createdUser.LastName}</p>
          <p>DisplayName: {createdUser.DisplayName}</p>
        </div>
      )}
    </main>
  );
}