import { unstable_cache } from "next/cache";
import { type Address, createPublicClient, formatEther, http } from "viem";
import { sepolia } from "viem/chains";
import {
  factoryContract,
  factoryEventCreatedEvent,
} from "@/lib/contracts/factory";
import { saleAbi, ticketAbi } from "@/lib/contracts/event";

const LOG_START_BLOCK = 10231714n;
const MAX_LOG_BLOCK_RANGE = 1000n;

const client = createPublicClient({
  chain: sepolia,
  transport: http(),
});

type EventCreatedRecord = {
  id: string;
  organizer: Address;
  eventTicket: Address;
  ticketSale: Address;
  ticketMarketplace: Address;
};

export type DiscoverEventStatus = "upcoming" | "live" | "ended" | "sold_out";

export type DiscoverEvent = {
  id: string;
  organizer: Address;
  eventOrganizer: Address;
  eventTicket: Address;
  ticketSale: Address;
  ticketMarketplace: Address;
  name: string;
  symbol: string;
  baseUri: string;
  saleStart: number;
  saleEnd: number;
  ticketPriceWei: string;
  ticketMaxSupply: string;
  totalSupply: string;
  remainingTickets: string;
};

function getStatusFromValues(
  nowInSeconds: number,
  saleStart: number,
  saleEnd: number,
  remainingTickets: bigint,
): DiscoverEventStatus {
  if (remainingTickets <= 0n) return "sold_out";
  if (nowInSeconds < saleStart) return "upcoming";
  if (nowInSeconds > saleEnd) return "ended";
  return "live";
}

export function getEventStatus(
  event: Pick<DiscoverEvent, "saleStart" | "saleEnd" | "remainingTickets">,
  nowInSeconds = Math.floor(Date.now() / 1000),
) {
  return getStatusFromValues(
    nowInSeconds,
    event.saleStart,
    event.saleEnd,
    BigInt(event.remainingTickets),
  );
}

export function formatEventPeriod(saleStart: number, saleEnd: number) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
  return `${formatter.format(new Date(saleStart * 1000))} - ${formatter.format(new Date(saleEnd * 1000))}`;
}

export function formatEventPrice(ticketPriceWei: string) {
  return `${formatEther(BigInt(ticketPriceWei))} WETH`;
}

const getEventCreatedLogs = unstable_cache(
  async (): Promise<EventCreatedRecord[]> => {
    const latestBlock = await client.getBlockNumber();
    if (latestBlock < LOG_START_BLOCK) return [];

    const records: EventCreatedRecord[] = [];
    let cursor = LOG_START_BLOCK;

    while (cursor <= latestBlock) {
      const chunkEnd =
        cursor + MAX_LOG_BLOCK_RANGE - 1n > latestBlock
          ? latestBlock
          : cursor + MAX_LOG_BLOCK_RANGE - 1n;

      const logs = await client.getLogs({
        address: factoryContract.address,
        event: factoryEventCreatedEvent,
        fromBlock: cursor,
        toBlock: chunkEnd,
      });

      for (const log of logs) {
        const id = (log.args?.id ?? 0n).toString();
        const organizer = (log.args?.organizer ??
          "0x0000000000000000000000000000000000000000") as Address;
        const eventTicket = (log.args?.eventTicket ??
          "0x0000000000000000000000000000000000000000") as Address;
        const ticketSale = (log.args?.ticketSale ??
          "0x0000000000000000000000000000000000000000") as Address;
        const ticketMarketplace = (log.args?.ticketMarketplace ??
          "0x0000000000000000000000000000000000000000") as Address;

        records.push({ id, organizer, eventTicket, ticketSale, ticketMarketplace });
      }

      cursor = chunkEnd + 1n;
    }

    return records.sort((a, b) => {
      const left = BigInt(a.id);
      const right = BigInt(b.id);
      if (left === right) return 0;
      return left > right ? -1 : 1;
    });
  },
  ["factory-events-raw", factoryContract.address, LOG_START_BLOCK.toString()],
  {
    revalidate: 60,
    tags: ["factory-events"],
  },
);

async function hydrateEvent(record: EventCreatedRecord): Promise<DiscoverEvent> {
  const [
    name,
    symbol,
    baseUri,
    totalSupply,
    eventOrganizer,
    saleStart,
    saleEnd,
    ticketPriceWei,
    ticketMaxSupply,
  ] = await client.multicall({
    allowFailure: false,
    contracts: [
      { address: record.eventTicket, abi: ticketAbi, functionName: "name" },
      { address: record.eventTicket, abi: ticketAbi, functionName: "symbol" },
      { address: record.eventTicket, abi: ticketAbi, functionName: "baseURI" },
      { address: record.eventTicket, abi: ticketAbi, functionName: "totalSupply" },
      { address: record.ticketSale, abi: saleAbi, functionName: "eventOrganizer" },
      { address: record.ticketSale, abi: saleAbi, functionName: "saleStart" },
      { address: record.ticketSale, abi: saleAbi, functionName: "saleEnd" },
      { address: record.ticketSale, abi: saleAbi, functionName: "ticketPriceWei" },
      { address: record.ticketSale, abi: saleAbi, functionName: "ticketMaxSupply" },
    ],
  });

  const remainingTickets = ticketMaxSupply - totalSupply;

  return {
    id: record.id,
    organizer: record.organizer,
    eventOrganizer,
    eventTicket: record.eventTicket,
    ticketSale: record.ticketSale,
    ticketMarketplace: record.ticketMarketplace,
    name,
    symbol,
    baseUri,
    saleStart: Number(saleStart),
    saleEnd: Number(saleEnd),
    ticketPriceWei: ticketPriceWei.toString(),
    ticketMaxSupply: ticketMaxSupply.toString(),
    totalSupply: totalSupply.toString(),
    remainingTickets: remainingTickets.toString(),
  };
}

export const getDiscoverEvents = unstable_cache(
  async (): Promise<DiscoverEvent[]> => {
    const records = await getEventCreatedLogs();
    if (records.length === 0) return [];
    return Promise.all(records.map((record) => hydrateEvent(record)));
  },
  ["factory-events-hydrated", factoryContract.address, LOG_START_BLOCK.toString()],
  {
    revalidate: 60,
    tags: ["factory-events"],
  },
);

export async function getDiscoverEventByTicketAndId(
  ticketAddress: Address,
  ticketId: string,
) {
  const records = await getEventCreatedLogs();
  const record = records.find(
    (event) =>
      event.id === ticketId &&
      event.eventTicket.toLowerCase() === ticketAddress.toLowerCase(),
  );
  if (!record) return null;
  return hydrateEvent(record);
}
