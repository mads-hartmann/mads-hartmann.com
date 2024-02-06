import express from "express";

const app = express();
const PORT = 3000;

app.use(express.static("_site"));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});
