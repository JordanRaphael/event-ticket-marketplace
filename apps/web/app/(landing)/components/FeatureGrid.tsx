const features = [
  {
    title: "Create new events",
    description:
      "Build shows, set ticket tiers, and publish to the primary market with organizer-first control.",
    bullets: [
      "Tiered pricing and bundles",
      "Instant publish to the storefront",
      "Built-in attendee management"
    ]
  },
  {
    title: "Search and buy tickets",
    description:
      "Discover events by city, venue, or vibe and lock in tickets straight from organizers.",
    bullets: [
      "Smart filters and curated picks",
      "Transparent fees at checkout",
      "Fast mobile entry"
    ]
  },
  {
    title: "Marketplace for resellers",
    description:
      "Let fans resell safely with verified transfers, keeping the inventory alive and honest.",
    bullets: [
      "Verified fan-to-fan listings",
      "Automated transfer protection",
      "Price guardrails for fairness"
    ]
  }
];

function FeatureIcon() {
  return (
    <div className="feature-icon" aria-hidden="true">
      <svg viewBox="0 0 24 24" role="img" focusable="false">
        <path
          d="M6 4h12a2 2 0 0 1 2 2v2.2c0 .7-.3 1.4-.8 1.9L14.6 14v4.5l-3 1V14L4.8 10.1A2.7 2.7 0 0 1 4 8.2V6a2 2 0 0 1 2-2Z"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />
      </svg>
    </div>
  );
}

export default function FeatureGrid() {
  return (
    <section className="feature-grid" aria-label="Platform features">
      {features.map((feature) => (
        <article className="feature-card" key={feature.title}>
          <FeatureIcon />
          <h3>{feature.title}</h3>
          <p>{feature.description}</p>
          <ul>
            {feature.bullets.map((bullet) => (
              <li key={bullet}>{bullet}</li>
            ))}
          </ul>
        </article>
      ))}
    </section>
  );
}
