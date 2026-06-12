import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

const required = ['DISCORD_TOKEN', 'DISCORD_CLIENT_ID', 'ANTHROPIC_API_KEY'];
for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

export const config = {
  discordToken: process.env.DISCORD_TOKEN,
  clientId: process.env.DISCORD_CLIENT_ID,
  guildId: process.env.DISCORD_GUILD_ID || null,
  anthropicApiKey: process.env.ANTHROPIC_API_KEY,
  rotationRoot: path.resolve(__dirname, '..', '..', 'rotation'),
  maxRequestLength: 500,
  rateLimitMs: 60_000,
  claudeModel: 'claude-haiku-4-5-20251001',
  maxTurns: 15,
  webhookPort: parseInt(process.env.WEBHOOK_PORT, 10) || 3000,
  webhookSecret: process.env.WEBHOOK_SECRET || null,
  releaseChannel: process.env.RELEASE_CHANNEL || null,
  adminModel: 'claude-sonnet-4-20250514',
  maxAdminTurns: 50,
  maxAdminExecutions: 20,
};
