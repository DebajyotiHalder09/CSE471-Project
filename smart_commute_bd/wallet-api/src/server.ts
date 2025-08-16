import "dotenv/config";
import app from "./app";
import { connectMongo } from "./utils/mongo";

const PORT = process.env.PORT || 1281;

(async () => {
  await connectMongo(process.env.MONGO_URI!);
  app.listen(PORT, () => console.log(`✅ API running on http://localhost:${PORT}`));
})();




