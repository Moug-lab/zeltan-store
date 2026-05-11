const { MongoClient, ServerApiVersion } = require('mongodb');

const uri = "mongodb+srv://zeltan-store1.yb0zerd.mongodb.net/zeltanDB?authSource=%24external&authMechanism=MONGODB-AWS";

const client = new MongoClient(uri, {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true,
  }
});

async function run() {
  try {
    await client.connect();
    await client.db("admin").command({ ping: 1 });
    console.log("✅ IAM MongoDB connection SUCCESS");
  } catch (err) {
    console.error("❌ IAM MongoDB FAILED:");
    console.error(err);
  } finally {
    await client.close();
  }
}

run();