import Link from "next/link";
import EventDiscoverRefreshButton from "@/(landing)/events/discover/components/EventDiscoverRefreshButton";
import {
  formatEventPeriod,
  formatEventPrice,
  getDiscoverEvents,
  getEventStatus,
  type DiscoverEventStatus,
} from "@/lib/events/discover";
import { discoverList, discoverStatusColor } from "@/(landing)/events/discover/styles/list";

const statusLabel: Record<DiscoverEventStatus, string> = {
  upcoming: "Upcoming",
  live: "Live",
  ended: "Ended",
  sold_out: "Sold out",
};

export default async function EventDiscoverList() {
  try {
    const events = await getDiscoverEvents();

    return (
      <section className={discoverList.section}>
        <header className={discoverList.header}>
          <div>
            <p className={discoverList.eyebrow}>
              Discover Events
            </p>
            <h1 className={discoverList.title}>
              Live Events on Sepolia
            </h1>
            <p className={discoverList.description}>
              Explore active and upcoming sales from events created through the
              factory contract.
            </p>
          </div>
          <EventDiscoverRefreshButton />
        </header>

        {events.length === 0 && (
          <div className={discoverList.emptyCard}>
            No events have been created yet on this factory contract.
          </div>
        )}

        {events.length > 0 && (
          <div className={discoverList.grid}>
            {events.map((event) => {
              const status = getEventStatus(event);
              return (
                <article className={discoverList.card} key={event.id}>
                  <div className={discoverList.cardHeader}>
                    <h3 className={discoverList.cardTitle}>{event.name}</h3>
                    <span
                      className={`${discoverList.statusBadge} ${discoverStatusColor[status]}`}
                    >
                      {statusLabel[status]}
                    </span>
                  </div>
                  <p className={discoverList.symbol}>{event.symbol}</p>
                  <div className={discoverList.details}>
                    <div>
                      Remaining tickets:{" "}
                      <span className="font-semibold">{event.remainingTickets}</span>
                    </div>
                    <div>
                      Period:{" "}
                      <span className="font-semibold">
                        {formatEventPeriod(event.saleStart, event.saleEnd)}
                      </span>
                    </div>
                    <div>
                      Price:{" "}
                      <span className="font-semibold">
                        {formatEventPrice(event.ticketPriceWei)}
                      </span>
                    </div>
                  </div>
                  <div className={discoverList.ctaWrap}>
                    <Link
                      href={`/events/discover/${event.eventTicket.toLowerCase()}/${event.id}`}
                      className={discoverList.ctaButton}
                    >
                      View event
                    </Link>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </section>
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unable to load events right now.";

    return (
      <section className={discoverList.section}>
        <header className={discoverList.header}>
          <div>
            <p className={discoverList.eyebrow}>
              Discover Events
            </p>
            <h1 className={discoverList.title}>
              Live Events on Sepolia
            </h1>
          </div>
          <EventDiscoverRefreshButton />
        </header>
        <div className={discoverList.errorCard}>
          {message}
        </div>
      </section>
    );
  }
}
