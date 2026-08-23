import DK_SPELLS from 'common/SPELLS/deathknight';
import TALENTS from 'common/TALENTS/deathknight';
import RESOURCE_TYPES from 'game/RESOURCE_TYPES';
import { Section, useInfo } from 'interface/guide';
import { AplSectionData } from 'interface/guide/components/Apl';
import SpellLink from 'interface/SpellLink';
import { suggestion } from 'parser/core/Analyzer';
import { AnyEvent, EventType } from 'parser/core/Events';
import aplCheck, { Apl, build, CheckResult, PlayerInfo, Rule } from 'parser/shared/metrics/apl';
import annotateTimeline from 'parser/shared/metrics/apl/annotate';
import {
  and,
  buffMissing,
  buffPresent,
  buffStacks,
  debuffMissing,
  hasResource,
  lastSpellCast,
  not,
  or,
  spellAvailable,
  spellCharges,
  spellCooldownRemaining,
  spellSpecific,
  targetsHit,
} from 'parser/shared/metrics/apl/conditions';

const RUNIC_POWER_SCALE_FACTOR = 0.1;
const FESTERING_SCYTHE_DURATION_MS = 25_000;
const FESTERING_SCYTHE_REFRESH_WINDOW_MS = 3_000;
const APL_CHECK_DELAY_MS = 15_000;

/** Stable IDs make future source comparisons independent of display text and spell IDs. */
export const UNHOLY_APL_RULE_IDS = {
  outbreak: 'unholy.disease.outbreak',
  blightburstPutrefy: 'unholy.disease.blightburst-putrefy',
  sanlaynSetup: 'unholy.sanlayn.dark-transformation-setup',
  army: 'unholy.cooldown.army-of-the-dead',
  darkTransformation: 'unholy.cooldown.dark-transformation',
  cappedPutrefy: 'unholy.putrefy.avoid-charge-cap',
  forbiddenActions: 'unholy.forbidden-knowledge.actions',
  burstMaintenance: 'unholy.common.burst-maintenance',
  deathAndDecay: 'unholy.aoe.death-and-decay',
  soulReaper: 'unholy.cooldown.soul-reaper',
  suddenDoom: 'unholy.common.sudden-doom',
  sanlaynPutrefy: 'unholy.sanlayn.putrefy',
  vampiricStrike: 'unholy.sanlayn.vampiric-strike',
  festeringStrike: 'unholy.common.festering-strike',
  scourgeStrike: 'unholy.common.scourge-strike',
  runicPowerSpender: 'unholy.common.runic-power-spender',
} as const;

const plagueMissing = () =>
  or(debuffMissing(DK_SPELLS.VIRULENT_PLAGUE), debuffMissing(DK_SPELLS.DREAD_PLAGUE));

const festeringScytheMissingOrExpiring = () =>
  buffMissing(DK_SPELLS.FESTERING_SCYTHE_BUFF, {
    duration: FESTERING_SCYTHE_DURATION_MS,
    timeRemaining: FESTERING_SCYTHE_REFRESH_WINDOW_MS,
  });

const runicPowerAtLeast = (amount: number) =>
  hasResource(
    RESOURCE_TYPES.RUNIC_POWER,
    { atLeast: amount / RUNIC_POWER_SCALE_FACTOR },
    { displayScaleFactor: RUNIC_POWER_SCALE_FACTOR },
  );

const runesAtLeast = (amount: number) => hasResource(RESOURCE_TYPES.RUNES, { atLeast: amount }, 6);

const runicPowerSpenderAffordable = () =>
  or(runicPowerAtLeast(30), and(buffPresent(DK_SPELLS.SUDDEN_DOOM_BUFF), runicPowerAtLeast(15)));

const deathAndDecayTargets = () =>
  targetsHit(
    { atLeast: 2 },
    {
      lookahead: 1_500,
      targetType: EventType.Damage,
      targetSpell: DK_SPELLS.DEATH_AND_DECAY_DAMAGE_TICK,
    },
  );

const necroticCoilTargets = () =>
  targetsHit(
    { atMost: 3 },
    {
      lookahead: 1_000,
      targetType: EventType.Damage,
      targetSpell: DK_SPELLS.NECROTIC_COIL_DAMAGE_HIT,
    },
  );

const graveyardTargets = () =>
  targetsHit(
    { atLeast: 4 },
    {
      lookahead: 1_000,
      targetType: EventType.Damage,
      targetSpell: DK_SPELLS.GRAVEYARD_DAMAGE,
    },
  );

