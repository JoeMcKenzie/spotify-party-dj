export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-white">
      <div className="w-full max-w-sm px-6">
        <h1 className="text-2xl font-semibold mb-6">Login to your account</h1>
        
        <form className="flex flex-col gap-4">
          <input
            type="email"
            placeholder="Email"
            className="border rounded-lg px-3 py-2 text-sm"
          />
          
          <button className="bg-black text-white py-2 rounded-lg text-sm">
            Login
          </button>
        </form>
      </div>
    </main>
  );
}