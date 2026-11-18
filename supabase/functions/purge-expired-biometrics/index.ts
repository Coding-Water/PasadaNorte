// Supabase Edge Function: purge-expired-biometrics
// Scheduled or manually invoked to enforce RA 10173 / NPC Circular No. 2023-03
// 72-hour raw-image staging purge via Supabase Storage API + database retention RPC.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const STAGING_BUCKETS = ['biometric-vault', 'id-documents'];
const MAX_STAGING_AGE_MS = 72 * 60 * 60 * 1000;

Deno.serve(async (req) => {
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

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const cutoff = new Date(Date.now() - MAX_STAGING_AGE_MS);
  const removedByBucket: Record<string, number> = {};

  for (const bucket of STAGING_BUCKETS) {
    let removedCount = 0;
    const { data: folders } = await supabase.storage.from(bucket).list('', { limit: 1000 });
    for (const item of folders ?? []) {
      if (item.id === null) {
        // Folder: list objects inside user folder
        const { data: files } = await supabase.storage.from(bucket).list(item.name, { limit: 1000 });
        const expiredPaths = (files ?? [])
          .filter((f) => f.created_at && new Date(f.created_at) < cutoff)
          .map((f) => `${item.name}/${f.name}`);
        if (expiredPaths.length > 0) {
          await supabase.storage.from(bucket).remove(expiredPaths);
          removedCount += expiredPaths.length;
        }
      } else if (item.created_at && new Date(item.created_at) < cutoff) {
        await supabase.storage.from(bucket).remove([item.name]);
        removedCount += 1;
      }
    }
    removedByBucket[bucket] = removedCount;
  }

  const { data: rpcResult, error: rpcError } = await supabase.rpc('purge_expired_biometric_data');

  return new Response(
    JSON.stringify({
      ok: !rpcError,
      cutoff_72h_iso: cutoff.toISOString(),
      storage_removed: removedByBucket,
      database_retention: rpcResult ?? null,
      rpc_error: rpcError?.message ?? null,
    }),
    {
      status: rpcError ? 500 : 200,
      headers: { 'Content-Type': 'application/json' },
    },
  );
});
