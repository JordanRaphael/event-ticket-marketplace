import type { DiscoverEventStatus } from "@/lib/events/discover";

export const discoverList = {
  section: "grid gap-8",
  header: "flex flex-col gap-4 md:flex-row md:items-center md:justify-between",
  eyebrow: "text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]",
  title: "mt-3 text-3xl font-semibold text-[#1a1411]",
  description: "mt-2 text-sm text-[#5e5249]",
  emptyCard:
    "rounded-3xl border border-black/10 bg-white/70 p-6 text-sm text-[#5e5249] shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur",
  errorCard: "rounded-3xl border border-red-200 bg-red-50 p-6 text-sm text-red-700",
  grid: "feature-grid",
  card: "feature-card flex h-full flex-col",
  cardHeader: "flex min-h-[4.5rem] items-start justify-between gap-3",
  cardTitle: "mt-0 pr-2 leading-tight",
  statusBadge: "rounded-full px-2.5 py-1 text-xs font-semibold",
  symbol: "mt-2 min-h-[1.5rem] break-words text-sm text-[#5e5249]",
  details: "mt-4 grid gap-2 text-sm text-[#1a1411]",
  ctaWrap: "mt-auto pt-5",
  ctaButton: "btn small",
} as const;

export const discoverStatusColor: Record<DiscoverEventStatus, string> = {
  upcoming: "bg-amber-100 text-amber-800",
  live: "bg-emerald-100 text-emerald-800",
  ended: "bg-slate-200 text-slate-700",
  sold_out: "bg-rose-100 text-rose-700",
};
