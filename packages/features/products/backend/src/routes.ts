import { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import {
  getProducts,
  getProductById,
  getProductBySlug,
  ProductResponse,
} from "./data";
import { slugify } from "@workspace/backend-utils";

export async function productRoutes(fastify: FastifyInstance) {
  fastify.get(
    "/products",
    async (_request: FastifyRequest, _reply: FastifyReply) => {
      const products: ProductResponse[] = getProducts().map((product) => ({
        ...product,
        slug: slugify(product.name),
      }));
      return { products };
    },
  );

  fastify.get<{ Params: { id: string } }>(
    "/products/:id",
    async (
      request: FastifyRequest<{ Params: { id: string } }>,
      reply: FastifyReply,
    ) => {
      const { id } = request.params;
      const product = getProductById(parseInt(id, 10));

      if (!product) {
        reply.code(404);
        return { error: "Product not found" };
      }

      const productResponse: ProductResponse = {
        ...product,
        slug: slugify(product.name),
      };

      return { product: productResponse };
    },
  );

  fastify.get<{ Params: { slug: string } }>(
    "/products/by-slug/:slug",
    async (
      request: FastifyRequest<{ Params: { slug: string } }>,
      reply: FastifyReply,
    ) => {
      const { slug } = request.params;
      const product = getProductBySlug(slug);

      if (!product) {
        reply.code(404);
        return { error: "Product not found" };
      }

      const productResponse: ProductResponse = {
        ...product,
        slug: slugify(product.name),
      };

      return { product: productResponse };
    },
  );
}
