import type { NextConfig } from "next";
import path from "path";

const nextConfig: NextConfig = {
  transpilePackages: ["@workspace/ui", "@workspace/products-frontend"],
  output: "standalone",
  // Include files from the monorepo root for proper tracing
  outputFileTracingRoot: path.join(__dirname, "../../../"),
};

export default nextConfig;
