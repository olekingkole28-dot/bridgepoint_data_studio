import { createClient } from 'npm:@supabase/supabase-js@2'

const EXPECTED_SHA = '8870d7a447077150708e1b21b7aeaedb97f3bec4c9a8fd499dc479dcc4e43bc2'
const SOURCE_SHA = 'c296b719d10aaca6e2772d4dabca46bbd11f1501'
const BUCKET = 'bridgepoint-release-handoff'
const OBJECT_PATH = `clean-v2-${SOURCE_SHA}.tar.gz`

function toHex(buffer: ArrayBuffer) {
  return Array.from(new Uint8Array(buffer)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('method not allowed', { status: 405 })
    const bytes = new Uint8Array(await req.arrayBuffer())
    if (bytes.byteLength < 100000 || bytes.byteLength > 5000000) {
      return Response.json({ ok: false, error: 'unexpected archive size' }, { status: 400 })
    }
    const actual = toHex(await crypto.subtle.digest('SHA-256', bytes))
    if (actual !== EXPECTED_SHA) {
      return Response.json({ ok: false, error: 'archive sha mismatch', actual }, { status: 400 })
    }

    const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}')
    const secret = secretKeys['default']
    if (!secret) throw new Error('default Supabase secret key unavailable')
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, secret)
    const { error } = await admin.storage.from(BUCKET).upload(OBJECT_PATH, bytes, {
      contentType: 'application/gzip',
      cacheControl: '60',
      upsert: true,
    })
    if (error) throw error
    const { data } = admin.storage.from(BUCKET).getPublicUrl(OBJECT_PATH)
    return Response.json({ ok: true, source_sha: SOURCE_SHA, archive_sha256: actual, bytes: bytes.byteLength, url: data.publicUrl })
  } catch (error) {
    return Response.json({ ok: false, error: error instanceof Error ? error.message : String(error) }, { status: 500 })
  }
})
