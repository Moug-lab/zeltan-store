require('dotenv').config();
const express = require('express');
const { connectDB } = require('./config/db');

const app = express();

app.use(express.json());

// Connect to DB
connectDB();

// Routes
const authRoutes = require('./routes/authRoutes');
const protectedRoutes = require('./routes/protectedRoutes');
const productRoutes = require('./routes/productRoutes');
app.use('/api/auth', authRoutes);
app.use('/api/protected', protectedRoutes);
app.use('/api/products', productRoutes);

// Test route
app.get("/", (req, res) => {
  res.send("Zeltan Store API Running");
});

// Start server
app.listen(process.env.PORT, () => {
  console.log(`Server running on port ${process.env.PORT}`);
});