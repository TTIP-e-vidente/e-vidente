import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const port = process.env.BACKEND_PORT ?? '3010';
const host = (process.env.BACKEND_HOST ?? 'localhost').trim();
const baseUrl = `http://${host}:${port}`;

const targetPath = path.resolve(__dirname, '../../juego/config/backend.local.json');

fs.mkdirSync(path.dirname(targetPath), { recursive: true });
fs.writeFileSync(targetPath, `${JSON.stringify({ base_url: baseUrl }, null, 2)}\n`, 'utf8');

console.log(`[sync] Godot backend URL → ${baseUrl} (${path.relative(process.cwd(), targetPath)})`);
