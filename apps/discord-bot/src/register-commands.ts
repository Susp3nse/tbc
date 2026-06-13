import { REST, Routes, SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { config } from './config.js';

const commands = [
  new SlashCommandBuilder()
    .setName('request')
    .setDescription('Request a personalized rotation tweak')
    .addStringOption(opt =>
      opt.setName('prompt')
        .setDescription('Describe what you want changed')
        .setRequired(true)
        .setMaxLength(config.maxRequestLength)
    )
    .addStringOption(opt =>
      opt.setName('class')
        .setDescription('Restrict edits to a specific class')
        .addChoices(
          { name: 'Druid', value: 'druid' },
          { name: 'Hunter', value: 'hunter' },
        )
    ),
  new SlashCommandBuilder()
    .setName('status')
    .setDescription('Check bot status and your recent request history'),
  new SlashCommandBuilder()
    .setName('admin')
    .setDescription('AI-assisted server management (Administrator only)')
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .addStringOption(opt =>
      opt.setName('prompt')
        .setDescription('What do you want to do? (natural language)')
        .setRequired(true)
        .setMaxLength(1000)
    ),
];

const rest = new REST().setToken(config.discordToken);

const route = config.guildId
  ? Routes.applicationGuildCommands(config.clientId, config.guildId)
  : Routes.applicationCommands(config.clientId);

try {
  console.log(`Registering ${commands.length} commands...`);
  await rest.put(route, { body: commands.map(c => c.toJSON()) });
  console.log('Commands registered successfully.');
} catch (err) {
  console.error('Failed to register commands:', err);
  process.exit(1);
}