const deathCoilTargets = () =>
  targetsHit(
    { atMost: 2 },
    {
      lookahead: 1_000,
      targetType: EventType.Damage,
      targetSpell: DK_SPELLS.DEATH_COIL_DAMAGE,
    },
  );

const epidemicTargets = () =>
  targetsHit(
    { atLeast: 3 },
    {
      lookahead: 1_000,
      targetType: EventType.Damage,
      targetSpell: DK_SPELLS.EPIDEMIC_DAMAGE,
    },
  );

/** Patch 12.1 Rider of the Apocalypse and San'layn APL. */
export function unholyApl(info: PlayerInfo): Apl {
  const combatant = info.combatant;
  const isSanlayn = combatant.hasTalent(TALENTS.VAMPIRIC_STRIKE_TALENT);
  const hasBlightburst = combatant.hasTalent(TALENTS.BLIGHTBURST_TALENT);
  const hasFesteringScythe = combatant.hasTalent(TALENTS.FESTERING_SCYTHE_TALENT);
  const hasSoulReaper = combatant.hasTalent(TALENTS.SOUL_REAPER_TALENT);
  const hasForbiddenKnowledge = combatant.hasTalent(TALENTS.FORBIDDEN_KNOWLEDGE_1_UNHOLY_TALENT);
  const rules: Rule[] = [];

  if (!hasBlightburst) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.outbreak,
      spell: DK_SPELLS.OUTBREAK,
      condition: and(plagueMissing(), runesAtLeast(1)),
    });
  } else {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.blightburstPutrefy,
      spell: TALENTS.PUTREFY_TALENT,
      condition: and(plagueMissing(), runesAtLeast(1)),
      description: (
        <>
          Use <SpellLink spell={TALENTS.PUTREFY_TALENT} /> to apply diseases when{' '}
          <SpellLink spell={TALENTS.BLIGHTBURST_TALENT} /> is talented.
        </>
      ),
    });
  }

  if (isSanlayn) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.sanlaynSetup,
      spell: DK_SPELLS.FESTERING_STRIKE,
      condition: and(
        spellAvailable(TALENTS.DARK_TRANSFORMATION_TALENT),
        buffStacks(DK_SPELLS.LESSER_GHOUL_BUFF, { atMost: 3 }),
        runesAtLeast(2),
      ),
      description: (
        <>
          Enter <SpellLink spell={TALENTS.DARK_TRANSFORMATION_TALENT} /> with more than three{' '}
          <SpellLink spell={DK_SPELLS.LESSER_GHOUL_BUFF} /> stacks.
        </>
      ),
    });
  }

  if (combatant.hasTalent(TALENTS.ARMY_OF_THE_DEAD_TALENT)) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.army,
      spell: TALENTS.ARMY_OF_THE_DEAD_TALENT,
      description: (
        <>
          Use <SpellLink spell={TALENTS.ARMY_OF_THE_DEAD_TALENT} /> on cooldown.
        </>
      ),
    });
  }

  rules.push({
    id: UNHOLY_APL_RULE_IDS.darkTransformation,
    spell: TALENTS.DARK_TRANSFORMATION_TALENT,
    description: (
      <>
        Use <SpellLink spell={TALENTS.DARK_TRANSFORMATION_TALENT} /> on cooldown and align it with{' '}
        <SpellLink spell={TALENTS.ARMY_OF_THE_DEAD_TALENT} /> when both are ready.
      </>
    ),
  });

  if (combatant.hasTalent(TALENTS.PUTRID_ECHOES_TALENT)) {
    const capCondition = and(spellCharges(TALENTS.PUTREFY_TALENT, { atLeast: 2 }), runesAtLeast(1));
    rules.push({
      id: UNHOLY_APL_RULE_IDS.cappedPutrefy,
      spell: TALENTS.PUTREFY_TALENT,
      condition:
        !isSanlayn && hasSoulReaper
          ? and(capCondition, spellAvailable(TALENTS.SOUL_REAPER_TALENT, { inverse: true }))
          : capCondition,
      description: (
        <>
          Spend <SpellLink spell={TALENTS.PUTREFY_TALENT} /> before charge generation is wasted.
        </>
      ),
    });
  }

  if (hasForbiddenKnowledge) {
    const alternatives: Parameters<typeof spellSpecific>[0] = [
      {
        spell: TALENTS.PUTREFY_TALENT,
        condition: and(
          buffPresent(DK_SPELLS.FORBIDDEN_KNOWLEDGE_BUFF),
          or(
            buffPresent(DK_SPELLS.DARK_TRANSFORMATION_BUFF),
            spellCharges(TALENTS.PUTREFY_TALENT, { atLeast: 2 }),
          ),
          runesAtLeast(1),
        ),
      },
      {
        spell: DK_SPELLS.NECROTIC_COIL,
        condition: and(
          buffPresent(DK_SPELLS.FORBIDDEN_KNOWLEDGE_BUFF),
          runicPowerSpenderAffordable(),
          necroticCoilTargets(),
        ),
      },
      {
        spell: DK_SPELLS.GRAVEYARD,
        condition: and(
          buffPresent(DK_SPELLS.FORBIDDEN_KNOWLEDGE_BUFF),
          runicPowerSpenderAffordable(),
          graveyardTargets(),
        ),
      },
    ];
    if (hasFesteringScythe) {
      alternatives.push({
        spell: DK_SPELLS.FESTERING_SCYTHE,
        condition: and(
          buffPresent(DK_SPELLS.FORBIDDEN_KNOWLEDGE_BUFF),
          festeringScytheMissingOrExpiring(),
          lastSpellCast(DK_SPELLS.FESTERING_STRIKE),
        ),
      });
    }
    rules.push({
      id: UNHOLY_APL_RULE_IDS.forbiddenActions,
      spell: alternatives.map(({ spell }) => spell),
      condition: spellSpecific(alternatives),
      description: (
        <>
          During <SpellLink spell={DK_SPELLS.FORBIDDEN_KNOWLEDGE_BUFF} />, maintain{' '}
          <SpellLink spell={DK_SPELLS.FESTERING_SCYTHE_BUFF} />, spend{' '}
          <SpellLink spell={TALENTS.PUTREFY_TALENT} />, and use{' '}
          <SpellLink spell={DK_SPELLS.NECROTIC_COIL} /> through three targets or{' '}
          <SpellLink spell={DK_SPELLS.GRAVEYARD} /> at four or more.
        </>
      ),
    });
  }

  const maintenanceAlternatives: Parameters<typeof spellSpecific>[0] = [
    {
      spell: TALENTS.PUTREFY_TALENT,
      condition: and(buffPresent(DK_SPELLS.DARK_TRANSFORMATION_BUFF), runesAtLeast(1)),
    },
  ];
  if (hasFesteringScythe) {
    maintenanceAlternatives.push({
      spell: DK_SPELLS.FESTERING_SCYTHE,
      condition: and(festeringScytheMissingOrExpiring(), lastSpellCast(DK_SPELLS.FESTERING_STRIKE)),
    });
  }
  rules.push({
    id: UNHOLY_APL_RULE_IDS.burstMaintenance,
    spell: maintenanceAlternatives.map(({ spell }) => spell),
    condition: spellSpecific(maintenanceAlternatives),
    description: (
      <>
        Spend <SpellLink spell={TALENTS.PUTREFY_TALENT} /> during{' '}
        <SpellLink spell={TALENTS.DARK_TRANSFORMATION_TALENT} /> and maintain{' '}
        <SpellLink spell={DK_SPELLS.FESTERING_SCYTHE_BUFF} />. The source-supported ordering varies
        with target count.
      </>
    ),
  });

  if (combatant.hasTalent(TALENTS.CYCLE_OF_DEATH_TALENT)) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.deathAndDecay,
      spell: DK_SPELLS.DEATH_AND_DECAY,
      condition: and(
        deathAndDecayTargets(),
        buffMissing(DK_SPELLS.DEATH_AND_DECAY_BUFF),
        runesAtLeast(1),
      ),
    });
  }

  if (hasSoulReaper) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.soulReaper,
      spell: TALENTS.SOUL_REAPER_TALENT,
      condition: runesAtLeast(1),
      description: (
        <>
          Use <SpellLink spell={TALENTS.SOUL_REAPER_TALENT} /> on cooldown, including the reset from{' '}
          <SpellLink spell={TALENTS.DARK_TRANSFORMATION_TALENT} />.
        </>
      ),
    });
  }

  const prioritySpend = isSanlayn
    ? or(buffPresent(DK_SPELLS.SUDDEN_DOOM_BUFF), runicPowerAtLeast(80))
    : buffPresent(DK_SPELLS.SUDDEN_DOOM_BUFF);
  const suddenDoomAlternatives: Parameters<typeof spellSpecific>[0] = [
    {
      spell: DK_SPELLS.DEATH_COIL,
      condition: and(prioritySpend, runicPowerSpenderAffordable(), deathCoilTargets()),
    },
    {
      spell: DK_SPELLS.EPIDEMIC,
      condition: and(prioritySpend, runicPowerSpenderAffordable(), epidemicTargets()),
    },
  ];
  rules.push({
    id: UNHOLY_APL_RULE_IDS.suddenDoom,
    spell: suddenDoomAlternatives.map(({ spell }) => spell),
    condition: spellSpecific(suddenDoomAlternatives),
  });

  if (isSanlayn) {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.sanlaynPutrefy,
      spell: TALENTS.PUTREFY_TALENT,
      condition: and(
        spellCooldownRemaining(TALENTS.DARK_TRANSFORMATION_TALENT, { atLeast: 15_000 }),
        runesAtLeast(1),
      ),
    });
    rules.push({
      id: UNHOLY_APL_RULE_IDS.vampiricStrike,
      spell: DK_SPELLS.VAMPIRIC_STRIKE,
      condition: and(
        buffStacks(DK_SPELLS.ESSENCE_OF_THE_BLOOD_QUEEN_BUFF, { atMost: 6 }),
        or(
          buffPresent(DK_SPELLS.VAMPIRIC_STRIKE_TRIGGER_BUFF),
          buffPresent(DK_SPELLS.GIFT_OF_THE_SANLAYN_BUFF),
        ),
        runesAtLeast(1),
      ),
    });
  }

  rules.push({
    id: UNHOLY_APL_RULE_IDS.festeringStrike,
    spell: DK_SPELLS.FESTERING_STRIKE,
    condition: and(buffStacks(DK_SPELLS.LESSER_GHOUL_BUFF, { atMost: 0 }), runesAtLeast(2)),
  });

  if (isSanlayn) {
    const vampiricStrikeAvailable = or(
      buffPresent(DK_SPELLS.VAMPIRIC_STRIKE_TRIGGER_BUFF),
      buffPresent(DK_SPELLS.GIFT_OF_THE_SANLAYN_BUFF),
    );
    const strikeAlternatives: Parameters<typeof spellSpecific>[0] = [
      {
        spell: TALENTS.SCOURGE_STRIKE_TALENT,
        condition: and(
          buffStacks(DK_SPELLS.LESSER_GHOUL_BUFF, { atLeast: 1 }),
          not(vampiricStrikeAvailable),
          runesAtLeast(1),
        ),
      },
      {
        spell: DK_SPELLS.VAMPIRIC_STRIKE,
        condition: and(
          buffStacks(DK_SPELLS.LESSER_GHOUL_BUFF, { atLeast: 1 }),
          vampiricStrikeAvailable,
          runesAtLeast(1),
        ),
      },
    ];
    rules.push({
      id: UNHOLY_APL_RULE_IDS.scourgeStrike,
      spell: strikeAlternatives.map(({ spell }) => spell),
      condition: spellSpecific(strikeAlternatives),
    });
  } else {
    rules.push({
      id: UNHOLY_APL_RULE_IDS.scourgeStrike,
      spell: TALENTS.SCOURGE_STRIKE_TALENT,
      condition: and(buffStacks(DK_SPELLS.LESSER_GHOUL_BUFF, { atLeast: 1 }), runesAtLeast(1)),
    });
  }

  const runicPowerAlternatives: Parameters<typeof spellSpecific>[0] = [
    {
      spell: DK_SPELLS.DEATH_COIL,
      condition: and(runicPowerAtLeast(30), deathCoilTargets()),
    },
    {
      spell: DK_SPELLS.EPIDEMIC,
      condition: and(runicPowerAtLeast(30), epidemicTargets()),
    },
  ];
  rules.push({
    id: UNHOLY_APL_RULE_IDS.runicPowerSpender,
    spell: runicPowerAlternatives.map(({ spell }) => spell),
    condition: spellSpecific(runicPowerAlternatives),
  });

  return { ...build(rules), checkDelay: APL_CHECK_DELAY_MS };
}

export const check = (events: AnyEvent[], info: PlayerInfo): CheckResult =>
  aplCheck(unholyApl(info))(events, info);

export function AplSection() {
  const info = useInfo();
  if (!info) {
    return null;
  }

  const apl = unholyApl(info);
  return (
    <Section title="Action Priority List">
      <p>
        This patch 12.1 priority adapts to Rider of the Apocalypse or San'layn and accepts the
        source-supported ordering differences around burst setup. Target-count rules are judged only
        when the combat log proves how many targets the cast hit. The opener is excluded from
        scoring because its exact sequence changes with selected talents and encounter timing.
      </p>
      <AplSectionData checker={check} apl={apl} />
    </Section>
  );
}

export default suggestion((events, info) => {
  const { violations } = check(events, info);
  annotateTimeline(violations);
  return undefined;
});
