import { getHistory, getCurrentRequest } from './request.js';

const startTime = Date.now();

export async function handleStatus(interaction) {
  const userId = interaction.user.id;
  const uptime = formatDuration(Date.now() - startTime);
  const current = getCurrentRequest();
  const recentHistory = getHistory(userId);

  const lines = [`**Bot Status**\nUptime: ${uptime}`];

  if (current) {
    const elapsed = formatDuration(Date.now() - current.startTime);
    lines.push(`\nCurrently processing a request for <@${current.userId}> (${elapsed})`);
  } else {
    lines.push('\nNo active request.');
  }

  if (recentHistory.length > 0) {
    lines.push('\n**Your Recent Requests**');
    for (const entry of recentHistory.slice(-5).reverse()) {
      const time = new Date(entry.timestamp).toLocaleString();
      const status = entry.status === 'success' ? 'OK' : entry.status;
      lines.push(`- \`${status}\` ${time} — ${entry.prompt.slice(0, 80)}`);
    }
  } else {
    lines.push('\nNo request history.');
  }

  await interaction.reply({ content: lines.join('\n'), ephemeral: true });
}

function formatDuration(ms) {
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s % 60}s`;
  return `${s}s`;
}
