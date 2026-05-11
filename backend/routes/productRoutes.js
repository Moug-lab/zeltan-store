const express = require('express');

const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  createProduct,
  getProducts
} = require('../controllers/productController');

// Create product (protected)
router.post(
  '/',
  authMiddleware,
  createProduct
);

// Get all products (public)
router.get(
  '/',
  getProducts
);

module.exports = router;