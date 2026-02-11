import Header from "@/(landing)/components/Header";
import Footer from "@/(landing)/components/Footer";
import CreateEventPage from "@/(landing)/events/create/components/CreateEvent";

export default function EventsCreatePage() {
  return (
    <main className="page">
      <Header />
      <CreateEventPage />
      <Footer />
    </main>
  );
}
