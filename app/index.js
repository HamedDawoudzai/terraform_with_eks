const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.get("/hello", (req, res) => {
  res.json({ message: "hello world from Hamed's EKS cluster!" });
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy" });
});

app.listen(PORT, () => {
  console.log(`Hamed's API is live on port ${PORT}`);
});
