const cardBase =
  "rounded-3xl border border-black/10 bg-white/70 p-6 shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur";

export const eventDetails = {
  section: "grid gap-8",
  titleBlock: "flex flex-col gap-3",
  backLink: "text-sm font-semibold text-[#5e5249]",
  eyebrow: "text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]",
  title: "text-3xl font-semibold text-[#1a1411]",
  subtitle: "text-sm text-[#5e5249]",
  card: cardBase,
  cardTitle: "text-xl font-semibold text-[#1a1411]",
  overviewGrid: "mt-4 grid gap-3 text-sm text-[#1a1411] md:grid-cols-2",
  addressesGrid: "mt-4 grid gap-2 text-sm text-[#1a1411]",
  addressValue: "font-mono",
  metadataValue: "font-mono break-all",
} as const;

export const eventBuyPanel = {
  card: cardBase,
  title: "text-xl font-semibold text-[#1a1411]",
  priceText: "mt-2 text-sm text-[#5e5249]",
  totalText: "mt-1 text-sm text-[#5e5249]",
  availabilityText: "mt-3 text-sm font-medium text-amber-700",
  controls: "mt-4 grid gap-3",
  fieldLabel: "grid gap-2 text-sm font-medium text-[#1a1411]",
  quantityInput:
    "rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40",
  buyButton: "btn small",
  message: "mt-3 text-sm text-[#5e5249]",
} as const;
