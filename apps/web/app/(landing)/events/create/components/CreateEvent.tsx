"use client";

import { useEffect, useState } from "react";
import type { ChangeEvent, FormEvent } from "react";
import type { Address, Hash } from "viem";
import { useAccount, useWaitForTransactionReceipt } from "wagmi";
import { useCreateSale } from "@/hooks/useCreateSale";
import { Button } from "@/components/ui/button";
import ActionPopup from "@/components/ActionPopup";
import { form } from "@/(landing)/events/create/styles/form";

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
      <section className={form.section}>
        <header className={form.header}>
          <p className={form.eyebrow}>
            Event Builder
          </p>
          <h1 className={form.title}>
            Create an Event
          </h1>
          <p className={form.description}>
            Fill in the essentials to create a ticket sale for an event.
          </p>
        </header>

        <form className={form.body} onSubmit={handleSubmit}>
        <div className={form.row}>
          <label className={form.label}>
            Event name
            <input
              className={form.eventName}
              name="eventName"
              placeholder="Monaco Grand Prix 2026"
              required
              value={formState.eventName}
              onChange={handleChange}
            />
          </label>
          <label className={form.label}>
            Event symbol
            <input
              className={form.eventSymbol}
              name="eventSymbol"
              placeholder="MGP26"
              required
              value={formState.eventSymbol}
              onChange={handleChange}
            />
          </label>
        </div>

        <label className={form.label}>
          Event URI
          <input
            className={form.eventUri}
            name="eventUri"
            placeholder="https://example.com/events/MonacoGP26"
            type="url"
            required
            value={formState.eventUri}
            onChange={handleChange}
          />
        </label>

        <label className={form.label}>
          Organizer wallet
          <input
            className={form.organizerWallet}
            name="organizerWallet"
            placeholder="0x..."
            required
            value={formState.organizerWallet}
            onChange={handleOrganizerChange}
          />
          <span className={form.hint}>
            Defaulting to your connected wallet address.
          </span>
        </label>

        <div className={form.row}>
          <label className={form.label}>
            Ticket price (wei)
            <input
              className={form.priceInWei}
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
          <label className={form.label}>
            Max supply
            <input
              className={form.maxSupply}
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

        <div className={form.row}>
          <label className={form.label}>
            Sale start
            <input
              className={form.saleStart}
              name="saleStart"
              required
              type="datetime-local"
              value={formState.saleStart}
              onChange={handleChange}
            />
          </label>
          <label className={form.label}>
            Sale end
            <input
              className={form.saleEnd}
              name="saleEnd"
              required
              type="datetime-local"
              value={formState.saleEnd}
              onChange={handleChange}
            />
          </label>
        </div>

        <div className={form.actions}>
          <Button className={form.submitButton} type="submit" disabled={isPending}>
            {isPending ? "Submitting..." : "Create ticket sale"}
          </Button>
          <Button
            className={form.resetButton}
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
          </Button>
        </div>
        </form>
      </section>
    </>
  );
}
