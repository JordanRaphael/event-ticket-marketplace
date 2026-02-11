import { headers } from "next/headers";
import { cookieToInitialState } from "wagmi";
import { getConfig } from "@/lib/wagmi-config";
import { Web3Provider } from "@/components/Web3Provider";

export default async function Web3ProviderWrapper({
  children
}: {
  children: React.ReactNode;
}) {
  const headerList = await headers();
  const cookieHeader = headerList.get("cookie") ?? "";
  const initialState = cookieToInitialState(getConfig(), cookieHeader);

  return <Web3Provider initialState={initialState}>{children}</Web3Provider>;
}
