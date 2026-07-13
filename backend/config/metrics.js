const client = require("prom-client");

// Collect default Node.js metrics
client.collectDefaultMetrics();

// Registry
const register = client.register;

// HTTP Request Counter
const httpRequests = new client.Counter({
    name: "http_requests_total",
    help: "Total number of HTTP requests",
    labelNames: ["method", "route", "status"]
});

module.exports = {
    register,
    httpRequests
};