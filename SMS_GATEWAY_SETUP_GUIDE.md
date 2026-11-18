# PasadaNorte Full SMS Gateway Setup Guide (`capcom6/android-sms-gateway` + TNT SIM)

This is the complete step-by-step guide to enabling live SMS notifications in **PasadaNorte** (`web_client` MINC Admin Portal) using **[capcom6/android-sms-gateway](https://github.com/capcom6/android-sms-gateway)** on an Android phone with a **TNT SIM + Unli All-Net Text promo** — with **no third-party commercial SMS provider**.

> **Security Rule:** Never put your Android SMS Gateway username or password inside Flutter (`web_client` or `mobile_client`). All SMS requests must go from `web_client` → **Supabase Edge Function (`send-sms-notice`)** → **Android SMS Gateway**.

---

## Step 1: Prepare the Gateway Phone & TNT SIM

1. Insert your **TNT SIM** into an Android phone (Android 8.0+ recommended) that can stay powered on and connected to Wi-Fi or mobile data.
2. Load an active **Unli All-Net Text** promo and keep at least **₱5–₱10 regular load** as a backup buffer.
3. If the phone is **Dual-SIM**:
   - Go to **Settings → Network & internet / SIM cards → SMS preference** and set **TNT** as the default SIM for SMS (note whether it is **SIM 1** or **SIM 2**).
4. Make sure the phone can send a normal text message manually to another Globe/Smart/DITO number before continuing.

---

## Step 2: Install & Configure `SMS Gateway for Android`

1. On the gateway phone, download and install the latest APK from:
   `https://github.com/capcom6/android-sms-gateway/releases`
2. Open **SMS Gateway** and grant all requested permissions:
   - **Send / View SMS** (required)
   - **Notifications** (keeps foreground service alive)
3. **Disable Battery Optimization (Critical):**
   - Go to **Settings → Apps → SMS Gateway → Battery → Unrestricted** (or disable Battery Optimization / Autostart restrictions on Xiaomi, OPPO, Vivo, Realme, or Samsung).
   - Otherwise Android will sleep the app and Cloud Server messages will delay or time out.
4. On the app home screen:
   - Turn ON **Cloud Server** *(recommended so Supabase Cloud can reach the phone from anywhere without router port-forwarding)*.
   - Copy the **Username** and **Password** displayed under **Cloud Server**.
   - Cloud endpoint URL:
     ```text
     https://api.sms-gate.app/3rdparty/v1/messages
     ```
   *(Optional LAN-only mode: **Local Server** uses `http://<PHONE_LOCAL_IP>:8080/message`, which only works if your backend runs on the same local Wi-Fi network.)*

---

## Step 3: Verify the Gateway Phone Directly (Before Touching Supabase)

Run a quick test from your PC terminal (PowerShell) to confirm the TNT SIM sends an SMS:

```powershell
$pair = "YOUR_APP_USERNAME:YOUR_APP_PASSWORD"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

Invoke-RestMethod -Method Post `
  -Uri "https://api.sms-gate.app/3rdparty/v1/messages" `
  -Headers @{ Authorization = "Basic $b64"; "Content-Type" = "application/json" } `
  -Body '{"textMessage":{"text":"PasadaNorte TNT Gateway Test"},"phoneNumbers":["+639XXXXXXXXX"]}'
```

Replace `+639XXXXXXXXX` with your own test mobile number. You should receive the SMS within **5–15 seconds**.

---

## Step 4: Store Gateway Credentials in Supabase Secrets

From your workspace root (`c:\Users\MSI\Desktop\Flutter\PasadaNorte`):

1. Log in and link your Supabase project (if not already linked):
   ```bash
   supabase login
   supabase link --project-ref YOUR_SUPABASE_PROJECT_REF
   ```
2. Set the server-side secrets:
   ```bash
   supabase secrets set SMS_GATEWAY_URL="https://api.sms-gate.app/3rdparty/v1/messages"
   supabase secrets set SMS_GATEWAY_USERNAME="YOUR_APP_USERNAME"
   supabase secrets set SMS_GATEWAY_PASSWORD="YOUR_APP_PASSWORD"
   # Optional: set to 1 or 2 if using a Dual-SIM phone
   supabase secrets set SMS_SIM_NUMBER="1"
   ```

---

## Step 5: Create & Deploy the `send-sms-notice` Edge Function

Create `supabase/functions/send-sms-notice/index.ts` with CORS support (required for Flutter Web `web_client`), `minc_admin` role verification, and PH number normalization:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function normalizePhPhone(raw: string): string {
  const clean = raw.replace(/[\s\-()]/g, '');
  if (clean.startsWith('09') && clean.length === 11) return `+63${clean.slice(1)}`;
  if (clean.startsWith('9') && clean.length === 10) return `+63${clean}`;
  if (clean.startsWith('639') && clean.length === 12) return `+${clean}`;
  return clean;
}

Deno.serve(async (req) => {
  // Handle browser CORS preflight from web_client
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 1. Verify authenticated MINC Admin JWT
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user || user.app_metadata?.role !== 'minc_admin') {
    return new Response(JSON.stringify({ error: 'Forbidden: minc_admin required' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 2. Parse & validate request body
  const { phone_number, message } = await req.json();
  if (!phone_number || !message) {
    return new Response(JSON.stringify({ error: 'phone_number and message are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const normalizedPhone = normalizePhPhone(String(phone_number));

  // 3. Dispatch via capcom6/android-sms-gateway
  const gatewayUrl =
    Deno.env.get('SMS_GATEWAY_URL') ?? 'https://api.sms-gate.app/3rdparty/v1/messages';
  const username = Deno.env.get('SMS_GATEWAY_USERNAME') ?? '';
  const password = Deno.env.get('SMS_GATEWAY_PASSWORD') ?? '';
  const simNumberRaw = Deno.env.get('SMS_SIM_NUMBER');
  const basicAuth = btoa(`${username}:${password}`);

  const payload: Record<string, unknown> = {
    textMessage: { text: String(message) },
    phoneNumbers: [normalizedPhone],
  };
  if (simNumberRaw && !Number.isNaN(Number(simNumberRaw))) {
    payload.simNumber = Number(simNumberRaw);
  }

  const smsResp = await fetch(gatewayUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${basicAuth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const respText = await smsResp.text();
  return new Response(
    JSON.stringify({
      ok: smsResp.ok,
      recipient: normalizedPhone,
      gateway_status: smsResp.status,
      gateway_response: respText,
    }),
    {
      status: smsResp.ok ? 200 : 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    },
  );
});
```

Deploy the Edge Function:

```bash
supabase functions deploy send-sms-notice
```

---

## Step 6: Connect `web_client` to `send-sms-notice`

In [web_client/lib/main.dart](file:///c:/Users/MSI/Desktop/Flutter/PasadaNorte/web_client/lib/main.dart), inside `_sendRenewalSmsAndAppNotification(...)` (right after or alongside the existing Supabase Realtime `document_renewal_notice` broadcast), add:

```dart
try {
  await Supabase.instance.client.functions.invoke(
    'send-sms-notice',
    body: {
      'phone_number': driver['phone'],
      'message': smsMessage,
    },
  );
} catch (e) {
  debugPrint('Android SMS Gateway dispatch failed: $e');
}
```

*(Optional)* You can invoke the exact same `send-sms-notice` function when MINC Admin approves, requests resubmission, or rejects a driver/passenger application.

---

## Step 7: End-to-End Verification Checklist

1. **Security Check:** Send an unauthenticated `POST` to `https://<PROJECT_REF>.supabase.co/functions/v1/send-sms-notice` — confirm it returns `403 Forbidden`.
2. **Admin Portal Test:**
   - Sign in to `web_client` as a `minc_admin` account (`app_metadata.role == 'minc_admin'`).
   - Open **Directory & Drivers**, pick a driver with a real `+639XXXXXXXXX` test number, and trigger **Notify** / **Resend Notif**.
   - Confirm:
     - The SMS arrives via your **TNT SIM** within ~5–15 seconds.
     - The driver's `mobile_client` receives the Realtime + Notification Center alert and tapping it routes to the **Account** tab.
3. **Logs:** Check Edge Function execution logs anytime with:
   ```bash
   supabase functions logs send-sms-notice
   ```

---

## Troubleshooting & TNT SIM Best Practices

- **Messages stuck in "Pending":** Check that **Cloud Server** is ON in the Android app, the phone has active internet, and Battery Optimization is set to **Unrestricted**.
- **SMS fails to send on Dual-SIM:** Verify `SMS_SIM_NUMBER` (`1` or `2`) matches your TNT SIM slot, and keep ₱5–₱10 regular load alongside your Unli All-Net Text promo.
- **Avoid telco anti-spam blocks:** Do not blast dozens of identical SMS within a few seconds; normal per-driver admin notifications (spaced a few seconds apart) work reliably on TNT.
- **CORS error in browser console:** Ensure the `OPTIONS` preflight handler and `corsHeaders` from Step 5 are included and re-deployed.
