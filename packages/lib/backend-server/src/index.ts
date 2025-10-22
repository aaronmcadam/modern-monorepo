import Fastify, {
  FastifyServerOptions,
  FastifyRequest,
  FastifyReply,
} from "fastify";
import cors from "@fastify/cors";

export async function createServer(options: FastifyServerOptions = {}) {
  const fastify = Fastify({
    logger: true,
    ...options,
  });

  // Enable CORS for local development
  await fastify.register(cors, {
    origin: true, // Allow all origins in development
  });

  // Add common hooks
  fastify.addHook(
    "onRequest",
    async (request: FastifyRequest, _reply: FastifyReply) => {
      request.log.info({ url: request.url }, "incoming request");
    },
  );

  return fastify;
}
