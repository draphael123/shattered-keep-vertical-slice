import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "The Shattered Keep — Mooncrypt Expedition",
  description: "A playable fantasy arcade co-op vertical slice.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
