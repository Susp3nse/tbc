import { config } from './config.js';
import { getToken } from './auth.js';

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Execute a GraphQL query against WCL API v2.
 * @param {string} query - GraphQL query string
 * @param {object} variables - Query variables (optional)
 * @returns {object} The `data` field from the response
 */
export async function graphql(query, variables = {}) {
  const token = await getToken();

  const res = await fetch(config.wcl.apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`WCL API error (${res.status}): ${text}`);
  }

  const json = await res.json();
  if (json.errors) {
    throw new Error(`WCL GraphQL errors: ${JSON.stringify(json.errors)}`);
  }

  return json.data;
}

/**
 * Fetch paginated events from a report fight.
 * Follows nextPageTimestamp until all events are collected.
 */
export async function fetchAllEvents(reportCode, fightID, dataType, startTime, endTime, opts = {}) {
  const allEvents = [];
  let cursor = startTime;
  const limit = opts.limit || 10000;
  const sourceID = opts.sourceID;

  while (cursor !== null && cursor < endTime) {
    const sourceFilter = sourceID != null ? `sourceID: ${sourceID},` : '';
    const query = `
      query {
        reportData {
          report(code: "${reportCode}") {
            events(
              fightIDs: [${fightID}],
              dataType: ${dataType},
              startTime: ${cursor},
              endTime: ${endTime},
              limit: ${limit},
              ${sourceFilter}
            ) {
              data
              nextPageTimestamp
            }
          }
        }
      }
    `;

    const data = await graphql(query);
    const events = data.reportData.report.events;

    if (events.data && events.data.length > 0) {
      allEvents.push(...events.data);
    }

    cursor = events.nextPageTimestamp;

    if (cursor !== null) {
      await delay(config.requestDelayMs);
    }
  }

  return allEvents;
}
