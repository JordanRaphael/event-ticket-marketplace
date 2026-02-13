import { NextResponse } from "next/server";

const PINATA_API_BASE_URL = "https://api.pinata.cloud";
const MAX_ICON_FILE_SIZE_BYTES = 5 * 1024 * 1024;
const PINATA_JWT = process.env.PINATA_JWT;

// @todo refactor pinata route

function buildPinName(value: string) {
  const normalized = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return normalized || "event";
}

async function readPinataError(response: Response) {
  try {
    const payload = (await response.json()) as { error?: { reason?: string } };
    if (payload?.error?.reason) return payload.error.reason;
  } catch {
    // ignore parse failure and use fallback
  }
  return `Pinata request failed with status ${response.status}.`;
}

type PinataFileResponse = {
  IpfsHash: string;
};

type PinataJsonResponse = {
  IpfsHash: string;
};

export async function POST(request: Request) {
  if (!PINATA_JWT) {
    return NextResponse.json(
      { error: "Missing PINATA_JWT in server environment." },
      { status: 500 },
    );
  }

  const formData = await request.formData();
  const eventName = String(formData.get("eventName") || "").trim();
  const eventSymbol = String(formData.get("eventSymbol") || "").trim();
  const icon = formData.get("icon");

  if (!eventName || !eventSymbol) {
    return NextResponse.json(
      { error: "Event name and symbol are required." },
      { status: 400 },
    );
  }

  if (!(icon instanceof File)) {
    return NextResponse.json({ error: "Event icon is required." }, { status: 400 });
  }

  if (!icon.type.startsWith("image/")) {
    return NextResponse.json(
      { error: "Event icon must be an image file." },
      { status: 400 },
    );
  }

  if (icon.size > MAX_ICON_FILE_SIZE_BYTES) {
    return NextResponse.json(
      { error: "Event icon must be 5MB or smaller." },
      { status: 400 },
    );
  }

  const basePinName = buildPinName(`${eventName}-${eventSymbol}`);
  const iconUploadBody = new FormData();
  iconUploadBody.append("file", icon, icon.name || `${basePinName}-icon`);
  iconUploadBody.append(
    "pinataMetadata",
    JSON.stringify({ name: `${basePinName}-icon` }),
  );
  iconUploadBody.append("pinataOptions", JSON.stringify({ cidVersion: 1 }));

  const iconUploadResponse = await fetch(
    `${PINATA_API_BASE_URL}/pinning/pinFileToIPFS`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${PINATA_JWT}`,
      },
      body: iconUploadBody,
    },
  );

  if (!iconUploadResponse.ok) {
    const message = await readPinataError(iconUploadResponse);
    return NextResponse.json(
      { error: `Failed to pin icon to IPFS. ${message}` },
      { status: 502 },
    );
  }

  const iconUploadJson =
    (await iconUploadResponse.json()) as PinataFileResponse;
  const imageURI = `ipfs://${iconUploadJson.IpfsHash}`;
  const metadata = {
    name: eventName,
    description: `Ticket for ${eventName}`,
    image: imageURI,
    symbol: eventSymbol,
  };

  const metadataUploadResponse = await fetch(
    `${PINATA_API_BASE_URL}/pinning/pinJSONToIPFS`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${PINATA_JWT}`,
      },
      body: JSON.stringify({
        pinataMetadata: { name: `${basePinName}-metadata` },
        pinataOptions: { cidVersion: 1 },
        pinataContent: metadata,
      }),
    },
  );

  if (!metadataUploadResponse.ok) {
    const message = await readPinataError(metadataUploadResponse);
    return NextResponse.json(
      { error: `Failed to pin metadata to IPFS. ${message}` },
      { status: 502 },
    );
  }

  const metadataUploadJson =
    (await metadataUploadResponse.json()) as PinataJsonResponse;
  const metadataURI = `ipfs://${metadataUploadJson.IpfsHash}`;

  return NextResponse.json({
    baseURI: metadataURI,
    imageURI,
    metadataURI,
  });
}
