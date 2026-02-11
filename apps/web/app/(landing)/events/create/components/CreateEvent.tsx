"use client";

import { useEffect, useState } from "react";
import type { ChangeEvent, FormEvent } from "react";
import type { Address, Hash } from "viem";
import { useAccount, useWaitForTransactionReceipt } from "wagmi";
import { useCreateSale } from "@/hooks/useCreateSale";
import ActionPopup from "@/components/ActionPopup";

type CreateEventFormState = {
  eventName: string;
  eventSymbol: string;
  eventUri: string;
  organizerWallet: string;
  priceInWei: string;
  maxSupply: string;
  saleStart: string;
  saleEnd: string;
};

const initialFormState: CreateEventFormState = {
  eventName: "",
  eventSymbol: "",
  eventUri: "",
  organizerWallet: "",
  priceInWei: "",
  maxSupply: "",
  saleStart: "",
  saleEnd: "",
};

export default function CreateEventPage() {
  const { address } = useAccount();
  const { createSale } = useCreateSale();
  const [formState, setFormState] = useState<CreateEventFormState>(initialFormState);
  const [organizerTouched, setOrganizerTouched] = useState(false);
  const [txHash, setTxHash] = useState<Hash | undefined>(undefined);
  const [successMessage, setSuccessMessage] = useState("");
  const [submittedEventName, setSubmittedEventName] = useState("");

  const { isSuccess: isTxSuccess, fetchStatus } = useWaitForTransactionReceipt({
    hash: txHash,
    query: {
      enabled: Boolean(txHash),
    },
  });

  const isPending = fetchStatus === "fetching";

  useEffect(() => {
    if (address && !organizerTouched) {
      setFormState((prev) => ({
        ...prev,
        organizerWallet: address,
      }));
    }
  }, [address, organizerTouched]);

  useEffect(() => {
    if (isTxSuccess && submittedEventName) {
      setSuccessMessage(`Event ${submittedEventName} Successfully Created ! 🎉`);
    }
  }, [isTxSuccess, submittedEventName]);

  const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
    const { name, value } = event.target;
    setFormState((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleOrganizerChange = (event: ChangeEvent<HTMLInputElement>) => {
    if (!organizerTouched) {
      setOrganizerTouched(true);
    }
    handleChange(event);
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!address) {
      console.warn("Connect a wallet before creating a ticket sale.");
      return;
    }

    const saleStartMs = new Date(formState.saleStart).getTime();
    const saleEndMs = new Date(formState.saleEnd).getTime();

    if (Number.isNaN(saleStartMs) || Number.isNaN(saleEndMs)) {
      console.warn("Invalid sale start or end date.");
      return;
    }

    const organizer = (formState.organizerWallet || address) as Address;

    try {
      const txHash = await createSale({
        name: formState.eventName.trim(),
        symbol: formState.eventSymbol.trim(),
        baseURI: formState.eventUri.trim(),
        organizer,
        priceInWei: BigInt(formState.priceInWei),
        maxSupply: BigInt(formState.maxSupply),
        saleStart: BigInt(Math.floor(saleStartMs / 1000)),
        saleEnd: BigInt(Math.floor(saleEndMs / 1000)),
      });

      setSubmittedEventName(formState.eventName.trim());
      setTxHash(txHash);
    } catch (error) {
      console.error("Failed to create ticket sale", error);
    }
  };

  return (
    <>
      <ActionPopup
        message={successMessage}
      />
      <section className="w-full max-w-3xl rounded-3xl border border-black/10 bg-white/70 p-10 shadow-[0_18px_40px_rgba(22,14,10,0.12)] backdrop-blur">
        <header className="mb-8">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#5e5249]">
            Event Builder
          </p>
          <h1 className="mt-3 text-3xl font-semibold text-[#1a1411]">
            Create an Event
          </h1>
          <p className="mt-2 text-sm text-[#5e5249]">
            Fill in the essentials to create a ticket sale for an event.
          </p>
        </header>

        <form className="grid gap-6" onSubmit={handleSubmit}>
        <div className="grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Event name
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="eventName"
              placeholder="Monaco Grand Prix 2026"
              required
              value={formState.eventName}
              onChange={handleChange}
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Event symbol
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm uppercase tracking-[0.2em] focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="eventSymbol"
              placeholder="MGP26"
              required
              value={formState.eventSymbol}
              onChange={handleChange}
            />
          </label>
        </div>

        <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
          Event URI
          <input
            className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
            name="eventUri"
            placeholder="https://example.com/events/MonacoGP26"
            type="url"
            required
            value={formState.eventUri}
            onChange={handleChange}
          />
        </label>

        <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
          Organizer wallet
          <input
            className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
            name="organizerWallet"
            placeholder="0x..."
            required
            value={formState.organizerWallet}
            onChange={handleOrganizerChange}
          />
          <span className="text-xs text-[#5e5249]">
            Defaulting to your connected wallet address.
          </span>
        </label>

        <div className="grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Ticket price (wei)
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="priceInWei"
              placeholder="1000000000000000"
              required
              min="0"
              step="1000000000000000"
              type="number"
              value={formState.priceInWei}
              onChange={handleChange}
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Max supply
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="maxSupply"
              placeholder="2500"
              required
              min="1"
              step="1"
              type="number"
              value={formState.maxSupply}
              onChange={handleChange}
            />
          </label>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Sale start
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="saleStart"
              required
              type="datetime-local"
              value={formState.saleStart}
              onChange={handleChange}
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
            Sale end
            <input
              className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
              name="saleEnd"
              required
              type="datetime-local"
              value={formState.saleEnd}
              onChange={handleChange}
            />
          </label>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button className="btn primary" type="submit" disabled={isPending}>
            {isPending ? "Submitting..." : "Create ticket sale"}
          </button>
          <button
            className="btn ghost"
            type="button"
            onClick={() => {
              setOrganizerTouched(false);
              setFormState({
                ...initialFormState,
                organizerWallet: address || "",
              });
            }}
          >
            Reset
          </button>
        </div>
        </form>
      </section>
    </>
  );
}
