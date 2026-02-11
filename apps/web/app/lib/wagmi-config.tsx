
import { http, createConfig, cookieStorage, createStorage } from "wagmi";
import { mainnet, sepolia } from "wagmi/chains";
import { injected, metaMask, safe, coinbaseWallet, walletConnect } from "wagmi/connectors";

const projectId = "32cb3920ce5fd0117ed8afc8c85f4ef7";

export function getConfig() {
  return createConfig({
    chains: [mainnet, sepolia],
    connectors: [
      injected({ target: "metaMask" }),
      metaMask(),
      coinbaseWallet(),
      walletConnect({ projectId }),
      safe()
    ],
    ssr: true,
    storage: createStorage({
      storage: cookieStorage,
    }),
    transports: {
      [mainnet.id]: http(),
      [sepolia.id]: http(),
    },
  });
}

export const config = getConfig();
