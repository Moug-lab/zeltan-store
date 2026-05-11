const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {

  // Get Authorization header
  const authHeader = req.header('Authorization');

  // Check if token exists
  if (!authHeader) {
    return res.status(401).json({
      message: 'No token provided'
    });
  }

  try {

    // Expected format:
    // Authorization: Bearer TOKEN

    const token = authHeader.split(' ')[1];

    // Verify token
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET
    );

    // Store user info inside request
    req.user = decoded;

    // Continue to next step
    next();

  } catch (error) {

    return res.status(401).json({
      message: 'Invalid token'
    });

  }
};

module.exports = authMiddleware;