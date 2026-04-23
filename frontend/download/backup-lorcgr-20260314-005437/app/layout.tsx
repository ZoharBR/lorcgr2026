import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "LOR CGR - Centralized Network Management",
  description: "Sistema de gerenciamento centralizado de redes com Dashboard NOC, Terminal SSH multi-abas, Backups automáticos e Auditoria completa.",
  keywords: ["LOR CGR", "Network Management", "NOC", "SSH", "BRAS", "PPPoE", "LibreNMS", "PHPIPAM"],
  authors: [{ name: "LOR Vision" }],
  icons: {
    icon: "/logo.svg",
  },
  openGraph: {
    title: "LOR CGR - Network Management",
    description: "Centralized network management system",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR" suppressHydrationWarning className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
      >
        {children}
        <Toaster />
      </body>
    </html>
  );
}
