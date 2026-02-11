import Link from "next/link";

export default function Footer() {
  return (
    <footer className="footer">
      <div>
        <span className="footer-brand">Event Ticket Project</span>
        <p>
          Crafted for venues, promoters, and fans who want ticketing to feel
          memorable again.
        </p>
      </div>
      <div className="footer-links">
        <Link href="/events/discover">
          <span>Primary Market</span>
        </Link>
        <span>Marketplace</span>
        <span>Organizer Tools</span>
      </div>
    </footer>
  );
}
