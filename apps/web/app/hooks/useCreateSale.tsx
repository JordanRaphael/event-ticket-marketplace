"use client";

import { useCallback } from "react";
import type { Hash } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { factoryContract, type CreateSaleParams } from "@/lib/contracts/factory";

type UseCreateSaleReturn = {
  createSale: (params: CreateSaleParams) => Promise<Hash>;
};

export function useCreateSale(): UseCreateSaleReturn {
  const { address } = useAccount();
  const publicClient = usePublicClient({ chainId: factoryContract.chainId });
  const { writeContractAsync } = useWriteContract();

  const createSale = useCallback(
    async (params: CreateSaleParams) => {
      if (!address) {
        throw new Error("Wallet not connected");
      }
      if (!publicClient) {
        throw new Error("Public client not available");
      }

      const { request } = await publicClient.simulateContract({
        ...factoryContract,
        functionName: "createSale",
        args: [params],
        account: address,
      });

      return writeContractAsync(request);
    },
    [address, publicClient, writeContractAsync],
  );

  return { createSale };
}
