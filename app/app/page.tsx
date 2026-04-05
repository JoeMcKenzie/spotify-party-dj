import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-white text-black">
      <div className="w-full max-w-sm px-6">
      
        <div className="mb-10 text-center">
          <h1 className="text-3xl font-semibold tracking-tight">
            CrowdDJ
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            Let the crowd control the music
          </p>
        </div>

        <div className="flex flex-col gap-4">
          <Link href="/login">
            <button className="w-full rounded-lg bg-black text-white py-3 text-sm font medium hover:bg-gray-800 transition">
              Log In
            </button>
          </Link>

          <Link href="/signup">
            <button className="w-full rounded-lg border border-gray-300 py-3 text-sm font-medium hover:bg-gray-50 transition">
              Sign Up
            </button>
          </Link>
        </div>

      </div>
    </main>
  );
}
