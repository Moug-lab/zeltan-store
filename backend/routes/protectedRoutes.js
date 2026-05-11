const express = require('express');

const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

// Protected route
router.get('/dashboard', authMiddleware, (req, res) => {

  res.json({
    message: 'Protected route accessed successfully',
    user: req.user
  });

});

module.exports = router;