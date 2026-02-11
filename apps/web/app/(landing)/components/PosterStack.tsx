import { getDiscoverEvents, getEventStatus } from "@/lib/events/discover";
import Link from "next/link";

type PosterCard = {
  id: string;
  address: string;
  title: string;
  subtitle: string;
  detail: string;
  tag: string;
};

function formatSaleDate(timestampInSeconds: number) {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  }).format(new Date(timestampInSeconds * 1000));
}

function formatTag(status: ReturnType<typeof getEventStatus>) {
  if (status === "live") return "Live";
  if (status === "upcoming") return "Upcoming";
  if (status === "sold_out") return "Sold out";
  return "Ended";
}

export default async function PosterStack() {
  const events = await getDiscoverEvents();
  const cards: PosterCard[] = events.slice(0, 3).map((event) => {
    const status = getEventStatus(event);
    const saleStart = formatSaleDate(event.saleStart);
    const saleEnd = formatSaleDate(event.saleEnd);

    return {
      id: event.id,
      address: event.eventTicket,
      title: event.name,
      subtitle: event.symbol,
      detail: `${saleStart} - ${saleEnd} · ${event.remainingTickets} left`,
      tag: formatTag(status),
    };
  });

  if (cards.length === 0) {
    cards.push({
      id: "empty",
      address: "0x0",
      title: "No events yet",
      subtitle: "Create your first onchain sale",
      detail: "New events appear here as soon as they are created.",
      tag: "Discover",
    });
  }

  return (
    <div className="poster-stack">
      {cards.map((card, index) => (
        <Link href={`/events/discover/${card.address.toLowerCase()}/${card.id}`} key={card.id}>
          <div className={`poster-card poster-card--${index + 1}`}>
            <div className="poster-header">
              <span className="poster-tag">{card.tag}</span>
              <span className="poster-seal" />
            </div>
            <div className="poster-title">{card.title}</div>
            <div className="poster-subtitle">{card.subtitle}</div>
            <div className="poster-detail">{card.detail}</div>
          </div>
        </Link>
      ))}
    </div>
  );
}
