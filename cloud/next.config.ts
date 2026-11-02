import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Type safety is checked explicitly by `npm run typecheck` in CI.
  // The container's Next build runner cannot parse tsc --showConfig output.
  typescript: { ignoreBuildErrors: true },
};

export default nextConfig;
