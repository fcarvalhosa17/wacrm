// ponytail: one-shot migration runner. Delete after use.
import postgres from 'postgres'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

// load DATABASE_URL from .env (no dotenv dep)
const env = readFileSync(join(root, '.env'), 'utf8')
const m = env.match(/^DATABASE_URL=(.+)$/m)
if (!m) throw new Error('DATABASE_URL not in .env')
let url = m[1].trim().replace(/^["']|["']$/g, '')

// direct host is IPv6-only (no route here) → use IPv4 pooler. Find region by probing.
const ref = 'duqmcliomzoznkicboli'
const pw = decodeURIComponent(url.match(/:([^:@]+)@/)?.[1] ?? '')
if (!pw || pw === '[YOUR-PASSWORD]') throw new Error('password missing/placeholder in DATABASE_URL')

// region resolved by probe: us-west-2, aws-1 pooler prefix
const HOST = 'aws-1-us-west-2.pooler.supabase.com'

const mode = process.argv[2] // 'test' | 'run'
const sql = postgres({ host: HOST, port: 6543, user: `postgres.${ref}`, password: pw, database: 'postgres', max: 1, prepare: false, connect_timeout: 15, ssl: 'require' })
{
  const [{ v }] = await sql`select version() as v`
  console.log('CONNECTED:', v.split(',')[0])
}

try {
  if (mode !== 'run') { await sql.end(); process.exit(0) }

  const dir = join(root, 'supabase', 'migrations')
  const files = readdirSync(dir).filter(f => f.endsWith('.sql')).sort()
  for (const f of files) {
    const ddl = readFileSync(join(dir, f), 'utf8')
    process.stdout.write(`→ ${f} ... `)
    await sql.begin(async tx => { await tx.unsafe(ddl) })
    console.log('ok')
  }
  console.log(`\nDONE: ${files.length} migrations applied.`)
} catch (e) {
  console.error('\nFAIL:', e.message)
  process.exitCode = 1
} finally {
  await sql.end()
}
