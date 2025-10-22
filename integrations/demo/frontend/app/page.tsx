"use client";

import Image from "next/image";
import { ProductCard } from "@workspace/products-frontend/components/product-card";
import { ProductTable } from "@workspace/products-frontend/components/product-table";
import { useProducts } from "@workspace/products-frontend/hooks/use-products";

export default function Home() {
  const { products, loading, error } = useProducts();

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
            <div className="text-lg text-gray-600">Loading products...</div>
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

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white flex flex-col">
        <header className="border-b bg-white/80 backdrop-blur-sm">
          <div className="container mx-auto px-4 py-6">
            <h1 className="text-3xl font-bold">Demo Store</h1>
          </div>
        </header>
        <main className="container mx-auto px-4 py-12 flex-1">
          <div className="rounded-lg border border-red-200 bg-red-50 p-4">
            <p className="text-red-800">Error: {error.message}</p>
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

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white flex flex-col">
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold">Demo Store</h1>
        </div>
      </header>
      <main className="container mx-auto px-4 py-12 flex-1 space-y-16">
        {/* Featured Products Section */}
        <section>
          <div className="mb-8">
            <h2 className="text-3xl font-bold mb-2">Featured Products</h2>
            <p className="text-gray-600">Check out our hand-picked selection</p>
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {products.slice(0, 3).map((product) => (
              <ProductCard
                key={product.id}
                name={product.name}
                price={product.price}
                inStock={product.inStock}
                slug={product.slug}
              />
            ))}
          </div>
        </section>

        {/* Products Table Section */}
        <section>
          <div className="mb-8">
            <h2 className="text-3xl font-bold mb-2">All Products</h2>
            <p className="text-gray-600">Browse our complete catalog</p>
          </div>
          <ProductTable
            products={products.map((p) => ({
              id: String(p.id),
              name: p.name,
              price: p.price,
              stock: p.inStock ? 10 : 0,
              slug: p.slug,
            }))}
          />
        </section>
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
