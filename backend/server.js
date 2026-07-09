require('dotenv').config();
const express = require('express');
const helmet  = require('helmet');
const rateLimit = require('express-rate-limit');
const cors    = require('cors');
const { connectDB } = require('./config/db');

const app = express();
// Trust the NGINX Ingress Controller
app.set("trust proxy", 1);
// ─────────────────────────────────────────────
// 1. SECURITY HEADERS
// ─────────────────────────────────────────────
app.use(helmet());

// ─────────────────────────────────────────────
// 2. CORS
// ─────────────────────────────────────────────
app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);

// ─────────────────────────────────────────────
// 3. RATE LIMITING
// ─────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { status: 'error', message: 'Too many requests, please try again later.' },
});
app.use(limiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { status: 'error', message: 'Too many login attempts, please try again later.' },
});
app.use('/api/auth', authLimiter);

// ─────────────────────────────────────────────
// 4. BODY PARSING — 10kb limit prevents DoS
// ─────────────────────────────────────────────
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// ─────────────────────────────────────────────
// 5. CUSTOM SANITIZERS — body only, no req.query
//    touching — avoids the read-only getter crash
// ─────────────────────────────────────────────

// 5a. NoSQL injection — strip keys starting with $ or containing .
app.use((req, res, next) => {
  if (req.body) {
    const sanitizeNoSQL = (obj) => {
      Object.keys(obj).forEach((key) => {
        if (key.startsWith('$') || key.includes('.')) {
          delete obj[key];
        } else if (typeof obj[key] === 'object' && obj[key] !== null) {
          sanitizeNoSQL(obj[key]);
        }
      });
    };
    sanitizeNoSQL(req.body);
  }
  next();
});

// 5b. XSS — strip HTML tags from all string values in body
app.use((req, res, next) => {
  if (req.body) {
    const sanitizeXSS = (obj) => {
      Object.keys(obj).forEach((key) => {
        if (typeof obj[key] === 'string') {
          obj[key] = obj[key]
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#x27;')
            .replace(/\//g, '&#x2F;');
        } else if (typeof obj[key] === 'object' && obj[key] !== null) {
          sanitizeXSS(obj[key]);
        }
      });
    };
    sanitizeXSS(req.body);
  }
  next();
});

// ─────────────────────────────────────────────
// 6. DATABASE CONNECTION
// ─────────────────────────────────────────────
connectDB();

// ─────────────────────────────────────────────
// 7. ROUTES
// ─────────────────────────────────────────────
const authRoutes      = require('./routes/authRoutes');
const protectedRoutes = require('./routes/protectedRoutes');
const productRoutes   = require('./routes/productRoutes');

app.use('/api/auth',      authRoutes);
app.use('/api/protected', protectedRoutes);
app.use('/api/products',  productRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'Zeltan Store API Running' });
});

// ─────────────────────────────────────────────
// 8. 404 HANDLER
// ─────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ status: 'error', message: `Route ${req.originalUrl} not found` });
});

// ─────────────────────────────────────────────
// 9. GLOBAL ERROR HANDLER
// ─────────────────────────────────────────────
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal server error'
    : err.message;
  console.error(`[${new Date().toISOString()}] ${err.stack}`);
  res.status(statusCode).json({ status: 'error', message });
});

// ─────────────────────────────────────────────
// 10. START SERVER
// ─────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
});