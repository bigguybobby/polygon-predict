const features = [
  { icon: "🎯", title: "Create Markets", desc: "Anyone can create a YES/NO prediction market with a custom question and deadline." },
  { icon: "💰", title: "Place Bets", desc: "Bet ETH on YES or NO. Payouts are proportional to your share of the winning pool." },
  { icon: "📈", title: "Live Odds", desc: "Real-time odds update as bets come in. See exactly what the crowd thinks." },
  { icon: "⚖️", title: "Fair Resolution", desc: "Markets resolved by designated oracles. Invalid markets get full refunds." },
  { icon: "🏆", title: "Instant Claims", desc: "Claim winnings immediately after market resolution. No waiting period." },
  { icon: "🔒", title: "2% Protocol Fee", desc: "Low, transparent fee. Most of the pool goes to winners." },
];

export default function Home() {
  return (
    <main className="min-h-screen">
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-indigo-900/30 via-gray-950 to-violet-900/20" />
        <div className="relative mx-auto max-w-5xl px-6 py-24 text-center">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-indigo-500/30 bg-indigo-500/10 px-4 py-1.5 text-sm text-indigo-400">
            🔮 Built for the Polygon Prediction Markets Program
          </div>
          <h1 className="mb-6 text-5xl font-bold leading-tight md:text-6xl">
            <span className="bg-gradient-to-r from-indigo-400 via-violet-300 to-indigo-400 bg-clip-text text-transparent">PredictMarket</span>
          </h1>
          <p className="mx-auto mb-4 max-w-2xl text-lg text-gray-400">
            Create and trade on binary prediction markets. Bet on outcomes, earn from being right.
          </p>
          <div className="flex items-center justify-center gap-4 mt-8">
            <a href="/dashboard" className="rounded-lg bg-indigo-500 px-8 py-3 font-semibold text-white transition hover:bg-indigo-400">Launch App</a>
            <a href="https://github.com/bigguybobby/polygon-predict" target="_blank" rel="noopener noreferrer" className="rounded-lg border border-gray-700 px-8 py-3 font-semibold text-gray-300 transition hover:border-gray-500">GitHub</a>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 py-16">
        <h2 className="mb-12 text-center text-3xl font-bold">How It Works</h2>
        <div className="grid gap-4 text-center md:grid-cols-4">
          {[
            { step: "1", label: "Create", desc: "Post a question", color: "text-indigo-400" },
            { step: "2", label: "Bet", desc: "Choose YES or NO", color: "text-violet-400" },
            { step: "3", label: "Resolve", desc: "Oracle decides", color: "text-purple-400" },
            { step: "4", label: "Claim", desc: "Winners get paid", color: "text-pink-400" },
          ].map((s) => (
            <div key={s.step} className="rounded-lg border border-gray-700 p-6">
              <div className={`mb-1 text-3xl font-bold ${s.color}`}>{s.step}</div>
              <div className="font-semibold">{s.label}</div>
              <div className="text-xs text-gray-500">{s.desc}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 py-16">
        <h2 className="mb-12 text-center text-3xl font-bold">Features</h2>
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div key={f.title} className="rounded-xl border border-gray-800 bg-gray-900/50 p-6 transition hover:border-indigo-500/40">
              <div className="mb-3 text-3xl">{f.icon}</div>
              <h3 className="mb-2 text-lg font-semibold">{f.title}</h3>
              <p className="text-sm text-gray-400">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <footer className="border-t border-gray-800 py-8 text-center text-sm text-gray-500">
        Built by <a href="https://github.com/bigguybobby" className="text-indigo-400 hover:underline" target="_blank" rel="noopener noreferrer">bigguybobby</a> for the Polygon Prediction Markets Program
      </footer>
    </main>
  );
}
