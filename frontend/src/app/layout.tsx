import type { Metadata } from "next";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "PredictMarket — Binary Prediction Markets",
  description: "Create and trade on binary prediction markets on Polygon",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-950 text-white antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
