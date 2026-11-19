// @ts-nocheck -- Deno Edge Function (uses esm.sh URL imports & Deno global)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  checkSmsGatewayStatus,
  corsHeaders,
  jsonResponse,
} from '../_shared/sms_gate.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST' && req.method !== 'GET') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  const role =
    user?.app_metadata?.role ??
    user?.user_metadata?.role ??
    '';

  if (authError || !user || role !== 'minc_admin') {
    return jsonResponse({ error: 'Forbidden: minc_admin required' }, 403);
  }

  const result = await checkSmsGatewayStatus();
  return jsonResponse({
    ok: result.ok,
    active: result.active,
    device_count: result.deviceCount,
    online_device_count: result.onlineDeviceCount,
    last_seen: result.lastSeen,
    last_seen_age_seconds: result.lastSeenAgeSeconds,
    gateway_status: result.status,
  });
});
