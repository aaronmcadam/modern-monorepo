import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Monorepo Demo",
  description: "Demo integration for monorepo framework",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
