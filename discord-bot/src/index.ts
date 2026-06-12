import { Client, Events, GatewayIntentBits } from 'discord.js';
import { config } from './config.js';
import { handleRequest } from './commands/request.js';
import { handleStatus } from './commands/status.js';
import { handleAdmin } from './commands/admin.js';
import { cleanupStaleWorkspaces } from './services/builder.js';
import { startWebhookServer } from './services/webhook.js';

const client = new Client({ intents: [GatewayIntentBits.Guilds] });

client.once(Events.ClientReady, (c) => {
  console.log(`Logged in as ${c.user.tag} (${c.guilds.cache.size} guilds)`);
  cleanupStaleWorkspaces();
  startWebhookServer(client);
});

client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  try {
    switch (interaction.commandName) {
      case 'request': return await handleRequest(interaction);
      case 'status': return await handleStatus(interaction);
      case 'admin': return await handleAdmin(interaction);
    }
  } catch (err) {
    console.error(`Command ${interaction.commandName} failed:`, err);
    const reply = { content: 'An unexpected error occurred.', ephemeral: true };
    if (interaction.deferred || interaction.replied) {
      await interaction.editReply(reply).catch(() => {});
    } else {
      await interaction.reply(reply).catch(() => {});
    }
  }
});

function shutdown() {
  console.log('Shutting down...');
  client.destroy();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

client.login(config.discordToken);
