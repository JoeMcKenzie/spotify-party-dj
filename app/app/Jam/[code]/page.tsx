'use client'
import { useState, useEffect, useRef } from 'react';
import { useParams } from 'next/navigation';

type Song = {
  id: string;
  name: string;
  artist: string;
  album: string;
  duration: string;
};

type QueuedSong = {
  QueueItemID: number;
  Position: number;
  Status: string;
  SongName: string;
  ArtistName: string;
  AlbumName: string;
  DurationSeconds: number;
  AddedBy: string;
};

function formatDuration(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function JamPage() {
  const { code } = useParams<{ code: string }>();
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<Song[]>([]);
  const [queue, setQueue] = useState<QueuedSong[]>([]);
  const [currentSong, setCurrentSong] = useState<QueuedSong | null>(null);
  const [adding, setAdding] = useState<string | null>(null);
  const [error, setError] = useState('');
  const userRef = useRef<{ UserID: number; Username: string } | null>(null);

  useEffect(() => {
    const stored = localStorage.getItem('user');
    if (stored) userRef.current = JSON.parse(stored);
  }, []);

  // Poll queue every 3 seconds
  useEffect(() => {
    async function fetchQueue() {
      try {
        const res = await fetch(`/api/sessions/${code}/queue`);
        const json = await res.json();
        if (json.success) {
          const active = json.data.filter((q: QueuedSong) => q.Status !== 'Played');
          setCurrentSong(active.find((q: QueuedSong) => q.Status === 'Playing') ?? null);
          setQueue(active.filter((q: QueuedSong) => q.Status !== 'Playing'));
        }
      } catch {}
    }

    fetchQueue();
    const interval = setInterval(fetchQueue, 3000);
    return () => clearInterval(interval);
  }, [code]);

  function handleSearch(e: React.ChangeEvent<HTMLInputElement>) {
    setSearch(e.target.value);
    setError('');
    if (e.target.value.trim()) {
      // Placeholder — replace with Spotify search
      setResults([
        { id: '1', name: 'Example Song', artist: 'Example Artist', album: 'Example Album', duration: '3:45' },
        { id: '2', name: 'Another Track', artist: 'Another Artist', album: 'Another Album', duration: '4:12' },
      ]);
    } else {
      setResults([]);
    }
  }

  async function addToQueue(song: Song) {
    if (!userRef.current) {
      setError('You must be logged in to add songs.');
      return;
    }
    setAdding(song.id);
    setError('');
    try {
      const res = await fetch(`/api/sessions/${code}/queue`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ song, userID: userRef.current.UserID }),
      });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error || 'Failed to add song');
        return;
      }
      setSearch('');
      setResults([]);
    } catch {
      setError('Something went wrong.');
    } finally {
      setAdding(null);
    }
  }

  return (
    <div className="min-h-screen bg-black text-white flex flex-col">

      {/* Top bar */}
      <div className="flex items-center gap-4 px-6 py-4 border-b border-white/10">
        <input
          className="flex-1 bg-transparent border border-white/30 rounded px-4 py-2 text-sm placeholder-white/40 focus:outline-none focus:border-white/60"
          placeholder="Search for songs..."
          value={search}
          onChange={handleSearch}
        />
        <div className="border border-white/30 rounded px-4 py-2 text-sm font-mono tracking-widest whitespace-nowrap">
          {code}
        </div>
      </div>

      {error && <p className="px-6 py-2 text-xs text-red-400">{error}</p>}

      {/* Main content */}
      <div className="flex flex-1 overflow-hidden">

        {/* Left sidebar — queue */}
        <div className="w-56 border-r border-white/10 flex flex-col">
          <p className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-white/40">
            Queue
          </p>
          <div className="flex-1 overflow-y-auto">
            {queue.length === 0 ? (
              <p className="px-4 py-3 text-xs text-white/30">No songs queued yet</p>
            ) : (
              queue.map((song) => (
                <div key={song.QueueItemID} className="px-4 py-3 border-b border-white/5 hover:bg-white/5">
                  <p className="text-sm font-medium truncate">{song.SongName}</p>
                  <p className="text-xs text-white/50 truncate">{song.ArtistName}</p>
                  <p className="text-xs text-white/30 truncate">by {song.AddedBy}</p>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Center — search results */}
        <div className="flex-1 flex flex-col overflow-hidden">
          {results.length > 0 && (
            <div className="border border-white/10 m-6 rounded overflow-hidden">
              {results.map((song) => (
                <div
                  key={song.id}
                  className="flex items-center justify-between px-4 py-3 border-b border-white/5 hover:bg-white/5 cursor-pointer"
                  onClick={() => addToQueue(song)}
                >
                  <div>
                    <p className="text-sm font-medium">{song.name}</p>
                    <p className="text-xs text-white/50">{song.artist} &mdash; {song.album}</p>
                  </div>
                  <span className="text-xs text-white/40">
                    {adding === song.id ? 'Adding...' : song.duration}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Bottom bar — now playing */}
      <div className="border-t border-white/10 px-6 py-4">
        {currentSong ? (
          <div>
            <p className="text-sm font-semibold">{currentSong.SongName}</p>
            <p className="text-xs text-white/50">
              {currentSong.ArtistName} &mdash; {formatDuration(currentSong.DurationSeconds)}
            </p>
          </div>
        ) : (
          <p className="text-xs text-white/30 text-center">No song currently playing</p>
        )}
      </div>
    </div>
  );
}
