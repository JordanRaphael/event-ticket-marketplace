const items = [
  "POSTER-WORTHY LINEUP",
  "VERIFIED ENTRY",
  "FAN-TO-FAN MARKETPLACE",
  "PRIMARY LISTINGS",
  "LIVE INVENTORY",
  "NO-SURPRISE FEES"
];

export default function Marquee() {
  return (
    <section className="marquee" aria-label="Highlights">
      <div className="marquee-track">
        {[...items, ...items].map((item, index) => (
          <span className="marquee-item" key={`${item}-${index}`}>
            {item}
          </span>
        ))}
      </div>
    </section>
  );
}
