"use client";

import { useState } from "react";
import { ConnectKitButton } from "connectkit";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther, formatEther } from "viem";
import { PREDICT_ADDRESS, PREDICT_ABI } from "@/config/contract";

const OUTCOME_LABELS = ["Unresolved", "Yes", "No", "Invalid"];
const OUTCOME_COLORS = ["text-gray-400", "text-green-400", "text-red-400", "text-yellow-400"];

type Tab = "markets" | "create" | "bet" | "portfolio";

function OddsBar({ yesBps }: { yesBps: number }) {
  const yPct = yesBps / 100;
  const nPct = 100 - yPct;
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-green-400">YES {yPct.toFixed(1)}%</span>
        <span className="text-red-400">NO {nPct.toFixed(1)}%</span>
      </div>
      <div className="flex h-3 rounded-full overflow-hidden">
        <div className="bg-green-500 transition-all" style={{ width: `${yPct}%` }} />
        <div className="bg-red-500 transition-all" style={{ width: `${nPct}%` }} />
      </div>
    </div>
  );
}

function CreateMarket() {
  const [question, setQuestion] = useState("");
  const [hours, setHours] = useState("24");
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const create = () => {
    const deadline = BigInt(Math.floor(Date.now() / 1000) + Number(hours) * 3600);
    writeContract({
      address: PREDICT_ADDRESS,
      abi: PREDICT_ABI,
      functionName: "createMarket",
      args: [question, deadline, "0x0000000000000000000000000000000000000000"],
    });
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Create Market</h2>
      <input value={question} onChange={(e) => setQuestion(e.target.value)} placeholder="Will ETH hit $10,000 by March 2026?" className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-3 text-white focus:border-indigo-500 focus:outline-none" />
      <div>
        <label className="block text-sm text-gray-400 mb-1">Deadline (hours from now)</label>
        <input type="number" value={hours} onChange={(e) => setHours(e.target.value)} className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-3 text-white focus:border-indigo-500 focus:outline-none" />
      </div>
      <button onClick={create} disabled={isPending || confirming || !question} className="rounded-lg bg-indigo-500 px-6 py-3 font-semibold text-white transition hover:bg-indigo-400 disabled:opacity-50">
        {isPending ? "Confirm..." : confirming ? "Creating..." : "Create Market"}
      </button>
      {isSuccess && <div className="rounded-lg border border-green-500/30 bg-green-500/10 p-4 text-green-400">✅ Market created! TX: <code className="text-xs">{hash}</code></div>}
    </div>
  );
}

