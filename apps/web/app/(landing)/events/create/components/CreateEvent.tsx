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
  organizerWallet: string;
  priceInWei: string;
  maxSupply: string;
  saleStart: string;
  saleEnd: string;
};

const initialFormState: CreateEventFormState = {
  eventName: "",
  eventSymbol: "",
  organizerWallet: "",
  priceInWei: "",
  maxSupply: "",
  saleStart: "",
  saleEnd: "",
};

type UploadEventMetadataResponse = {
  baseURI: string;
  imageURI: string;
  metadataURI: string;
};

async function uploadEventMetadata(params: {
  eventName: string;
  eventSymbol: string;
  icon: File;
}): Promise<UploadEventMetadataResponse> {
  const formData = new FormData();
  formData.append("eventName", params.eventName);
  formData.append("eventSymbol", params.eventSymbol);
  formData.append("icon", params.icon);

  const response = await fetch("/api/ipfs/event-metadata", {
    method: "POST",
    body: formData,
  });

  const payload = (await response.json().catch(() => null)) as
    | (Partial<UploadEventMetadataResponse> & { error?: string })
    | null;

  if (!response.ok) {
    throw new Error(payload?.error || "Unable to upload metadata to IPFS.");
  }

  if (!payload?.baseURI || !payload?.metadataURI || !payload?.imageURI) {
    throw new Error("Metadata upload response was invalid.");
  }

  return {
    baseURI: payload.baseURI,
    metadataURI: payload.metadataURI,
    imageURI: payload.imageURI,
  };
}

export default function CreateEventPage() {
  const { address } = useAccount();
  const { createSale } = useCreateSale();
  const [formState, setFormState] = useState<CreateEventFormState>(initialFormState);
  const [icon, setIcon] = useState<File | null>(null);
  const [iconPreviewUrl, setIconPreviewUrl] = useState<string | null>(null);
  const [organizerTouched, setOrganizerTouched] = useState(false);
  const [txHash, setTxHash] = useState<Hash | undefined>(undefined);
  const [successMessage, setSuccessMessage] = useState("");
  const [statusMessage, setStatusMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [uploadedMetadataUri, setUploadedMetadataUri] = useState("");
  const [isUploadingMetadata, setIsUploadingMetadata] = useState(false);
  const [fileInputKey, setFileInputKey] = useState(0);
  const [submittedEventName, setSubmittedEventName] = useState("");

  const { isSuccess: isTxSuccess, fetchStatus } = useWaitForTransactionReceipt({
    hash: txHash,
    query: {
      enabled: Boolean(txHash),
    },
  });

  const isTxPending = fetchStatus === "fetching";
  const isPending = isTxPending || isUploadingMetadata;

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
      setSuccessMessage(`Event ${submittedEventName} successfully created! 🎉`);
      setStatusMessage("");
    }
  }, [isTxSuccess, submittedEventName]);

  useEffect(() => {
    if (!icon) {
      setIconPreviewUrl(null);
      return;
    }

    const previewUrl = URL.createObjectURL(icon);
    setIconPreviewUrl(previewUrl);

    return () => URL.revokeObjectURL(previewUrl);
  }, [icon]);

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

  const handleIconChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] || null;
    setIcon(file);
    setUploadedMetadataUri("");
    setErrorMessage("");
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setErrorMessage("");
    setSuccessMessage("");

    if (!address) {
      setErrorMessage("Connect a wallet before creating a ticket sale.");
      return;
    }

    if (!icon) {
      setErrorMessage("Upload an event icon before creating the event.");
      return;
    }

    const eventName = formState.eventName.trim();
    const eventSymbol = formState.eventSymbol.trim();

    const saleStartMs = new Date(formState.saleStart).getTime();
    const saleEndMs = new Date(formState.saleEnd).getTime();

    if (Number.isNaN(saleStartMs) || Number.isNaN(saleEndMs)) {
      setErrorMessage("Invalid sale start or end date.");
      return;
    }

    const organizer = (formState.organizerWallet || address) as Address;

    try {
      setIsUploadingMetadata(true);
      setStatusMessage("Uploading event metadata to IPFS...");

      const { baseURI, metadataURI } = await uploadEventMetadata({
        eventName,
        eventSymbol,
        icon,
      });
      setUploadedMetadataUri(metadataURI);
      setStatusMessage("Metadata pinned. Submit your wallet transaction.");

      const txHash = await createSale({
        name: eventName,
        symbol: eventSymbol,
        baseURI,
        organizer,
        priceInWei: BigInt(formState.priceInWei),
        maxSupply: BigInt(formState.maxSupply),
        saleStart: BigInt(Math.floor(saleStartMs / 1000)),
        saleEnd: BigInt(Math.floor(saleEndMs / 1000)),
      });

      setSubmittedEventName(eventName);
      setTxHash(txHash);
      setStatusMessage("Transaction submitted. Waiting for confirmation...");
    } catch (error) {
      const fallbackMessage = "Failed to create ticket sale.";
      setErrorMessage(error instanceof Error ? error.message : fallbackMessage);
      setStatusMessage("");
      console.error("Failed to create ticket sale", error);
    } finally {
      setIsUploadingMetadata(false);
    }
  };

  return (
    <>
      <ActionPopup message={successMessage} onClose={() => setSuccessMessage("")}/>
      <section className={form.section}>
        <header className={form.header}>
          <p className={form.eyebrow}>Event Builder</p>
          <h1 className={form.title}>Create an Event</h1>
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
            Event icon
            <input
              key={fileInputKey}
              className={form.eventIconInput}
              type="file"
              accept="image/png,image/jpeg,image/webp,image/gif,image/svg+xml"
              required
              onChange={handleIconChange}
            />
            <span className={form.hint}>
              The icon and event metadata are pinned to IPFS automatically.
            </span>
          </label>

          <div className={form.iconPreviewCard}>
            {iconPreviewUrl ? (
              <img src={iconPreviewUrl} alt="Event icon preview" className={form.iconPreviewImage} />
            ) : (
              <div className={form.iconPreviewPlaceholder}>No icon</div>
            )}
            <div className={form.iconPreviewMeta}>
              <span>{icon ? icon.name : "Upload an image file to preview it."}</span>
              <span>{icon ? `${Math.ceil(icon.size / 1024)} KB` : "PNG, JPG, WEBP, GIF, SVG"}</span>
            </div>
          </div>

          {uploadedMetadataUri && (
            <div className={form.label}>
              Generated metadata URI
              <p className={form.metadataUri}>{uploadedMetadataUri}</p>
            </div>
          )}

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
            <span className={form.hint}>Defaulting to your connected wallet address.</span>
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

          {statusMessage && <p className={form.statusMessage}>{statusMessage}</p>}
          {errorMessage && <p className={form.errorMessage}>{errorMessage}</p>}

          <div className={form.actions}>
            <Button className={form.submitButton} type="submit" disabled={isPending}>
              {isUploadingMetadata
                ? "Uploading to IPFS..."
                : isTxPending
                  ? "Submitting..."
                  : "Create ticket sale"}
            </Button>
            <Button
              className={form.resetButton}
              type="button"
              onClick={() => {
                setOrganizerTouched(false);
                setIcon(null);
                setUploadedMetadataUri("");
                setStatusMessage("");
                setErrorMessage("");
                setFileInputKey((prev) => prev + 1);
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
