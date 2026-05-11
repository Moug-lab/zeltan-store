const { getDB } = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Register user
exports.register = async (req, res) => {
  try {
    const db = getDB();

    const { name, email, password } = req.body;

    const existingUser = await db.collection('users').findOne({ email });

    if (existingUser) {
      return res.status(400).json({ message: "User already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = {
      name,
      email,
      password: hashedPassword,
    };

    const result = await db.collection('users').insertOne(newUser);

    const token = jwt.sign(
      { userId: result.insertedId },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(201).json({
      message: "User registered successfully",
      token,
      user: {
        id: result.insertedId,
        name,
        email,
      },
    });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};