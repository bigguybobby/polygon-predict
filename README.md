# 🔮 PredictMarket — Binary Prediction Markets for Polygon

> Built for the Polygon Prediction Markets Program

## Features
- Create binary YES/NO prediction markets with custom deadlines
- Place bets with ETH, proportional payout based on pool ratios
- Real-time odds calculation (basis points)
- Market resolution by designated oracle/creator
- Invalid market → full refund
- 2% protocol fee (configurable)
- Potential payout calculator
- User portfolio tracking

## Deployed
- **Celo Sepolia:** `0x9Aa87Cff875c671af7EDE5d750d0Ea747ABC23F0`

## Tests
12/12 passing — covers creation, betting, resolution, claims, refunds, edge cases

## Tech Stack
- Solidity 0.8.20 + Foundry
- Next.js + TypeScript + Tailwind (frontend)
- wagmi + viem + ConnectKit (wallet integration)
