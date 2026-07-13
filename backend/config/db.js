const { MongoClient } = require("mongodb");

const uri = process.env.MONGO_URI;

let client;
let db;

const connectDB = async () => {
  console.log("MONGO_URI:", process.env.MONGO_URI);

  try {
    client = new MongoClient(uri, {
      authMechanism: "MONGODB-AWS",
    });

    await client.connect();

    db = client.db("zeltanDB");

    console.log("✅ MongoDB Connected (IAM)");

  } catch (error) {

    console.error("❌ MongoDB connection error:", error.message);

    console.log("⚠️ Application will continue running without database connection.");

    // Do NOT exit the application.
    // Kubernetes can still scrape metrics and
    // the database connection can be retried later.
  }
};

const getDB = () => db;

module.exports = {
  connectDB,
  getDB,
};