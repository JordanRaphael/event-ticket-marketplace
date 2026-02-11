import type { Address } from "viem";
import { sepolia } from "wagmi/chains";

export const FACTORY_CHAIN_ID = sepolia.id;

export const FACTORY_ADDRESS_BY_CHAIN = {
  [sepolia.id]: "0x24b0835e023965134357ec9cf72cc5aca8b19b59",
} as const;

export const factoryEventCreatedEvent = {
  type: "event",
  name: "EventCreated",
  inputs: [
    { name: "organizer", type: "address", indexed: true },
    { name: "id", type: "uint256", indexed: true },
    { name: "eventTicket", type: "address", indexed: false },
    { name: "ticketSale", type: "address", indexed: false },
    { name: "ticketMarketplace", type: "address", indexed: false },
  ],
  anonymous: false,
} as const;

export const factoryAbi = [
  factoryEventCreatedEvent,
  {
    type: "function",
    name: "createSale",
    stateMutability: "nonpayable",
    inputs: [
      {
        name: "createSaleParams",
        type: "tuple",
        components: [
          { name: "name", type: "string" },
          { name: "symbol", type: "string" },
          { name: "baseURI", type: "string" },
          { name: "organizer", type: "address" },
          { name: "priceInWei", type: "uint256" },
          { name: "maxSupply", type: "uint256" },
          { name: "saleStart", type: "uint256" },
          { name: "saleEnd", type: "uint256" },
        ],
      },
    ],
    outputs: [],
  },
] as const;

export type CreateSaleParams = {
  name: string;
  symbol: string;
  baseURI: string;
  organizer: Address;
  priceInWei: bigint;
  maxSupply: bigint;
  saleStart: bigint;
  saleEnd: bigint;
};

export const factoryContract = {
  address: FACTORY_ADDRESS_BY_CHAIN[FACTORY_CHAIN_ID],
  abi: factoryAbi,
  chainId: FACTORY_CHAIN_ID,
} as const;
