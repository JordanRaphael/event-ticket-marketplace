import FeatureGrid from "@/(landing)/components/FeatureGrid";
import Header from "@/(landing)/components/Header";
import Footer from "@/(landing)/components/Footer";
import Hero from "@/(landing)/components/Hero";
import Marquee from "@/(landing)/components/Marquee";
import TicketStrip from "@/(landing)/components/TicketStrip";
import Link from "next/link";

import { Button } from "@/components/ui/button";

export default function HomePage() {
  return (
        <main className="page">
          <Header />
          <Hero />
          <Marquee />
          <FeatureGrid />
          <TicketStrip />
          <section className="cta-panel">
            <div>
              <h2>Ready to build your next sold-out night?</h2>
              <p>
                Bring your venue online with ticketing that feels like a
                collectible.
              </p>
            </div>
            <div className="cta-group">
              <Link href="/events/create">
                <Button className="btn primary" type="button">
                  Create an event
                </Button>
              </Link>
              <Button className="btn ghost" type="button">
                Browse the marketplace
              </Button>
            </div>
          </section>
          <Footer />
        </main>
  );
}
