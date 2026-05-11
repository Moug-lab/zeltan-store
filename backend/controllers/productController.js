const { getDB } = require('../config/db');

// CREATE PRODUCT
exports.createProduct = async (req, res) => {

  try {

    const db = getDB();

    const {
      name,
      description,
      price,
      category,
      stock,
      imageUrl
    } = req.body;

    // Basic validation
    if (!name || !price) {
      return res.status(400).json({
        message: 'Name and price are required'
      });
    }

    // Create product object
    const newProduct = {
      name,
      description,
      price,
      category,
      stock,
      imageUrl,
      createdAt: new Date()
    };

    // Insert into MongoDB
    const result = await db
      .collection('products')
      .insertOne(newProduct);

    res.status(201).json({
      message: 'Product created successfully',
      productId: result.insertedId,
      product: newProduct
    });

  } catch (error) {

    res.status(500).json({
      message: error.message
    });

  }

};

// GET ALL PRODUCTS
exports.getProducts = async (req, res) => {

  try {

    const db = getDB();

    const products = await db
      .collection('products')
      .find({})
      .toArray();

    res.status(200).json(products);

  } catch (error) {

    res.status(500).json({
      message: error.message
    });

  }

};