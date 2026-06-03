import dotenv from 'dotenv';
import { app } from './app';

dotenv.config();

const port = Number.parseInt(process.env.BACKEND_PORT ?? '3000', 10);

app.listen(port, () => {
  console.log(`E-VIDENTE backend listening on port ${port}`);
});
