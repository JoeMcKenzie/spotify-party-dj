'use client'
import { useState } from 'react';

export default function JoinSessionPage() {
  const [code, setCode] = useState('');

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setCode(e.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5));
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
      />
      <button disabled={code.length < 5} className="mt-4 rounded-lg bg-black text-white py-3 px-8 text-sm font-medium hover:bg-gray-800 transition disabled:opacity-40 disabled:cursor-not-allowed">
        Join
      </button>
    </main>
  );
}
