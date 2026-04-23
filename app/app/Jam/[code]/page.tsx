'use client'
import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';

type Song = {
  id: string;
  name: string;
  artist: string;
  album: string;
  duration: string;
};

type QueuedSong = Song & { position: number; addedBy: string };

export default function JamPage() {
  const { code } = useParams<{ code: string }>();
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<Song[]>([]);
  const [queue, setQueue] = useState<QueuedSong[]>([]);
  const [currentSong, setCurrentSong] = useState<Song | null>(null);

  // Placeholder: replace with real Spotify search
  function handleSearch(e: React.ChangeEvent<HTMLInputElement>) {
    setSearch(e.target.value);
    if (e.target.value.trim()) {
      setResults([
        { id: '1', name: 'Example Song', artist: 'Example Artist', album: 'Example Album', duration: '3:45' }, // these are examples use spotify api to pop results later
        { id: '2', name: 'Another Track', artist: 'Another Artist', album: 'Another Album', duration: '4:12' }, // TPD spotify api stuff
      ]);
    } else {
      setResults([]);
    }
  }

  function addToQueue(song: Song) {
    setQueue((prev) => [
      ...prev,
      { ...song, position: prev.length + 1, addedBy: 'You' },
    ]);
    setSearch('');
    setResults([]);
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
                <div key={song.id} className="px-4 py-3 border-b border-white/5 hover:bg-white/5">
                  <p className="text-sm font-medium truncate">{song.name}</p>
                  <p className="text-xs text-white/50 truncate">{song.artist}</p>
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
                  <span className="text-xs text-white/40">{song.duration}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Bottom bar — now playing */}
      <div className="border-t border-white/10 px-6 py-4">
        {currentSong ? (
          <div className="flex items-center gap-4">
            <div>
              <p className="text-sm font-semibold">{currentSong.name}</p>
              <p className="text-xs text-white/50">{currentSong.artist} &mdash; {currentSong.duration}</p>
            </div>
          </div>
        ) : (
          <p className="text-xs text-white/30 text-center">No song currently playing</p>
        )}
      </div>
    </div>
  );
}
