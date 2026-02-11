const cards = [
  {
    title: "Midnight Open Air",
    subtitle: "Poster Series 03",
    detail: "21 Sep · Harbor Bowl",
    tag: "Primary"
  },
  {
    title: "Vinyl & Fire",
    subtitle: "Collector Ticket",
    detail: "05 Oct · Civic Hall",
    tag: "Resale"
  },
  {
    title: "Stadium Stories",
    subtitle: "Gate Pass",
    detail: "12 Oct · East Field",
    tag: "VIP"
  }
]; // @todo fetch events and showcase them here

export default function PosterStack() {
  return (
    <div className="poster-stack" aria-hidden="true">
      {cards.map((card, index) => (
        <div className={`poster-card poster-card--${index + 1}`} key={card.title}>
          <div className="poster-header">
            <span className="poster-tag">{card.tag}</span>
            <span className="poster-seal" />
          </div>
          <div className="poster-title">{card.title}</div>
          <div className="poster-subtitle">{card.subtitle}</div>
          <div className="poster-detail">{card.detail}</div>
        </div>
      ))}
    </div>
  );
}
