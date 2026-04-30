'use client'
import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';

declare global {
  interface Window {
    Spotify: any;
    onSpotifyWebPlaybackSDKReady: () => void;
  }
}

type Song = {
  id: string;
  spotifyUri: string;
  name: string;
  artist: string;
  album: string;
  duration: string;
  durationSeconds: number;
  imageUrl?: string | null;
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
  VoteCount: number;
  UserHasVoted: number;
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
  const [voting, setVoting] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [showHostModal, setShowHostModal] = useState(true);

  const [spotifyDeviceId, setSpotifyDeviceId] = useState<string | null>(null);
  const [playerReady, setPlayerReady] = useState(false);
  const [playerError, setPlayerError] = useState('');

  async function activateBrowserPlayer() {
    setPlayerError('');
    setError('');

    try {

      const tokenRes = await fetch('/api/spotify/web-playback-token');
      const tokenJson = await tokenRes.json();

      if (!tokenRes.ok || !tokenJson.success) {
        setPlayerError(tokenJson.error || 'Could not get Spotify token.');
        return;
      }

      const accessToken = tokenJson.accessToken;

      if (!window.Spotify) {
        const script = document.createElement('script');
        script.src = 'https://sdk.scdn.co/spotify-player.js';
        script.async = true;
        document.body.appendChild(script);
      }

      window.onSpotifyWebPlaybackSDKReady = () => {
        const player = new window.Spotify.Player({
          name: 'PartyDJ Browser Player',
          getOAuthToken: (cb: (token: string) => void) => {
            cb(accessToken);
          },
          volume: 0.8,
        });

        player.addListener('ready', ({ device_id }: {device_id: string }) => {
          console.log('Spotify browser device ready:', device_id);
          setSpotifyDeviceId(device_id);
          setPlayerReady(true);
        });

        player.connect().then((success: boolean) => {
          if (!success) {
            setPlayerError('Spotify browser player failed to connect.');
          }
        });
      };

      if (window.Spotify) {
        window.onSpotifyWebPlaybackSDKReady();
      }
 
    } catch {
      setPlayerError('Could not activate Spotify browser player.');
    };
  }

  async function playTopSongAutomatically() {
    if (!spotifyDeviceId || !playerReady) {
      return;
    }

    try {
      const res = await fetch(`/api/sessions/${code}/play-test`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ deviceId: spotifyDeviceId }),
      });

      const json = await res.json();

      if (!res.ok || !json.successs) {
        console.error('Auto play failed:', json);
        setError(json.error || 'Auto play failed');
        return;
      }

      console.log('Auto play result:', json);
    } catch (err) {
      console.error('Auto play request failed:', err);
    }
  }

  useEffect(() => {
    if (!playerReady || !spotifyDeviceId) {
      return;
    }

    playTopSongAutomatically();

    const interval = setInterval(playTopSongAutomatically, 5000);
 
    return () => clearInterval(interval);
  }, [playerReady, spotifyDeviceId, code]);

  useEffect(() => {
    const query = search.trim();
    
    if (!query) {
      setResults([]);
      return;
    }
    
    const timeout = setTimeout(async () => {
      try {
        const res = await fetch(`/api/spotify/search?q=${encodeURIComponent(query)}`);
        const json = await res.json();

        if (!res.ok || !json.success) {
          setError(json.error || 'Failed to search Spotify');
          return;
        }

        setResults(json.data);
      } catch {
        setError('Something went wrong while searching Spotify.');
      }
    }, 400);
    return () => clearTimeout(timeout);
  }, [search]);

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

  async function handleGetStarted() {
    setShowHostModal(false);
    await activateBrowserPlayer();
  }

  async function playTestSong() {
    setError('');

    if (!spotifyDeviceId) {
      setError('Activate the Spotify browser player first.');
      return;
    }

    try {
      const res = await fetch(`/api/sessions/${code}/play-test`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ deviceId: spotifyDeviceId }),
      });

      const json = await res.json();

      if (!res.ok || !json.success) {
        setError(json.error || 'Failed to play test song');
        return;
      }

      console.log(json.message);
    } catch {
      setError('Something went wrong testing playback.');
    }
  }


  function handleSearch(e: React.ChangeEvent<HTMLInputElement>) {
    const value = e.target.value;
    setSearch(value);
    setError('');
  }

  async function vote(queueItemID: number) {
    setVoting(queueItemID);
    setError('');

    try {
      const res = await fetch(`/api/sessions/${code}/vote`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ queueItemID }),
      });

      const json = await res.json();

      if (!res.ok) {
        setError(json.error || 'Failed to vote');
      }
    } catch {
      setError('Something went wrong.');
    } finally {
      setVoting(null);
    }
  }

  async function addToQueue(song: Song) {
    setAdding(song.id);
    setError('');

    try {
      const res = await fetch(`/api/sessions/${code}/queue`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ song }),
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

      {showHostModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-6">
          <div className="w-full max-w-md rounded-2xl bg-white p-8 text-black shadow-xl">
            <h2 className="text-2xl font-bold">You're the host!</h2>
            
            <p className="mt-3 text-sm text-gray-600">
              Share this Jam Code with your friends to start the party.
            </p>

            <div className="mt-6 rounded-xl border border-gray-200 bg-gray-50 px-4 py-5 text-center">
              <p className="text-xs font-semibold uppercase tracking-widest text-gray-500">
                Jam Code
              </p>
              <p className="mt-2 text-4xl font-bold tracking-widest">
                {code}
              </p>
            </div>
            <button
              onClick={handleGetStarted}
              className="mt-6 w-full rounded-lg bg-black px-4 py-3 text-sm font-medium text-white transition hover:bg-gray-800"
            >
              Get Started
            </button>
            <p className="mt-3 text-xs text-gray-500">
              This also actives this tab as the Spotify playback device.
            </p>
          </div>
        </div>
      )}
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

      {}
      <div className="flex flex-1 overflow-hidden">

        {}
        <div className="w-56 border-r border-white/10 flex flex-col">
          <p className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-white/40">
            Queue
          </p>
          <div className="flex-1 overflow-y-auto">
            {queue.length === 0 ? (
              <p className="px-4 py-3 text-xs text-white/30">No songs queued yet</p>
            ) : (
              queue.map((song) => (
                <div key={song.QueueItemID} className="flex items-center gap-2 px-4 py-3 border-b border-white/5 hover:bg-white/5">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{song.SongName}</p>
                    <p className="text-xs text-white/50 truncate">{song.ArtistName}</p>
                    <p className="text-xs text-white/30 truncate">by {song.AddedBy}</p>
                  </div>
                  <button
                    onClick={() => vote(song.QueueItemID)}
                    disabled={!!song.UserHasVoted || voting === song.QueueItemID}
                    className="flex flex-col items-center text-xs shrink-0 disabled:opacity-40 disabled:cursor-not-allowed hover:text-green-400 transition"
                  >
                    <span>{voting === song.QueueItemID ? '…' : '▲'}</span>
                    <span>{song.VoteCount}</span>
                  </button>
                </div>
              ))
            )}
          </div>
        </div>

        {}
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

      {}
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
      <button
        onClick = {playTestSong}
        className="mt-3 rounded bg-white text-black px-4 py-2 text-sm font-medium hover:bg-gray-200 transition"
      >
        Play Test Song
      </button>
    </div>
  );
}
