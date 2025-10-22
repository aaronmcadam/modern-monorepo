import { slugify } from "@workspace/backend-utils";
import productsData from "./products.json";

export type Product = {
  id: number;
  name: string;
  price: number;
  inStock: boolean;
};

export type ProductResponse = Product & {
  slug: string;
};

const products: Product[] = productsData;

export function getProducts(): Product[] {
  return products;
}

export function getProductById(id: number): Product | undefined {
  return products.find((p) => p.id === id);
}

export function getProductBySlug(slug: string): Product | undefined {
  return products.find((p) => slugify(p.name) === slug);
}
