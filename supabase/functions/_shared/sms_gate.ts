export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function normalizePhPhone(raw: string): string {
  const clean = raw.replace(/[\s\-()]/g, '');
  if (clean.startsWith('09') && clean.length === 11) return `+63${clean.slice(1)}`;
  if (clean.startsWith('9') && clean.length === 10) return `+63${clean}`;
  if (clean.startsWith('639') && clean.length === 12) return `+${clean}`;
  return clean;
}

export async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export async function dispatchSmsViaGateway(
  phoneNumber: string,
  message: string,
): Promise<{ ok: boolean; status: number; body: string; recipient: string }> {
  const gatewayUrl =
    Deno.env.get('SMS_GATEWAY_URL') ?? 'https://api.sms-gate.app/3rdparty/v1/messages';
  const username = Deno.env.get('SMS_GATEWAY_USERNAME') ?? '';
  const password = Deno.env.get('SMS_GATEWAY_PASSWORD') ?? '';
  const simNumberRaw = Deno.env.get('SMS_SIM_NUMBER');

  if (!username || !password) {
    throw new Error('SMS_GATEWAY_USERNAME or SMS_GATEWAY_PASSWORD secret is not configured.');
  }

  const recipient = normalizePhPhone(phoneNumber);
  const basicAuth = btoa(`${username}:${password}`);

  const payload: Record<string, unknown> = {
    textMessage: { text: message },
    phoneNumbers: [recipient],
  };
  if (simNumberRaw && !Number.isNaN(Number(simNumberRaw))) {
    payload.simNumber = Number(simNumberRaw);
  }

  const smsResp = await fetch(gatewayUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basicAuth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const body = await smsResp.text();
  return {
    ok: smsResp.ok,
    status: smsResp.status,
    body,
    recipient,
  };
}

export async function checkSmsGatewayStatus(): Promise<{
  ok: boolean;
  active: boolean;
  deviceCount: number;
  status: number;
}> {
  const gatewayUrl =
    Deno.env.get('SMS_GATEWAY_URL') ?? 'https://api.sms-gate.app/3rdparty/v1/messages';
  const username = Deno.env.get('SMS_GATEWAY_USERNAME') ?? '';
  const password = Deno.env.get('SMS_GATEWAY_PASSWORD') ?? '';

  if (!username || !password) {
    return { ok: false, active: false, deviceCount: 0, status: 500 };
  }

  const devicesUrl = gatewayUrl.replace(/\/messages\/?$/, '/devices');
  const basicAuth = btoa(`${username}:${password}`);

  try {
    const resp = await fetch(devicesUrl, {
      method: 'GET',
      headers: { Authorization: `Basic ${basicAuth}` },
    });
    if (!resp.ok) {
      return { ok: false, active: false, deviceCount: 0, status: resp.status };
    }
    const data = await resp.json().catch(() => []);
    const devices = Array.isArray(data) ? data : [];
    return {
      ok: true,
      active: devices.length > 0,
      deviceCount: devices.length,
      status: resp.status,
    };
  } catch {
    return { ok: false, active: false, deviceCount: 0, status: 503 };
  }
}
