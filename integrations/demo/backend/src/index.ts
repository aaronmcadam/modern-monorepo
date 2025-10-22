import { createServer } from "@workspace/backend-server";
import { productRoutes } from "@workspace/products-backend";

async function start() {
  const server = await createServer();

  // Register routes
  await server.register(productRoutes);

  // Start server
  try {
    await server.listen({ port: 4000, host: "0.0.0.0" });
    console.log("Server listening on http://localhost:4000");
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
}

start();
