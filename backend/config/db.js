const { MongoClient } = require('mongodb');

const uri = process.env.MONGO_URI;

let client;
let db;

const connectDB = async () => {
  console.log("MONGO_URI:", process.env.MONGO_URI); 
  try {
    client = new MongoClient(uri, {
      authMechanism: 'MONGODB-AWS',
    });

    await client.connect();

    db = client.db("zeltanDB");

    console.log("✅ MongoDB Connected (IAM)");

  } catch (error) {
    console.error("❌ MongoDB connection error:", error);
    process.exit(1);
  }
};

// Export DB getter
const getDB = () => db;

module.exports = { connectDB, getDB };