require("dotenv").config();

const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const rateLimit = require("express-rate-limit");

const { connectDB } = require("./config/db");
const {
  register,
  httpRequests,
} = require("./config/metrics");

const app = express();

// ======================================================
// TRUST PROXY (Kubernetes NGINX Ingress)
// ======================================================

app.set("trust proxy", 1);

// ======================================================
// SECURITY HEADERS
// ======================================================

app.use(helmet());

// ======================================================
// CORS
// ======================================================

app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

// ======================================================
// RATE LIMITERS
// ======================================================

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    status: "error",
    message: "Too many requests, please try again later.",
  },
});

app.use(limiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: {
    status: "error",
    message: "Too many login attempts, please try again later.",
  },
});

app.use("/api/auth", authLimiter);

// ======================================================
// BODY PARSING
// ======================================================

app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: true, limit: "10kb" }));

// ======================================================
// PROMETHEUS REQUEST METRICS
// ======================================================

app.use((req, res, next) => {

  res.on("finish", () => {

    httpRequests.inc({

      method: req.method,

      route: req.baseUrl + (req.route?.path || req.path),

      status: res.statusCode,

    });

  });

  next();

});

// ======================================================
// NoSQL SANITIZATION
// ======================================================

app.use((req, res, next) => {

  if (req.body) {

    const sanitizeNoSQL = (obj) => {

      Object.keys(obj).forEach((key) => {

        if (key.startsWith("$") || key.includes(".")) {

          delete obj[key];

        } else if (typeof obj[key] === "object" && obj[key] !== null) {

          sanitizeNoSQL(obj[key]);

        }

      });

    };

    sanitizeNoSQL(req.body);

  }

  next();

});

// ======================================================
// XSS SANITIZATION
// ======================================================

app.use((req, res, next) => {

  if (req.body) {

    const sanitizeXSS = (obj) => {

      Object.keys(obj).forEach((key) => {

        if (typeof obj[key] === "string") {

          obj[key] = obj[key]
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#x27;")
            .replace(/\//g, "&#x2F;");

        } else if (typeof obj[key] === "object" && obj[key] !== null) {

          sanitizeXSS(obj[key]);

        }

      });

    };

    sanitizeXSS(req.body);

  }

  next();

});

// ======================================================
// DATABASE
// ======================================================

connectDB();

// ======================================================
// ROUTES
// ======================================================

const authRoutes = require("./routes/authRoutes");
const protectedRoutes = require("./routes/protectedRoutes");
const productRoutes = require("./routes/productRoutes");

app.use("/api/auth", authRoutes);
app.use("/api/protected", protectedRoutes);
app.use("/api/products", productRoutes);

// ======================================================
// HEALTH CHECK
// ======================================================

app.get("/", (req, res) => {

  res.json({
    status: "ok",
    message: "Zeltan Store API Running",
  });

});

// ======================================================
// PROMETHEUS METRICS
// ======================================================

app.get("/metrics", async (req, res) => {

  res.set("Content-Type", register.contentType);

  res.end(await register.metrics());

});

// ======================================================
// 404 HANDLER
// ======================================================

app.use((req, res) => {

  res.status(404).json({
    status: "error",
    message: `Route ${req.originalUrl} not found`,
  });

});

// ======================================================
// GLOBAL ERROR HANDLER
// ======================================================

app.use((err, req, res, next) => {

  const statusCode = err.statusCode || 500;

  const message =
    process.env.NODE_ENV === "production"
      ? "Internal server error"
      : err.message;

  console.error(`[${new Date().toISOString()}] ${err.stack}`);

  res.status(statusCode).json({
    status: "error",
    message,
  });

});

// ======================================================
// START SERVER
// ======================================================

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {

  console.log(
    `Server running in ${process.env.NODE_ENV || "development"} mode on port ${PORT}`
  );

});