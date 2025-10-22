import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  transpilePackages: ["@workspace/ui", "@workspace/products-frontend"],
};

export default nextConfig;
