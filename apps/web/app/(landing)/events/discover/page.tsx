import Header from "@/(landing)/components/Header";
import Footer from "@/(landing)/components/Footer";
import EventDiscoverList from "@/(landing)/events/discover/components/EventDiscoverList";

export const revalidate = 60;

export default function EventsDiscoverPage() {
  return (
    <main className="page">
      <Header />
      <EventDiscoverList />
      <Footer />
    </main>
  );
}
