export const PREDICT_ADDRESS = "0x9Aa87Cff875c671af7EDE5d750d0Ea747ABC23F0" as const;

export const PREDICT_ABI = [
  { type: "function", name: "createMarket", inputs: [{ name: "question", type: "string" }, { name: "deadline", type: "uint256" }, { name: "resolver", type: "address" }], outputs: [{ name: "marketId", type: "uint256" }], stateMutability: "nonpayable" },
  { type: "function", name: "placeBet", inputs: [{ name: "marketId", type: "uint256" }, { name: "isYes", type: "bool" }], outputs: [], stateMutability: "payable" },
  { type: "function", name: "resolveMarket", inputs: [{ name: "marketId", type: "uint256" }, { name: "outcome", type: "uint8" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "claimWinnings", inputs: [{ name: "marketId", type: "uint256" }], outputs: [], stateMutability: "nonpayable" },
  { type: "function", name: "nextMarketId", inputs: [], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getMarketPools", inputs: [{ name: "marketId", type: "uint256" }], outputs: [{ name: "yesPool", type: "uint256" }, { name: "noPool", type: "uint256" }, { name: "totalPool", type: "uint256" }, { name: "outcome", type: "uint8" }, { name: "resolved", type: "bool" }, { name: "deadline", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getMarketMeta", inputs: [{ name: "marketId", type: "uint256" }], outputs: [{ name: "question", type: "string" }, { name: "creator", type: "address" }, { name: "resolver", type: "address" }, { name: "createdAt", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getOdds", inputs: [{ name: "marketId", type: "uint256" }], outputs: [{ name: "yesBps", type: "uint256" }, { name: "noBps", type: "uint256" }], stateMutability: "view" },
  { type: "function", name: "getUserPosition", inputs: [{ name: "marketId", type: "uint256" }, { name: "user", type: "address" }], outputs: [{ name: "yesAmount", type: "uint256" }, { name: "noAmount", type: "uint256" }, { name: "claimed", type: "bool" }], stateMutability: "view" },
  { type: "function", name: "getUserMarkets", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256[]" }], stateMutability: "view" },
  { type: "function", name: "getCreatedMarkets", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256[]" }], stateMutability: "view" },
  { type: "function", name: "calculatePayout", inputs: [{ name: "marketId", type: "uint256" }, { name: "isYes", type: "bool" }, { name: "betAmount", type: "uint256" }], outputs: [{ name: "", type: "uint256" }], stateMutability: "view" },
] as const;

export const CELO_SEPOLIA = {
  id: 11142220,
  name: "Celo Sepolia",
  nativeCurrency: { name: "CELO", symbol: "CELO", decimals: 18 },
  rpcUrls: { default: { http: ["https://celo-sepolia.drpc.org"] } },
  blockExplorers: { default: { name: "CeloScan", url: "https://sepolia.celoscan.io" } },
  testnet: true,
} as const;
