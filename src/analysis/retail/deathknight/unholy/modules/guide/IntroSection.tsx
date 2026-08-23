import { Section } from 'interface/guide';

export function IntroSection() {
  return (
    <Section title="Introduction">
      <p>
        Welcome to the patch 12.1 Unholy Death Knight analyzer. Its rotational guidance follows the
        current guides from{' '}
        <a href="https://www.method.gg/guides/unholy-death-knight/playstyle-and-rotation">Method</a>
        ,{' '}
        <a href="https://maxroll.gg/wow/class-guides/unholy-death-knight-raid-guide#rotation-header">
          Maxroll
        </a>{' '}
        and{' '}
        <a href="https://www.wowhead.com/guide/classes/death-knight/unholy/rotation-cooldowns-pve-dps">
          Wowhead
        </a>
        , with Method taking precedence where their recommendations differ.
      </p>
      <p>
        Unholy is all about spreading diseases, managing your undead army, and syncing your
        cooldowns to deliver devastating burst windows. This tool helps identify room for
        improvement in rotation, buff uptime, cooldown usage, and overall execution.
      </p>
      <p>
        The analysis here is based on general guidelines and doesn’t always account for specific
        fight mechanics or edge cases. For the most accurate benchmarking, compare your performance
        to other top Unholy Death Knights in the same encounter using{' '}
        <a href="https://www.warcraftlogs.com">Warcraft Logs</a>.
      </p>
      <p>
        If you have any questions, feedback, or suggestions, feel free to reach out in the{' '}
        <a href="https://discord.gg/acherus">Acherus Discord</a>.
      </p>
    </Section>
  );
}
