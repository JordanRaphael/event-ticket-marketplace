"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Button } from "@/components/ui/button";

export default function EventDiscoverRefreshButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  return (
    <Button
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
    </Button>
  );
}
