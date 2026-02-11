const inputBase =
  "rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40";

export const form = {
  section:
    "w-full max-w-3xl rounded-3xl border border-black/10 bg-white/70 p-10 shadow-[0_18px_40px_rgba(22,14,10,0.12)] backdrop-blur",
  header: "mb-8",
  eyebrow: "text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]",
  title: "mt-3 text-3xl font-semibold text-[#1a1411]",
  description: "mt-2 text-sm text-[#5e5249]",
  body: "grid gap-6",
  row: "grid gap-4 md:grid-cols-2",
  label: "grid gap-2 text-sm font-medium text-[#1a1411]",
  hint: "text-xs text-[#5e5249]",
  eventName: inputBase,
  eventSymbol: `${inputBase} uppercase tracking-[0.2em]`,
  eventUri: inputBase,
  organizerWallet: inputBase,
  priceInWei: inputBase,
  maxSupply: inputBase,
  saleStart: inputBase,
  saleEnd: inputBase,
  actions: "flex flex-wrap items-center gap-3",
  submitButton: "btn primary",
  resetButton: "btn ghost",
} as const;
