"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Image from "next/image";
import { Button } from "@workspace/ui/components/button";
import { Badge } from "@workspace/ui/components/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@workspace/ui/components/card";

interface Product {
  id: number;
  name: string;
  price: number;
  inStock: boolean;
  slug: string;
}

export default function ProductDetailPage() {
  const params = useParams();
  const router = useRouter();
  const slug = params.slug as string;

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetch(`http://localhost:4000/products/by-slug/${slug}`)
      .then((res) => {
        if (!res.ok) {
          throw new Error("Product not found");
        }
        return res.json();
      })
      .then((data) => {
        setProduct(data.product);
        setLoading(false);
      })
      .catch((err) => {
        setError(err);
        setLoading(false);
      });
  }, [slug]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white flex flex-col">
        <header className="border-b bg-white/80 backdrop-blur-sm">
          <div className="container mx-auto px-4 py-6">
            <h1 className="text-3xl font-bold">Demo Store</h1>
          </div>
        </header>
        <main className="container mx-auto px-4 py-12 flex-1">
          <div className="flex items-center justify-center">
            <div className="text-lg text-gray-600">Loading product...</div>
          </div>
        </main>
        <footer className="border-t bg-white/80 backdrop-blur-sm">
          <div className="container mx-auto px-4 py-6">
            <div className="flex items-center justify-center gap-2 text-sm text-gray-600">
              <span>Built with</span>
              <Image
                src="/next.svg"
                alt="Next.js"
                width={80}
                height={16}
                className="dark:invert"
              />
            </div>
          </div>
        </footer>
      </div>
    );
  }

  if (error || !product) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white flex flex-col">
        <header className="border-b bg-white/80 backdrop-blur-sm">
          <div className="container mx-auto px-4 py-6">
            <h1 className="text-3xl font-bold">Demo Store</h1>
          </div>
        </header>
        <main className="container mx-auto px-4 py-12 flex-1">
          <div className="rounded-lg border border-red-200 bg-red-50 p-4">
            <p className="text-red-800">
              Error: {error?.message || "Product not found"}
            </p>
            <Button
              variant="outline"
              className="mt-4"
              onClick={() => router.push("/")}
            >
              Back to Products
            </Button>
          </div>
        </main>
        <footer className="border-t bg-white/80 backdrop-blur-sm">
          <div className="container mx-auto px-4 py-6">
            <div className="flex items-center justify-center gap-2 text-sm text-gray-600">
              <span>Built with</span>
              <Image
                src="/next.svg"
                alt="Next.js"
                width={80}
                height={16}
                className="dark:invert"
              />
            </div>
          </div>
        </footer>
      </div>
    );
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(price / 100);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white flex flex-col">
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold">Demo Store</h1>
        </div>
      </header>
      <main className="container mx-auto px-4 py-12 flex-1">
        <Button
          variant="ghost"
          className="mb-6"
          onClick={() => router.push("/")}
        >
          ← Back to Products
        </Button>

        <div className="max-w-4xl mx-auto">
          <Card>
            <CardHeader>
              <CardTitle className="text-3xl">{product.name}</CardTitle>
              <CardDescription className="text-2xl font-semibold">
                {formatPrice(product.price)}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center gap-2">
                <Badge variant={product.inStock ? "secondary" : "outline"}>
                  {product.inStock ? "In Stock" : "Out of Stock"}
                </Badge>
              </div>

              <div className="border-t pt-4">
                <h3 className="font-semibold mb-2">Product Details</h3>
                <dl className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-gray-600">Product ID:</dt>
                    <dd className="font-medium">{product.id}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-gray-600">URL Slug:</dt>
                    <dd className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                      {product.slug}
                    </dd>
                  </div>
                </dl>
              </div>
            </CardContent>
            <CardFooter className="flex gap-4">
              <Button className="flex-1" disabled={!product.inStock}>
                Add to Cart
              </Button>
              <Button variant="outline" className="flex-1">
                ♡ Add to Wishlist
              </Button>
            </CardFooter>
          </Card>
        </div>
      </main>
      <footer className="border-t bg-white/80 backdrop-blur-sm mt-12">
        <div className="container mx-auto px-4 py-6">
          <div className="flex items-center justify-center gap-2 text-sm text-gray-600">
            <span>Built with</span>
            <Image
              src="/next.svg"
              alt="Next.js"
              width={80}
              height={16}
              className="dark:invert"
            />
          </div>
        </div>
      </footer>
    </div>
  );
}
