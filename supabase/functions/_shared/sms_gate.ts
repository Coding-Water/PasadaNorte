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
  priority?: number,
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
  if (typeof priority === 'number') {
    payload.priority = priority;
  }
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
  onlineDeviceCount: number;
  lastSeen: string | null;
  lastSeenAgeSeconds: number | null;
  status: number;
}> {
  const gatewayUrl =
    Deno.env.get('SMS_GATEWAY_URL') ?? 'https://api.sms-gate.app/3rdparty/v1/messages';
  const username = Deno.env.get('SMS_GATEWAY_USERNAME') ?? '';
  const password = Deno.env.get('SMS_GATEWAY_PASSWORD') ?? '';
  const windowSecRaw = Number(Deno.env.get('SMS_GATE_ONLINE_WINDOW_SECONDS') ?? '300');
  const onlineWindowMs =
    Number.isFinite(windowSecRaw) && windowSecRaw > 0 ? windowSecRaw * 1000 : 5 * 60 * 1000;

  if (!username || !password) {
    return {
      ok: false,
      active: false,
      deviceCount: 0,
      onlineDeviceCount: 0,
      lastSeen: null,
      lastSeenAgeSeconds: null,
      status: 500,
    };
  }

  const devicesUrl = gatewayUrl.replace(/\/messages\/?$/, '/devices');
  const basicAuth = btoa(`${username}:${password}`);

  try {
    const resp = await fetch(devicesUrl, {
      method: 'GET',
      headers: { Authorization: `Basic ${basicAuth}` },
    });
    if (!resp.ok) {
      return {
        ok: false,
        active: false,
        deviceCount: 0,
        onlineDeviceCount: 0,
        lastSeen: null,
        lastSeenAgeSeconds: null,
        status: resp.status,
      };
    }
    const data = await resp.json().catch(() => []);
    const allDevices = Array.isArray(data) ? data : [];
    const devices = allDevices.filter((d) => !d?.deletedAt && !d?.deleted_at);
    const now = Date.now();
    let latestTs = 0;
    let latestIso: string | null = null;
    let onlineCount = 0;

    for (const d of devices) {
      const rawLastSeen = d?.lastSeen ?? d?.last_seen;
      if (rawLastSeen) {
        const ts = new Date(String(rawLastSeen)).getTime();
        if (!Number.isNaN(ts)) {
          if (ts > latestTs) {
            latestTs = ts;
            latestIso = String(rawLastSeen);
          }
          if (now - ts <= onlineWindowMs) {
            onlineCount++;
          }
        }
      }
    }

    const lastSeenAgeSeconds =
      latestTs > 0 ? Math.max(0, Math.round((now - latestTs) / 1000)) : null;

    return {
      ok: true,
      active: onlineCount > 0,
      deviceCount: devices.length,
      onlineDeviceCount: onlineCount,
      lastSeen: latestIso,
      lastSeenAgeSeconds,
      status: resp.status,
    };
  } catch {
    return {
      ok: false,
      active: false,
      deviceCount: 0,
      onlineDeviceCount: 0,
      lastSeen: null,
      lastSeenAgeSeconds: null,
      status: 503,
    };
  }
}
