// @ts-nocheck -- Deno Edge Function (uses esm.sh URL imports & Deno global)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  corsHeaders,
  dispatchSmsViaGateway,
  jsonResponse,
  normalizePhPhone,
  sha256Hex,
} from '../_shared/sms_gate.ts';

function generateSixDigitOtp(): string {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String(bytes[0] % 1_000_000).padStart(6, '0');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  let body: { phone_number?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const normalizedPhone = normalizePhPhone(String(body.phone_number ?? '').trim());
  if (!/^\+639\d{9}$/.test(normalizedPhone)) {
    return jsonResponse(
      { error: 'Valid Philippine mobile number (+639XXXXXXXXX) is required' },
      400,
    );
  }

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  // Rate limit: 45 seconds between OTP sends per phone number
  const { data: recent } = await adminClient
    .from('sms_otp_codes')
    .select('created_at')
    .eq('phone_number', normalizedPhone)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (recent?.created_at) {
    const elapsedMs = Date.now() - new Date(recent.created_at).getTime();
    if (elapsedMs < 45_000) {
      const waitSec = Math.ceil((45_000 - elapsedMs) / 1000);
      return jsonResponse(
        { error: `Please wait ${waitSec}s before requesting another OTP.` },
        429,
      );
    }
  }

  const code = generateSixDigitOtp();
  const codeHash = await sha256Hex(`${normalizedPhone}:${code}`);
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

  const { data: insertedRow, error: insertError } = await adminClient
    .from('sms_otp_codes')
    .insert({
      phone_number: normalizedPhone,
      code_hash: codeHash,
      expires_at: expiresAt,
    })
    .select('id')
    .single();

  if (insertError) {
    return jsonResponse({ error: `Failed to store OTP: ${insertError.message}` }, 500);
  }

  try {
    const smsText =
      `PasadaNorte OTP: ${code}. Valid for 5 minutes. Never share this code with anyone.`;
    const result = await dispatchSmsViaGateway(normalizedPhone, smsText, 100);
    if (!result.ok && insertedRow?.id) {
      await adminClient.from('sms_otp_codes').delete().eq('id', insertedRow.id);
    }
    return jsonResponse(
      {
        ok: result.ok,
        recipient: result.recipient,
        expires_at: expiresAt,
        gateway_status: result.status,
      },
      result.ok ? 200 : 502,
    );
  } catch (err) {
    if (insertedRow?.id) {
      await adminClient.from('sms_otp_codes').delete().eq('id', insertedRow.id);
    }
    return jsonResponse({ error: String(err) }, 500);
  }
});
