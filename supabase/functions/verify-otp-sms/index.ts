// @ts-nocheck -- Deno Edge Function (uses esm.sh URL imports & Deno global)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  corsHeaders,
  jsonResponse,
  normalizePhPhone,
  sha256Hex,
} from '../_shared/sms_gate.ts';

const MAX_ATTEMPTS = 10;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  let body: { phone_number?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const normalizedPhone = normalizePhPhone(String(body.phone_number ?? '').trim());
  const code = String(body.code ?? '').trim();

  if (!normalizedPhone || !/^\d{6}$/.test(code)) {
    return jsonResponse({ ok: false, error: 'Valid phone_number and 6-digit code are required' }, 400);
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  const { data: otpRow, error: fetchError } = await adminClient
    .from('sms_otp_codes')
    .select('id, code_hash, expires_at, attempts, verified_at')
    .eq('phone_number', normalizedPhone)
    .is('verified_at', null)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (fetchError || !otpRow) {
    return jsonResponse({ ok: false, error: 'No active OTP found. Please resend a new code.' }, 400);
  }

  if (new Date(otpRow.expires_at).getTime() < Date.now()) {
    return jsonResponse({ ok: false, error: 'OTP has expired. Please request a new code.' }, 400);
  }

  if (otpRow.attempts >= MAX_ATTEMPTS) {
    return jsonResponse({ ok: false, error: 'Too many failed attempts. Please request a new code.' }, 429);
  }

  const expectedHash = await sha256Hex(`${normalizedPhone}:${code}`);
  if (expectedHash !== otpRow.code_hash) {
    await adminClient
      .from('sms_otp_codes')
      .update({ attempts: otpRow.attempts + 1 })
      .eq('id', otpRow.id);
    return jsonResponse({ ok: false, error: 'Invalid OTP code. Please try again.' }, 400);
  }

  await adminClient
    .from('sms_otp_codes')
    .update({ verified_at: new Date().toISOString() })
    .eq('id', otpRow.id);

  return jsonResponse({ ok: true, verified: true, phone_number: normalizedPhone }, 200);
});
