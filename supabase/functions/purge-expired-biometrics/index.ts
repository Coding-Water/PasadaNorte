// Supabase Edge Function: purge-expired-biometrics
// Scheduled or manually invoked to enforce RA 10173 / NPC Circular No. 2023-03
// 72-hour raw-image staging purge via Supabase Storage REST API + database retention RPC.

declare const Deno: {
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  env: {
    get: (key: string) => string | undefined;
  };
};

interface StorageObjectItem {
  id: string | null;
  name: string;
  created_at?: string | null;
}

const STAGING_BUCKETS = ['biometric-vault', 'id-documents'];
const MAX_STAGING_AGE_MS = 72 * 60 * 60 * 1000;

async function listBucketObjects(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  prefix: string,
): Promise<StorageObjectItem[]> {
  const resp = await fetch(`${supabaseUrl}/storage/v1/object/list/${bucket}`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefix, limit: 1000, offset: 0 }),
  });
  if (!resp.ok) return [];
  const data = (await resp.json()) as StorageObjectItem[];
  return Array.isArray(data) ? data : [];
}

async function removeBucketObjects(
  supabaseUrl: string,
  serviceRoleKey: string,
  bucket: string,
  prefixes: string[],
): Promise<void> {
  if (prefixes.length === 0) return;
  await fetch(`${supabaseUrl}/storage/v1/object/${bucket}`, {
    method: 'DELETE',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefixes }),
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const cutoff = new Date(Date.now() - MAX_STAGING_AGE_MS);
  const removedByBucket: Record<string, number> = {};

  for (const bucket of STAGING_BUCKETS) {
    let removedCount = 0;
    const folders = await listBucketObjects(supabaseUrl, serviceRoleKey, bucket, '');
    for (const item of folders) {
      if (item.id === null) {
        const files = await listBucketObjects(supabaseUrl, serviceRoleKey, bucket, item.name);
        const expiredPaths = files
          .filter((f: StorageObjectItem) => Boolean(f.created_at && new Date(f.created_at) < cutoff))
          .map((f: StorageObjectItem) => `${item.name}/${f.name}`);
        if (expiredPaths.length > 0) {
          await removeBucketObjects(supabaseUrl, serviceRoleKey, bucket, expiredPaths);
          removedCount += expiredPaths.length;
        }
      } else if (item.created_at && new Date(item.created_at) < cutoff) {
        await removeBucketObjects(supabaseUrl, serviceRoleKey, bucket, [item.name]);
        removedCount += 1;
      }
    }
    removedByBucket[bucket] = removedCount;
  }

  const rpcResp = await fetch(`${supabaseUrl}/rest/v1/rpc/purge_expired_biometric_data`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });

  const rpcResult = rpcResp.ok ? await rpcResp.json() : null;
  const rpcError = rpcResp.ok ? null : await rpcResp.text();

  return new Response(
    JSON.stringify({
      ok: rpcResp.ok,
      cutoff_72h_iso: cutoff.toISOString(),
      storage_removed: removedByBucket,
      database_retention: rpcResult,
      rpc_error: rpcError,
    }),
    {
      status: rpcResp.ok ? 200 : 500,
      headers: { 'Content-Type': 'application/json' },
    },
  );
});
