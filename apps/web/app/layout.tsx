import "./globals.css";
import { Fredoka, Sora } from "next/font/google";
import Web3ProviderWrapper from "@/components/Web3ProviderWrapper";

const display = Fredoka({
  subsets: ["latin"],
  weight: ["400", "600", "700"],
  variable: "--font-display"
});

const bodyFont = Sora({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body"
});

export const metadata = {
  title: "Event Ticket Project",
  description:
    "Create events, sell tickets, and explore primary and fan-to-fan marketplaces with a collectible-inspired ticketing experience."
};

export default function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {

  return (
    <Web3ProviderWrapper>
      <html lang="en" className={`${display.variable} ${bodyFont.variable}`}>
        <body>
          <div className="grain" aria-hidden="true" />
          {children}
        </body>
      </html>
    </Web3ProviderWrapper>
  );
}
