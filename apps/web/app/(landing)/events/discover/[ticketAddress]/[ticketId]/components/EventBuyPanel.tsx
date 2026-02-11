"use client";

import { useEffect, useMemo, useState } from "react";
import type { Address } from "viem";
import { formatEther } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { factoryContract } from "@/lib/contracts/factory";
import { erc20Abi, saleAbi } from "@/lib/contracts/event";
import { Button } from "@/components/ui/button";

type EventBuyPanelProps = {
  eventName: string;
  saleAddress: Address;
  saleStart: number;
  saleEnd: number;
  remainingTickets: string;
  ticketPriceWei: string;
};

function toQuantity(value: string) {
  if (!/^\d+$/.test(value)) return null;
  const quantity = Number(value);
  if (!Number.isInteger(quantity) || quantity <= 0) return null;
  return quantity;
}

export default function EventBuyPanel({
  eventName,
  saleAddress,
  saleStart,
  saleEnd,
  remainingTickets,
  ticketPriceWei,
}: EventBuyPanelProps) {
  const { address } = useAccount();
  const publicClient = usePublicClient({ chainId: factoryContract.chainId });
  const { writeContractAsync } = useWriteContract();
  const [quantity, setQuantity] = useState("1");
  const [isPending, setIsPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [nowInSeconds, setNowInSeconds] = useState(() =>
    Math.floor(Date.now() / 1000),
  );

  useEffect(() => {
    const timer = setInterval(() => {
      setNowInSeconds(Math.floor(Date.now() / 1000));
    }, 30_000);
    return () => clearInterval(timer);
  }, []);

  const remaining = BigInt(remainingTickets);
  const priceWei = BigInt(ticketPriceWei);
  const parsedQuantity = toQuantity(quantity);
  const requestedQuantity = parsedQuantity ? BigInt(parsedQuantity) : 0n;
  const totalCost = requestedQuantity * priceWei;

  const availability = useMemo(() => {
    if (remaining <= 0n) return { isLive: false, reason: "Tickets are sold out." };
    if (nowInSeconds < saleStart) {
      return { isLive: false, reason: "Sale has not started yet." };
    }
    if (nowInSeconds > saleEnd) return { isLive: false, reason: "Sale has ended." };
    return { isLive: true, reason: null };
  }, [nowInSeconds, remaining, saleEnd, saleStart]);

  const handleBuy = async () => {
    if (!parsedQuantity) {
      setMessage("Enter a valid quantity.");
      return;
    }
    if (!address) {
      setMessage("Connect your wallet to buy tickets.");
      return;
    }
    if (!publicClient) {
      setMessage("Public client is not available.");
      return;
    }
    if (!availability.isLive) {
      setMessage(availability.reason);
      return;
    }
    if (requestedQuantity > remaining) {
      setMessage("Requested quantity exceeds remaining tickets.");
      return;
    }

    try {
      setIsPending(true);
      setMessage(null);

      const wethAddress = await publicClient.readContract({
        address: saleAddress,
        abi: saleAbi,
        functionName: "WETH",
      });
      const latestPriceWei = await publicClient.readContract({
        address: saleAddress,
        abi: saleAbi,
        functionName: "ticketPriceWei",
      });
      const latestTotalCost = requestedQuantity * latestPriceWei;

      const [allowance, balance] = await Promise.all([
        publicClient.readContract({
          address: wethAddress,
          abi: erc20Abi,
          functionName: "allowance",
          args: [address, saleAddress],
        }),
        publicClient.readContract({
          address: wethAddress,
          abi: erc20Abi,
          functionName: "balanceOf",
          args: [address],
        }),
      ]);

      if (balance < latestTotalCost) {
        setMessage("Insufficient WETH balance.");
        return;
      }

      if (allowance < latestTotalCost) {
        setMessage("Approving WETH...");
        const approveHash = await writeContractAsync({
          address: wethAddress,
          abi: erc20Abi,
          functionName: "approve",
          args: [saleAddress, latestTotalCost],
          chainId: factoryContract.chainId,
          account: address,
        });
        await publicClient.waitForTransactionReceipt({ hash: approveHash });
      }

      setMessage("Submitting buy transaction...");
      const { request } = await publicClient.simulateContract({
        address: saleAddress,
        abi: saleAbi,
        functionName: "buy",
        args: [requestedQuantity, latestPriceWei],
        account: address,
      });

      const hash = await writeContractAsync(request);
      await publicClient.waitForTransactionReceipt({ hash });
      setMessage(`Purchase complete for ${eventName}.`);
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Unable to complete purchase.";
      setMessage(errorMessage);
    } finally {
      setIsPending(false);
    }
  };

  return (
    <section className="rounded-3xl border border-black/10 bg-white/70 p-6 shadow-[0_18px_40px_rgba(22,14,10,0.08)] backdrop-blur">
      <h2 className="text-xl font-semibold text-[#1a1411]">Buy Tickets</h2>
      <p className="mt-2 text-sm text-[#5e5249]">
        Price per ticket: {formatEther(priceWei)} WETH
      </p>
      <p className="mt-1 text-sm text-[#5e5249]">
        Total: {formatEther(totalCost)} WETH
      </p>

      {!availability.isLive && (
        <p className="mt-3 text-sm font-medium text-amber-700">{availability.reason}</p>
      )}

      <div className="mt-4 grid gap-3">
        <label className="grid gap-2 text-sm font-medium text-[#1a1411]">
          Quantity
          <input
            className="rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#e0482d]/40"
            type="number"
            min="1"
            step="1"
            value={quantity}
            onChange={(event) => setQuantity(event.target.value)}
          />
        </label>
        <Button
          className="btn small"
          type="button"
          disabled={isPending || !availability.isLive}
          onClick={handleBuy}
        >
          {isPending ? "Processing..." : "Buy tickets"}
        </Button>
      </div>

      {message && <p className="mt-3 text-sm text-[#5e5249]">{message}</p>}
    </section>
  );
}
