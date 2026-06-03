import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { pool } from '../src/config/database';
import { authConfig } from '../src/config/auth';

dotenv.config();

interface DemoUser {
  username: string;
  name: string;
  mail: string;
  password: string;
  age: number;
}

const DEMO_USERS: DemoUser[] = [
  {
    username: 'margo',
    name: 'Margo',
    mail: 'margo@test.com',
    password: '123',
    age: 0,
  },
  {
    username: 'agus',
    name: 'Agus',
    mail: 'agus@test.com',
    password: '123',
    age: 0,
  },
];

async function seedUser(user: DemoUser): Promise<void> {
  const passwordHash = await bcrypt.hash(user.password, authConfig.bcryptSaltRounds);

  await pool.query(
    `
    INSERT INTO users (username, name, mail, password_hash, age)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (username)
    DO UPDATE SET
      name          = EXCLUDED.name,
      mail          = EXCLUDED.mail,
      password_hash = EXCLUDED.password_hash,
      updated_at    = now()
    `,
    [user.username, user.name, user.mail, passwordHash, user.age]
  );

  console.log(`Seeded user: ${user.username}`);
}

async function run(): Promise<void> {
  for (const user of DEMO_USERS) {
    await seedUser(user);
  }
  console.log('Dev users ready.');
}

run()
  .then(async () => {
    await pool.end();
  })
  .catch(async (error) => {
    console.error('Seed failed:', error);
    await pool.end();
    process.exit(1);
  });
