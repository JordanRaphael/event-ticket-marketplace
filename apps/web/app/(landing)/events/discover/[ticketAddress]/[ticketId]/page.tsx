import Link from "next/link";
import { notFound } from "next/navigation";
import type { Address } from "viem";
import { isAddress } from "viem";
import Header from "@/(landing)/components/Header";
import Footer from "@/(landing)/components/Footer";
import EventBuyPanel from "@/(landing)/events/discover/[ticketAddress]/[ticketId]/components/EventBuyPanel";
import { eventDetails } from "@/(landing)/events/discover/[ticketAddress]/[ticketId]/styles/detail";
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

      <section className={eventDetails.section}>
        <div className={eventDetails.titleBlock}>
          <Link href="/events/discover" className={eventDetails.backLink}>
            Back to discover
          </Link>
          <p className={eventDetails.eyebrow}>
            Event details
          </p>
          <h1 className={eventDetails.title}>{event.name}</h1>
          <p className={eventDetails.subtitle}>
            {event.symbol} • Event #{event.id} • {statusLabel[status]}
          </p>
        </div>

        <section className={eventDetails.card}>
          <h2 className={eventDetails.cardTitle}>Overview</h2>
          <div className={eventDetails.overviewGrid}>
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

        <section className={eventDetails.card}>
          <h2 className={eventDetails.cardTitle}>Onchain addresses</h2>
          <div className={eventDetails.addressesGrid}>
            <p>
              Ticket contract: <span className={eventDetails.addressValue}>{event.eventTicket}</span>
            </p>
            <p>
              Sale contract: <span className={eventDetails.addressValue}>{event.ticketSale}</span>
            </p>
            <p>
              Marketplace contract:{" "}
              <span className={eventDetails.addressValue}>{event.ticketMarketplace}</span>
            </p>
            <p>
              Event organizer: <span className={eventDetails.addressValue}>{event.eventOrganizer}</span>
            </p>
            <p>
              Event creator: <span className={eventDetails.addressValue}>{event.organizer}</span>
            </p>
            <p>
              Metadata URI: <span className={eventDetails.metadataValue}>{event.baseUri}</span>
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
