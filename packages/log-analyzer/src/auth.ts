import { assertWclConfig, config } from './config.js';

let cachedToken = null;
let tokenExpiry = 0;

export async function getToken() {
  assertWclConfig();

  const now = Date.now();
  if (cachedToken && now < tokenExpiry) {
    return cachedToken;
  }

  const params = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: config.wcl.clientId,
    client_secret: config.wcl.clientSecret,
  } as Record<string, string>);

  const res = await fetch(config.wcl.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`WCL auth failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  cachedToken = data.access_token;
  // Expire 60s early to avoid edge cases
  tokenExpiry = now + (data.expires_in - 60) * 1000;

  return cachedToken;
}
