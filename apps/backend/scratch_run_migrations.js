const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const config = {
  host: 'db.qjolinnxfovlliameork.supabase.co',
  port: 5432,
  user: 'postgres',
  password: 'Mridul@1706',
  database: 'postgres',
  ssl: { rejectUnauthorized: false }
};

const migrationsDir = 'c:\\Users\\HP\\OneDrive\\Desktop\\skipit 2.0\\infrastructure\\supabase\\migrations';

const migrationFiles = [
  '20240516000000_initial_schema.sql',
  '20260517000000_phase1_schema.sql',
  '20260517100000_production_schema.sql',
  '20260517200000_wishlist_schema.sql',
  '20260709000000_secure_profiles.sql'
];

async function main() {
  const client = new Client(config);
  await client.connect();
  console.log('Connected to Supabase Postgres database successfully.');

  // Reset database tables
  console.log('Resetting database schema to clean slate...');
  await client.query(`
    DROP VIEW IF EXISTS profiles_public CASCADE;
    DROP TABLE IF EXISTS audit_log CASCADE;
    DROP TABLE IF EXISTS notifications CASCADE;
    DROP TABLE IF EXISTS wishlist CASCADE;
    DROP TABLE IF EXISTS wishlists CASCADE;
    DROP TABLE IF EXISTS reports CASCADE;
    DROP TABLE IF EXISTS transactions CASCADE;
    DROP TABLE IF EXISTS messages CASCADE;
    DROP TABLE IF EXISTS reviews CASCADE;
    DROP TABLE IF EXISTS categories CASCADE;
    DROP TABLE IF EXISTS bookings CASCADE;
    DROP TABLE IF EXISTS listings CASCADE;
    DROP TABLE IF EXISTS profiles CASCADE;
  `);
  console.log('Tables dropped successfully.');

  // 1. Run migrations in order
  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    console.log(`\nExecuting migration: ${file}...`);
    const sql = fs.readFileSync(filePath, 'utf8');
    try {
      await client.query(sql);
      console.log(`Migration ${file} executed successfully.`);
    } catch (err) {
      console.error(`Error executing migration ${file}:`, err.message);
      // Don't stop unless it's a fatal parse error; some objects might exist
    }
  }

  // 2. Query policies on profiles table
  console.log('\n--- pg_policies for profiles ---');
  try {
    const res = await client.query(`
      SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'profiles';
    `);
    console.table(res.rows);
    console.log('Raw output:', JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error('Error fetching policies:', err.message);
  }

  // 3. Confirm profiles_public view existence
  console.log('\n--- information_schema.views for profiles_public ---');
  try {
    const res = await client.query(`
      SELECT table_name, view_definition 
      FROM information_schema.views 
      WHERE table_name = 'profiles_public';
    `);
    console.table(res.rows);
    console.log('Raw output:', JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error('Error checking view:', err.message);
  }

  await client.end();
}

main().catch(console.error);
