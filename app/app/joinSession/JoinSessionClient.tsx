'use client'
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

type JoinSessionClientProps = {
  username: string;
};

type TopQueuedSong = {
  SongName: string;
  ArtistName: string;
  QueueCount: number;
};

type PersonalStats = {
  TotalVotes: number;
  AverageSessionVotes: number | null;
};

type ArtistAnalysisRow = {
  ArtistName: string;
  SongQueued: number;
  TotalPlayTimeSeconds: number;
  AverageSongDurationSeconds: number;
};

export default function JoinSessionClient({ username }: JoinSessionClientProps) {
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState<'join' | 'host' | null>(null);
  const [topQueuedSongs, setTopQueuedSongs] = useState<TopQueuedSongs[]>([]);
  const [statsLoading, setStatsLoading] = useState(true);

  const [personalStats, setPersonalStats] = useState<PersonalStats | null>(null);
  const [personalStatsLoading, setPersonalStatsLoading] = useState(true);

  const [artistStartDate, setArtistStartDate] = useState('');
  const [artistEndDate, setArtistEndDate] = useState('');
  const [artistRows, setArtistRows] = useState<ArtistAnalysisRow[]>([]);
  const [artistLoading, setArtistLoading] = useState(false);
  const [artistError, setArtistError] = useState('');

  const router = useRouter();

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    setCode(e.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 5));
    setError('');
  }

  useEffect(() => {
    async function fetchGlobalStats() {
      try {
        const res = await fetch('/api/stats/global/top-queued');
        const json = await res.json();

        if (json.success) {
          setTopQueuedSongs(json.data);
        }
      } catch {
        // keep quiet for now
      } finally {
        setStatsLoading(false);
      }
    }

    fetchGlobalStats();
  }, []);

  useEffect(() => {
    fetchArtistAnalysis();
  }, []);

  useEffect(() => {
    async function fetchPersonalStats() {
      try {
        const res = await fetch('/api/stats/personal');
        const json = await res.json();

        if (json.success) {
          setPersonalStats(json.data);
        }
      } finally {
        setPersonalStatsLoading(false);
      }
    }

    fetchPersonalStats();
  }, []);

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

  function formatSeconds(seconds: number) {
    const total = Math.round(seconds || 0);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;

    if (hours > 0) {
      return `$(hours)h ${minutes}m`;
    }

    return `${minutes}m ${secs}s`;
  }

  async function fetchArtistAnalysis() {
    setArtistLoading(true);
    setArtistError('');

    try {
      const params = new URLSearchParams();

      if (artistStartDate) {
        params.set('startDate', artistStartDate);
      }

      if (artistEndDate) {
        params.set('endDate', artistEndDate);
      }

      const query = params.toString();
      const res = await fetch(`/api/stats/artists${query ? `?${query}` : ''}`);
      const json = await res.json();

      if (!res.ok || !json.success) {
        setArtistError(json.error || 'Failed to load artist analysis.');
        return;
      }

      setArtistRows(json.data);
    } catch {
      setArtistError('Something went wrong loading artist analysis.');
    } finally {
      setArtistLoading(false);
    }
  }

  async function handleHost() {
    setLoading('host');
    setError('');

    window.location.href = '/api/spotify/authorize';
  }

  const ready = code.length === 5;

  return (
    <main className="min-h-screen bg-gray-100 text-black px-6 py-10">
      <div className="mx-auto grid max-w-6xl grid-cols-1 gap-6 lg:grid-cols-[2fr_1fr]">
        <section className="rounded-2xl bg-white p-10 shadow-md flex flex-col justify-center">
          <h1 className="text-4xl font-bold tracking-tight">
            Hello, {username}!
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
              Your voting metrics.
            </p>
            
            {personalStatsLoading ? (
              <p className="mt-2 text-sm text-gray-500">Loading stats...</p>
            ) : (
              <div className="mt-4 grid grid-cols-2 gap-3">
                <div className="rounded-xl border border-gray-100 p-4">
                  <p className="text-xs uppercase tracking-wide text-gray-500">
                    Total Votes
                  </p>
                  <p className="mt-2 text-2xl font-bold">
                    {personalStats?.TotalVotes ?? 0}
                  </p>
                </div>
             
                <div className="rounded-xl border border-gray-100 p-4">
                  <p className="text-xs uppercase tracking wide text-gray-500">
                    Avg / Session
                  </p>
                  <p className="mt-2 text-2xl font-bold">
                    {personalStats?.AverageSessionVotes ?? 0}
                  </p>
                </div>
              </div>
            )}
          </section>

          <section className="rounded-2xl bg-white p-6 shadow-md min-h-48">
            <h2 className="text-xl font-semibold">Global Stats</h2>
            <p className="mt-2 text-sm text-gray-500">
              Top queued songs across all sessions.
            </p>

            <div className="mt-4 space-y-3">
              {statsLoading ? (
                <p className="text-sm text-gray-400">Loading stats..</p>
              ) : topQueuedSongs.length === 0 ? (
                <p className="text-sm text-gray-400">No songs queued yet.</p>
              ) : (
                topQueuedSongs.map((song, index) => (
                  <div
                    key={`${song.SongName}-${song.ArtistName}`}
                    className="flex items-start gap-3 rounded-lg border border-gray-100 p-3"
                  >
                    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-black text-xs font-semibold text-white">
                      {index + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">
                        {song.SongName}
                      </p>
                      <p className="truncate text-sm text-gray-500">
                        {song.ArtistName}
                      </p>
                    </div>

                    <p className="text-xs font-medium text-gray-500">
                      {song.QueueCount}x
                    </p>
                  </div>
                ))
              )}
            </div>        
          </section>
        </aside>
      </div>

      <section className="mx-auto mt-6 max-w-6xl rounded-2xl bg-white p-6 shadow-md">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <h2 className="text-xl font-semibold">Artist Analysis</h2>
            <p className="mt-2 text-sm text-gray-500">
              Top artist by queue activity across the selected date range.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <div>
              <label className="block text-xs font-medium text-gray-500">
                Start Date
              </label>
              <input
                type="date"
                value={artistStartDate}
                onChange={(e) => setArtistStartDate(e.target.value)}
                className="mt-1 rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-500">
                End Date
              </label>
              <input
                type="date"
                value={artistEndDate}
                onChange={(e) => setArtistEndDate(e.target.value)}
                className="mt-1 rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>

            <button
              onClick={fetchArtistAnalysis}
              disabled={artistLoading}
              className="rounded-lg bg-black px-4 py-2 text-sm font-medium text-white hover:bg-gray-800 disabled:opacity-50"
            >
              {artistLoading ? 'Loading...' : 'Apply'}
            </button>
          </div>
        </div>
        
        {artistError && (
          <p className="mt-4 text-sm text-red-500">{artistError}</p>
        )}

        <div className="mt-6 overflow-x-auto">
          {artistLoading ? (
            <p className="text-sm text-gray-500">Loading artist analysis...</p>
          ) : artistRows.length === 0 ? (
            <p className="text-sm text-gray-500">
              Not artist activity found for this date range.
            </p>
          ) : (
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b text-xs uppercase tracking-wide text-gray-500">
                  <th className="py-3 pr-4">Rank</th>
                  <th className="py-3 pr-4">Artist</th>
                  <th className="py-3 pr-4">Songs Queued</th>
                  <th className="py-3 pr-4">Total Play Time</th>
                  <th className="py-3 pr-4">Avg Duration</th>
                </tr>
              </thead>

              <tbody>
                {artistRows.map((row, index) => (
                  <tr
                    key={row.ArtistName}
                    className="border-b border-graay-100 last:border-0"
                  >
                    <td className="py-3 pr-4 font-medium">
                      #{index + 1}
                    </td>
                    <td className="py-3 pr-4 font-medium">
                      {row.ArtistName}
                    </td>
                    <td className="py-3 pr-4 font-medium">
                      {row.SongsQueued}
                    </td>
                    <td className="py-3 pr-4 font-medium">
                      {formatSeconds(row.TotalPlayTimeSeconds)}
                    </td>
                    <td className="py-3 pr-4 font-medium">
                      {formatSeconds(row.AverageSongDurationSeconds)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      <section className="mx-auto mt-6 max-w-6xl rounded-2xl bg-white p-6 shadow-md">
        <h2 className="text-xl font-semibold">Song Analysis</h2>
        <p className="mt-2 text-sm text-gray-500">
          Song insights will appear here.
        </p>
      </section>

      <section className="mx-auto mt-6 max-w-6xl rounded-2xl bg-white p-6 shadow-md">
        <h2 className="text-xl font-semibold">Session Analysis</h2>
        <p className="mt-2 text-sm text-gray-500">
          Session insights will appear here.
        </p>
      </section>
    </main>
  );
}