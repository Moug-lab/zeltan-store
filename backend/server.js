const express = require('express');
const connectDB = require('./config/db');
require('dotenv').config();

const app = express();

app.use(express.json());

connectDB();

const authRoutes = require('./routes/authRoutes');
app.use('/api/auth', authRoutes);

app.get("/", (req, res) => {
  res.send("Zeltan Store API Running");
});

app.listen(process.env.PORT, () => {
  console.log(`Server running on port ${process.env.PORT}`);
});