function BetOnMarket() {
  const [marketId, setMarketId] = useState("");
  const [amount, setAmount] = useState("0.01");
  const [side, setSide] = useState<"yes" | "no">("yes");
  const id = BigInt(marketId || "0");

  const { data: meta } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getMarketMeta", args: [id],
    query: { enabled: marketId !== "" },
  });
  const { data: pools } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getMarketPools", args: [id],
    query: { enabled: marketId !== "" },
  });
  const { data: odds } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getOdds", args: [id],
    query: { enabled: marketId !== "" && !!pools },
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const bet = () => {
    writeContract({
      address: PREDICT_ADDRESS,
      abi: PREDICT_ABI,
      functionName: "placeBet",
      args: [id, side === "yes"],
      value: parseEther(amount),
    });
  };

  const { writeContract: resolve, isPending: resolving } = useWriteContract();
  const { writeContract: claim, isPending: claiming } = useWriteContract();

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Market Details & Betting</h2>
      <input value={marketId} onChange={(e) => setMarketId(e.target.value)} placeholder="Market ID (0, 1, 2...)" className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-3 text-white focus:border-indigo-500 focus:outline-none" />

      {meta && pools && (
        <div className="space-y-4">
          {/* Market Info */}
          <div className="rounded-xl border border-gray-800 bg-gray-900/50 p-6">
            <h3 className="text-xl font-semibold mb-3">{meta[0] as string}</h3>
            {odds && <OddsBar yesBps={Number(odds[0])} />}
            <div className="grid grid-cols-3 gap-4 mt-4">
              <div className="text-center">
                <div className="text-green-400 font-bold">{formatEther(pools[0] as bigint)} CELO</div>
                <div className="text-xs text-gray-500">YES Pool</div>
              </div>
              <div className="text-center">
                <div className="text-red-400 font-bold">{formatEther(pools[1] as bigint)} CELO</div>
                <div className="text-xs text-gray-500">NO Pool</div>
              </div>
              <div className="text-center">
                <div className="text-white font-bold">{formatEther(pools[2] as bigint)} CELO</div>
                <div className="text-xs text-gray-500">Total</div>
              </div>
            </div>
            <div className="flex items-center gap-4 mt-3 text-sm">
              <span className={`font-medium ${OUTCOME_COLORS[Number(pools[3])]}`}>
                {pools[4] ? `Resolved: ${OUTCOME_LABELS[Number(pools[3])]}` : "Open"}
              </span>
              <span className="text-gray-500">
                Deadline: {new Date(Number(pools[5]) * 1000).toLocaleString()}
              </span>
            </div>
          </div>

          {/* Bet Form */}
          {!pools[4] && (
            <div className="rounded-xl border border-gray-800 bg-gray-900/50 p-6 space-y-4">
              <h3 className="text-lg font-semibold">Place Your Bet</h3>
              <div className="flex gap-2">
                <button onClick={() => setSide("yes")} className={`flex-1 rounded-lg py-3 font-semibold transition ${side === "yes" ? "bg-green-500 text-white" : "border border-gray-700 text-gray-400 hover:text-white"}`}>YES ✅</button>
                <button onClick={() => setSide("no")} className={`flex-1 rounded-lg py-3 font-semibold transition ${side === "no" ? "bg-red-500 text-white" : "border border-gray-700 text-gray-400 hover:text-white"}`}>NO ❌</button>
              </div>
              <input type="number" step="0.001" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="Amount in CELO" className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-3 text-white focus:border-indigo-500 focus:outline-none" />
              <button onClick={bet} disabled={isPending || confirming} className="w-full rounded-lg bg-indigo-500 px-6 py-3 font-semibold text-white transition hover:bg-indigo-400 disabled:opacity-50">
                {isPending ? "Confirm..." : confirming ? "Betting..." : `Bet ${amount} CELO on ${side.toUpperCase()}`}
              </button>
              {isSuccess && <div className="text-green-400 text-sm">✅ Bet placed!</div>}
            </div>
          )}

          {/* Resolve + Claim */}
          {pools[4] ? (
            <button onClick={() => claim({ address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "claimWinnings", args: [id] })} disabled={claiming} className="w-full rounded-lg bg-yellow-500 px-6 py-3 font-semibold text-black transition hover:bg-yellow-400 disabled:opacity-50">
              {claiming ? "Claiming..." : "🏆 Claim Winnings"}
            </button>
          ) : (
            <div className="flex gap-2">
              {[1, 2, 3].map((o) => (
                <button key={o} onClick={() => resolve({ address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "resolveMarket", args: [id, o] })} disabled={resolving} className="flex-1 rounded-lg border border-gray-700 px-4 py-2 text-sm text-gray-400 hover:text-white hover:border-gray-500">
                  Resolve {OUTCOME_LABELS[o]}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function BrowseMarkets() {
  const { data: total } = useReadContract({ address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "nextMarketId" });
  const { address } = useAccount();
  const { data: userIds } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getUserMarkets", args: [address!],
    query: { enabled: !!address },
  });
  const { data: createdIds } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getCreatedMarkets", args: [address!],
    query: { enabled: !!address },
  });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Markets</h2>
      <div className="grid grid-cols-3 gap-4">
        <div className="rounded-xl border border-gray-800 bg-gray-900/50 p-6 text-center">
          <div className="text-3xl font-bold text-indigo-400">{total !== undefined ? Number(total) : "..."}</div>
          <div className="text-sm text-gray-500">Total Markets</div>
        </div>
        <div className="rounded-xl border border-gray-800 bg-gray-900/50 p-6 text-center">
          <div className="text-3xl font-bold text-violet-400">{createdIds ? (createdIds as readonly bigint[]).length : "..."}</div>
          <div className="text-sm text-gray-500">Created by You</div>
        </div>
        <div className="rounded-xl border border-gray-800 bg-gray-900/50 p-6 text-center">
          <div className="text-3xl font-bold text-pink-400">{userIds ? (userIds as readonly bigint[]).length : "..."}</div>
          <div className="text-sm text-gray-500">Your Bets</div>
        </div>
      </div>
      {userIds && (userIds as readonly bigint[]).length > 0 && (
        <div>
          <h3 className="text-lg font-semibold mb-2">Your Active Markets</h3>
          <div className="flex flex-wrap gap-2">
            {(userIds as readonly bigint[]).map((id) => (
              <span key={id.toString()} className="rounded-full bg-indigo-500/20 text-indigo-400 px-3 py-1 text-sm">Market #{id.toString()}</span>
            ))}
          </div>
        </div>
      )}
      <p className="text-sm text-gray-500">Use the Bet tab to view and interact with any market by ID.</p>
    </div>
  );
}

function Portfolio() {
  const { address } = useAccount();
  const { data: userIds } = useReadContract({
    address: PREDICT_ADDRESS, abi: PREDICT_ABI, functionName: "getUserMarkets", args: [address!],
    query: { enabled: !!address },
  });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Your Portfolio</h2>
      {!userIds || (userIds as readonly bigint[]).length === 0 ? (
        <div className="text-center py-12 text-gray-400">No bets yet. Create a market or place a bet to get started!</div>
      ) : (
        <div className="space-y-3">
          {(userIds as readonly bigint[]).map((id) => (
            <div key={id.toString()} className="rounded-xl border border-gray-800 bg-gray-900/50 p-4 flex items-center justify-between">
              <span className="text-indigo-400 font-medium">Market #{id.toString()}</span>
              <a href={`/dashboard?tab=bet&id=${id.toString()}`} className="text-sm text-gray-400 hover:text-white">View →</a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function Dashboard() {
  const [tab, setTab] = useState<Tab>("markets");
  const { isConnected } = useAccount();

  const tabs: { id: Tab; label: string; icon: string }[] = [
    { id: "markets", label: "Markets", icon: "🔮" },
    { id: "create", label: "Create", icon: "➕" },
    { id: "bet", label: "Bet", icon: "🎯" },
    { id: "portfolio", label: "Portfolio", icon: "💼" },
  ];

  return (
    <div className="min-h-screen bg-gray-950">
      <header className="border-b border-gray-800 px-6 py-4">
        <div className="mx-auto flex max-w-5xl items-center justify-between">
          <a href="/" className="flex items-center gap-2">
            <span className="text-xl">🔮</span>
            <span className="text-lg font-bold bg-gradient-to-r from-indigo-400 to-violet-300 bg-clip-text text-transparent">PredictMarket</span>
          </a>
          <ConnectKitButton />
        </div>
      </header>
      <div className="mx-auto max-w-5xl px-6 py-8">
        <div className="flex gap-1 mb-8 rounded-lg border border-gray-800 bg-gray-900/50 p-1">
          {tabs.map((t) => (
            <button key={t.id} onClick={() => setTab(t.id)} className={`flex-1 rounded-md px-4 py-2.5 text-sm font-medium transition ${tab === t.id ? "bg-indigo-500 text-white" : "text-gray-400 hover:text-white"}`}>
              {t.icon} {t.label}
            </button>
          ))}
        </div>
        {!isConnected ? (
          <div className="text-center py-20"><div className="text-4xl mb-4">🔮</div><h2 className="text-2xl font-bold mb-2">Connect Your Wallet</h2><p className="text-gray-400">Connect to start predicting</p></div>
        ) : (
          <>
            {tab === "markets" && <BrowseMarkets />}
            {tab === "create" && <CreateMarket />}
            {tab === "bet" && <BetOnMarket />}
            {tab === "portfolio" && <Portfolio />}
          </>
        )}
      </div>
    </div>
  );
}
