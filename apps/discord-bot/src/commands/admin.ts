import { PermissionFlagsBits, EmbedBuilder } from 'discord.js';
import { runAdminLoop } from '../services/admin-claude.js';

let currentSession = null;

export function getCurrentAdminSession() {
  return currentSession;
}

export async function handleAdmin(interaction) {
  const prompt = interaction.options.getString('prompt');
  const userId = interaction.user.id;

  // Belt-and-suspenders permission check (SlashCommand already gates via setDefaultMemberPermissions)
  if (!interaction.memberPermissions.has(PermissionFlagsBits.Administrator)) {
    return interaction.reply({ content: 'Administrator permission required.', ephemeral: true });
  }

  // Mutex: one admin session at a time
  if (currentSession) {
    return interaction.reply({
      content: `An admin session is already active (started by <@${currentSession.userId}>).`,
      ephemeral: true,
    });
  }

  currentSession = { userId, startTime: Date.now(), prompt };
  await interaction.deferReply();

  try {
    await interaction.editReply({
      embeds: [
        new EmbedBuilder()
          .setTitle('Admin Assistant')
          .setDescription('Analyzing your request...')
          .setColor(0x5865f2),
      ],
    });

    const result = await runAdminLoop(interaction.guild, interaction, prompt);

    if (result.success) {
      const embed = new EmbedBuilder()
        .setTitle('Admin Complete')
        .setDescription(result.summary || 'Session completed.')
        .setColor(0x57f287)
        .setFooter({ text: `Completed in ${formatDuration(Date.now() - currentSession.startTime)}` });

      if (result.actions.length > 0) {
        const actionsText = result.actions.map(a => `- ${a}`).join('\n');
        embed.addFields({ name: 'Actions Taken', value: actionsText.slice(0, 1024) });
      }

      await interaction.editReply({ embeds: [embed] });
    } else {
      await interaction.editReply({
        embeds: [
          new EmbedBuilder()
            .setTitle('Admin Session Ended')
            .setDescription(result.error || 'Session ended without completing.')
            .setColor(0xed4245),
        ],
      });
    }
  } catch (err) {
    console.error('Admin session failed:', err);
    await interaction.editReply({
      embeds: [
        new EmbedBuilder()
          .setTitle('Admin Error')
          .setDescription('An unexpected error occurred.')
          .setColor(0xed4245),
      ],
    }).catch(() => {});
  } finally {
    currentSession = null;
  }
}

function formatDuration(ms) {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const remaining = seconds % 60;
  return `${minutes}m ${remaining}s`;
}
