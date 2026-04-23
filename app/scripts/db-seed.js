const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '../.env.local');
let password = process.env.DB_PASSWORD ?? 'Password123321!';

if (fs.existsSync(envPath)) {
  const match = fs.readFileSync(envPath, 'utf8').match(/^DB_PASSWORD=(.+)$/m);
  if (match) password = match[1].trim();
}

const seedSql = path.join(__dirname, '../../database/seeds/mock_session.sql');
const cmd = `docker exec -i party-dj-sqlserver bash -c "/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '${password}' -C"`;

console.log('Seeding PartyDJ database...');
execSync(cmd, { input: fs.readFileSync(seedSql), stdio: ['pipe', 'inherit', 'inherit'] });
console.log('Done.');
