import { ConnectWalletButton } from "@/components/SimpleKit"
import Link from "next/link";

export default function Header() {
  return (
    <header className="nav">
    <Link href="/">
        <div className="brand">
            <span className="brand-mark">ET</span>
            <div>
            <div className="brand-name">Event Ticket Project</div>
            <div className="brand-tag">Primary + Marketplace</div>
            </div>
        </div>
    </Link>
    <div className="nav-actions">
        <Link href="/events/create">
        <span>Sell tickets</span>
        </Link>
        <span>Find events</span>
        <ConnectWalletButton /> {/* @todo add ens icon left of the connected address */}
    </div>
    </header>
  );
}
