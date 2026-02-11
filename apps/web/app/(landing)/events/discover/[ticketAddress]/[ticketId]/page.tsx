import Link from "next/link";
import { notFound } from "next/navigation";
import type { Address } from "viem";
import { isAddress } from "viem";
import Header from "@/(landing)/components/Header";
import Footer from "@/(landing)/components/Footer";
import EventBuyPanel from "@/(landing)/events/discover/[ticketAddress]/[ticketId]/components/EventBuyPanel";
import {
  formatEventPeriod,
  formatEventPrice,
  getDiscoverEventByTicketAndId,
  getEventStatus,
} from "@/lib/events/discover";

type EventDetailsPageProps = {
  params: Promise<{
    ticketAddress: string;
    ticketId: string;
  }>;
};

const statusLabel = {
  upcoming: "Upcoming",
  live: "Live",
  ended: "Ended",
  sold_out: "Sold out",
} as const;

export const revalidate = 60;

export default async function EventDetailsPage({ params }: EventDetailsPageProps) {
  const { ticketAddress, ticketId } = await params;
  const normalizedTicketAddress = ticketAddress.toLowerCase();

  if (!isAddress(normalizedTicketAddress) || !/^\d+$/.test(ticketId)) notFound();

  const event = await getDiscoverEventByTicketAndId(
    normalizedTicketAddress as Address,
    ticketId,
  );
  if (!event) notFound();

  const status = getEventStatus(event);

  return (
    <main className="page">
      <Header />

      <section className="grid gap-8">
        <div className="flex flex-col gap-3">
          <Link href="/events/discover" className="text-sm font-semibold text-[#5e5249]">
            Back to discover
          </Link>
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]">
            Event details
          </p>
          <h1 className="text-3xl font-semibold text-[#1a1411]">{event.name}</h1>
          <p className="text-sm text-[#5e5249]">
            {event.symbol} • Event #{event.id} • {statusLabel[status]}
          </p>
        </div>

        <section className="rounded-3xl border border-black/10 bg-white/70 p-6 shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur">
          <h2 className="text-xl font-semibold text-[#1a1411]">Overview</h2>
          <div className="mt-4 grid gap-3 text-sm text-[#1a1411] md:grid-cols-2">
            <p>
              Remaining tickets:{" "}
              <span className="font-semibold">{event.remainingTickets}</span>
            </p>
            <p>
              Price: <span className="font-semibold">{formatEventPrice(event.ticketPriceWei)}</span>
            </p>
            <p>
              Period:{" "}
              <span className="font-semibold">
                {formatEventPeriod(event.saleStart, event.saleEnd)}
              </span>
            </p>
            <p>
              Minted:{" "}
              <span className="font-semibold">
                {event.totalSupply} / {event.ticketMaxSupply}
              </span>
            </p>
          </div>
        </section>

        <section className="rounded-3xl border border-black/10 bg-white/70 p-6 shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur">
          <h2 className="text-xl font-semibold text-[#1a1411]">Onchain addresses</h2>
          <div className="mt-4 grid gap-2 text-sm text-[#1a1411]">
            <p>
              Ticket contract: <span className="font-mono">{event.eventTicket}</span>
            </p>
            <p>
              Sale contract: <span className="font-mono">{event.ticketSale}</span>
            </p>
            <p>
              Marketplace contract:{" "}
              <span className="font-mono">{event.ticketMarketplace}</span>
            </p>
            <p>
              Event organizer: <span className="font-mono">{event.eventOrganizer}</span>
            </p>
            <p>
              Event creator: <span className="font-mono">{event.organizer}</span>
            </p>
            <p>
              Metadata URI: <span className="font-mono break-all">{event.baseUri}</span>
            </p>
          </div>
        </section>

        <EventBuyPanel
          eventName={event.name}
          saleAddress={event.ticketSale}
          saleStart={event.saleStart}
          saleEnd={event.saleEnd}
          remainingTickets={event.remainingTickets}
          ticketPriceWei={event.ticketPriceWei}
        />
      </section>

      <Footer />
    </main>
  );
}
