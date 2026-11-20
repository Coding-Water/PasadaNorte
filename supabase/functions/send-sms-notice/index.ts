// @ts-nocheck -- Deno Edge Function (uses esm.sh URL imports & Deno global)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  corsHeaders,
  dispatchSmsViaGateway,
  jsonResponse,
  normalizePhPhone,
} from '../_shared/sms_gate.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  // Verify authenticated MINC Admin JWT
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

  let body: { phone_number?: string; message?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const phoneNumber = normalizePhPhone(String(body.phone_number ?? '').trim());
  const message = String(body.message ?? '').trim();
  if (!/^\+639\d{9}$/.test(phoneNumber) || !message) {
    return jsonResponse(
      { error: 'Valid Philippine mobile number (+639XXXXXXXXX) and message are required' },
      400,
    );
  }

  try {
    const result = await dispatchSmsViaGateway(phoneNumber, message, 100);
    return jsonResponse(
      {
        ok: result.ok,
        recipient: result.recipient,
        gateway_status: result.status,
        gateway_response: result.body,
      },
      result.ok ? 200 : 502,
    );
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
