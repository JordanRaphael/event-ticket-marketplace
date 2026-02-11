"use client";

import { Button } from "@/components/ui/button";

type ActionPopupProps = {
  message: string;
  onClose?: () => void;
};

export default function ActionPopup({ message, onClose }: ActionPopupProps) {
  if (!message.trim()) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center px-4 pb-6 sm:items-start sm:justify-end sm:p-6">
      <div
        className="w-full max-w-sm rounded-2xl border border-black/10 bg-white/90 p-4 shadow-[0_20px_45px_rgba(22,14,10,0.2)] backdrop-blur"
        role="status"
        aria-live="polite"
      >
        <div className="flex items-start justify-between gap-3">
          <p className="text-sm font-semibold text-[#1a1411]">{message}</p>
          {onClose ? (
            <Button
              className="text-xs font-semibold uppercase tracking-[0.2em] text-[#5e5249]"
              type="button"
              aria-label="Dismiss notification"
              onClick={onClose}
            >
              Close
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
