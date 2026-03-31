async function getTestMessage() {
  const res = await fetch('http://localhost:3000/api/test', {
    cache: 'no-store',
  });

  if (!res.ok) {
    throw new Error('Failed to fetch test message');
  }

  return res.json();
}

export default async function Home() {
  const result = await getTestMessage();
  const message = result?.data?.[0]?.Message ?? 'No message returned';

  return (
    <main className="p-8">
      <h1 className="text-3xl font-bold">Party DJ</h1>
      <p className="mt-4">Database message:</p>
      <p className="mt-2 rounded border p-4">{message}</p>
    </main>
  );
}
