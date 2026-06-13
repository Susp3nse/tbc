import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env') });

const wclBaseUrl = process.env.WCL_BASE_URL || 'https://www.warcraftlogs.com';

export const config = {
  wcl: {
    clientId: process.env.WCL_CLIENT_ID,
    clientSecret: process.env.WCL_CLIENT_SECRET,
    tokenUrl: `${wclBaseUrl}/oauth/token`,
    apiUrl: `${wclBaseUrl}/api/v2/client`,
  },
  dataDir: path.resolve(__dirname, '..', 'data'),
  requestDelayMs: 500,
};

export function assertWclConfig() {
  const required = ['WCL_CLIENT_ID', 'WCL_CLIENT_SECRET'];
  for (const key of required) {
    if (!process.env[key]) {
      throw new Error(`Missing required environment variable: ${key}. Check root .env file.`);
    }
  }
}
