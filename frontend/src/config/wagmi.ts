import { createConfig, http } from "wagmi";
import { CELO_SEPOLIA } from "./contract";
import { getDefaultConfig } from "connectkit";

export const config = createConfig(
  getDefaultConfig({
    chains: [CELO_SEPOLIA as any],
    transports: { [CELO_SEPOLIA.id]: http("https://celo-sepolia.drpc.org") },
    walletConnectProjectId: "polygon-predict-demo",
    appName: "PredictMarket",
  })
);
