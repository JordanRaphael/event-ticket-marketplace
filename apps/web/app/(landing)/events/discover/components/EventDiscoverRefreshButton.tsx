"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function EventDiscoverRefreshButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  return (
    <button
      className="btn ghost small"
      type="button"
      onClick={() => {
        startTransition(() => {
          router.refresh();
        });
      }}
      disabled={isPending}
    >
      {isPending ? "Refreshing..." : "Refresh"}
    </button>
  );
}
