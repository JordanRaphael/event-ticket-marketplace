const steps = [
  {
    title: "List the event",
    detail: "Upload art, set capacity, and choose primary pricing."
  },
  {
    title: "Fans claim seats",
    detail: "Tickets stay verified across primary and resale channels."
  },
  {
    title: "Scan at the door",
    detail: "One tap entry with instant transfers and fraud protection."
  }
];

export default function TicketStrip() {
  return (
    <section className="ticket-strip" aria-label="How it works">
      <div className="ticket-header">
        <h2>From marquee to main stage</h2>
        <p>
          Built for organizers and fans who want a collectible ticket with a
          fast, secure entry experience.
        </p>
      </div>
      <div className="ticket-steps">
        {steps.map((step, index) => (
          <div className="ticket" key={step.title}>
            <div className="ticket-number">0{index + 1}</div>
            <div>
              <h3>{step.title}</h3>
              <p>{step.detail}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
