import Link from "next/link";
import PosterStack from "./PosterStack";

export default function Hero() {
  return (
    <section className="hero">
      <div className="hero-copy">
        <span className="eyebrow">Event Ticket Project</span>
        <h1>Poster-worthy tickets. Real-world entry.</h1>
        <p className="lead">
          Create events to sell tickets, then let fans discover them across
          primary listings and a verified resale marketplace.
        </p>
        <div className="cta-group">
          <Link href="/events/create">
            <button className="btn primary" type="button">
              Start selling events
            </button>
          </Link>
          <button className="btn ghost" type="button">
            Explore events
          </button>
        </div>
        <div className="stat-row">
          <div className="stat">
            <span className="stat-value">Organizer-first</span>
            <span className="stat-label">Primary listings in one tap</span>
          </div>
          <div className="stat">
            <span className="stat-value">Verified resale</span>
            <span className="stat-label">Fan-to-fan tickets you can trust</span>
          </div>
          <div className="stat">
            <span className="stat-value">Instant transfer</span>
            <span className="stat-label">Claim and scan in seconds</span>
          </div>
        </div>
      </div>
      <PosterStack />
    </section>
  );
}
