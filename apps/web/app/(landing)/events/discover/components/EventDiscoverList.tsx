import Link from "next/link";
import EventDiscoverRefreshButton from "@/(landing)/events/discover/components/EventDiscoverRefreshButton";
import {
  formatEventPeriod,
  formatEventPrice,
  getDiscoverEvents,
  getEventStatus,
  type DiscoverEventStatus,
} from "@/lib/events/discover";

const statusLabel: Record<DiscoverEventStatus, string> = {
  upcoming: "Upcoming",
  live: "Live",
  ended: "Ended",
  sold_out: "Sold out",
};

const statusColor: Record<DiscoverEventStatus, string> = {
  upcoming: "bg-amber-100 text-amber-800",
  live: "bg-emerald-100 text-emerald-800",
  ended: "bg-slate-200 text-slate-700",
  sold_out: "bg-rose-100 text-rose-700",
};

export default async function EventDiscoverList() {
  try {
    const events = await getDiscoverEvents();

    return (
      <section className="grid gap-8">
        <header className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]">
              Discover Events
            </p>
            <h1 className="mt-3 text-3xl font-semibold text-[#1a1411]">
              Live Events on Sepolia
            </h1>
            <p className="mt-2 text-sm text-[#5e5249]">
              Explore active and upcoming sales from events created through the
              factory contract.
            </p>
          </div>
          <EventDiscoverRefreshButton />
        </header>

        {events.length === 0 && (
          <div className="rounded-3xl border border-black/10 bg-white/70 p-6 text-sm text-[#5e5249] shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur">
            No events have been created yet on this factory contract.
          </div>
        )}

        {events.length > 0 && (
          <div className="feature-grid">
            {events.map((event) => {
              const status = getEventStatus(event);
              return (
                <article className="feature-card" key={event.id}>
                  <div className="flex items-start justify-between gap-3">
                    <h3 className="mt-0">{event.name}</h3>
                    <span
                      className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusColor[status]}`}
                    >
                      {statusLabel[status]}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-[#5e5249]">{event.symbol}</p>
                  <div className="mt-4 grid gap-2 text-sm text-[#1a1411]">
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
                  <div className="mt-5">
                    <Link
                      href={`/events/discover/${event.eventTicket.toLowerCase()}/${event.id}`}
                      className="btn small"
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
      <section className="grid gap-8">
        <header className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]">
              Discover Events
            </p>
            <h1 className="mt-3 text-3xl font-semibold text-[#1a1411]">
              Live Events on Sepolia
            </h1>
          </div>
          <EventDiscoverRefreshButton />
        </header>
        <div className="rounded-3xl border border-red-200 bg-red-50 p-6 text-sm text-red-700">
          {message}
        </div>
      </section>
    );
  }
}
