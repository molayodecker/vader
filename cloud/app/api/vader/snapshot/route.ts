import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const base = process.env.PHOENIX_API_URL;
  const token = process.env.VADER_OPERATOR_TOKEN;
  if (!base || !token) {
    return NextResponse.json({ error: "backend_not_configured" }, { status: 503 });
  }
  try {
    const url = new URL("/api/v1/snapshot", base);
    if (!["https:", "http:"].includes(url.protocol)) throw new Error("invalid protocol");
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return NextResponse.json({ error: "backend_unavailable" }, { status: 503 });
    return NextResponse.json(await res.json(), { headers: { "Cache-Control": "no-store" } });
  } catch {
    return NextResponse.json({ error: "backend_unavailable" }, { status: 503 });
  }
}
