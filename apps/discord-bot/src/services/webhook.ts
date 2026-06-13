import { createServer } from 'http';
import { createHmac, timingSafeEqual } from 'crypto';
import { config } from '../config.js';

/**
 * Starts an HTTP server that listens for GitHub release webhooks
 * and posts announcements to a configured Discord channel.
 *
 * No-ops if WEBHOOK_SECRET or RELEASE_CHANNEL are not configured.
 */
export function startWebhookServer(client) {
  if (!config.webhookSecret || !config.releaseChannel) {
    console.log('Webhook server disabled (WEBHOOK_SECRET or RELEASE_CHANNEL not set)');
    return;
  }

  const server = createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== '/webhook/github') {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    // Collect body
    const chunks: Buffer[] = [];
    for await (const chunk of req) chunks.push(chunk);
    const body = Buffer.concat(chunks);

    // The server only starts when webhookSecret is set (see guard above), but TS
    // can't narrow that across the request closure — re-check so the secret is a
    // definite string before handing it to createHmac.
    const secret = config.webhookSecret;
    if (!secret) {
      res.writeHead(500);
      res.end('Webhook secret not configured');
      return;
    }

    // Verify signature. Header values are string | string[]; signatures are a
    // single value, so reject the array form rather than guessing which to use.
    const signature = req.headers['x-hub-signature-256'];
    if (!signature || Array.isArray(signature)) {
      res.writeHead(401);
      res.end('Missing signature');
      return;
    }

    const expected =
      'sha256=' + createHmac('sha256', secret).update(body).digest('hex');

    if (!timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
      console.warn('Webhook signature verification failed');
      res.writeHead(401);
      res.end('Invalid signature');
      return;
    }

    // Only handle release events
    const event = req.headers['x-github-event'];
    if (event !== 'release') {
      res.writeHead(200);
      res.end('Ignored (not a release event)');
      return;
    }

    let payload;
    try {
      payload = JSON.parse(body.toString());
    } catch {
      res.writeHead(400);
      res.end('Invalid JSON');
      return;
    }

    if (payload.action !== 'published') {
      res.writeHead(200);
      res.end('Ignored (not a published release)');
      return;
    }

    // Find channel by ID
    const channel = client.channels.cache.get(config.releaseChannel);

    if (!channel) {
      console.error(`Release channel ID "${config.releaseChannel}" not found in cache`);
      res.writeHead(404);
      res.end('Channel not found');
      return;
    }

    // Build and send embed
    const release = payload.release;
    const releaseBody = release.body
      ? release.body.length > 2000
        ? release.body.slice(0, 2000) + '…'
        : release.body
      : '_No release notes._';

    try {
      await channel.send({
        embeds: [
          {
            title: `📦 ${release.name || release.tag_name}`,
            url: release.html_url,
            description: releaseBody,
            color: 0x5865f2,
            author: release.author
              ? {
                  name: release.author.login,
                  icon_url: release.author.avatar_url,
                  url: release.author.html_url,
                }
              : undefined,
            footer: { text: 'GitHub Release' },
            timestamp: release.published_at || new Date().toISOString(),
          },
        ],
      });

      console.log(`Posted release ${release.tag_name} to #${channel.name}`);
      res.writeHead(200);
      res.end('OK');
    } catch (err) {
      console.error('Failed to send release notification:', err);
      res.writeHead(500);
      res.end('Failed to send message');
    }
  });

  server.listen(config.webhookPort, () => {
    console.log(`Webhook server listening on port ${config.webhookPort}`);
  });

  return server;
}
