import { maybeGetTalentOrSpell } from 'common/maybeGetTalentOrSpell';
import type { Buff } from 'parser/core/Events';

import type { LocalActor, LocalDiagnostic } from '../../LocalCombatLogParser';
import type { CompanionSnapshot } from './contracts';

const UNKNOWN_ICON = 'inv_misc_questionmark';

export interface CompanionAuraMaterializationSummary {
  readonly completeness: CompanionSnapshot['completeness'];
  readonly capturedAuraCount: number;
  readonly materializedAuraCount: number;
  readonly skippedSecret: number;
  readonly skippedInvalid: number;
  readonly skippedUnknownSource: number;
  readonly skippedUnresolvedSource: number;
}

export interface MaterializedCompanionAuras {
  readonly auras: readonly Buff[];
  readonly diagnostics: readonly LocalDiagnostic[];
  readonly summary: CompanionAuraMaterializationSummary;
}

const countLabel = (count: number, singular: string) =>
  `${count} ${singular}${count === 1 ? '' : 's'}`;

/**
 * Map only exact GUIDs already present in the local actor model. In particular,
 * an unknown or missing source never falls back to the selected player.
 */
export function materializeCompanionAuras(
  snapshot: CompanionSnapshot,
  actors: readonly LocalActor[],
): MaterializedCompanionAuras {
  const actorsByGuid = new Map<string, LocalActor | undefined>();
  for (const actor of actors) {
    actorsByGuid.set(actor.guid, actorsByGuid.has(actor.guid) ? undefined : actor);
  }

  const auras: Buff[] = [];
  let skippedUnknownSource = 0;
  let skippedUnresolvedSource = 0;
  for (const record of snapshot.auras) {
    if (record.sourceGuid === null) {
      skippedUnknownSource += 1;
      continue;
    }
    const source = actorsByGuid.get(record.sourceGuid);
    if (!source || !Number.isSafeInteger(source.id) || source.id <= 0) {
      skippedUnresolvedSource += 1;
      continue;
    }
    const spell = maybeGetTalentOrSpell(record.spellId);
    auras.push({
      source: source.id,
      ability: record.spellId,
      stacks: record.applications,
      icon: spell?.icon ?? UNKNOWN_ICON,
      ...(spell?.name ? { name: spell.name } : {}),
    });
  }

  const diagnostics: LocalDiagnostic[] = [];
  if (snapshot.completeness === 'partial') {
    diagnostics.push({
      line: 0,
      severity: 'warning',
      message: `The pull snapshot was partial: ${countLabel(snapshot.auras.length, 'readable aura')} captured; ${countLabel(snapshot.skippedSecret, 'secret entry')} and ${countLabel(snapshot.skippedInvalid, 'invalid entry')} skipped by the addon.`,
    });
  }
  if (skippedUnknownSource > 0 || skippedUnresolvedSource > 0) {
    const omittedSources = [
      ...(skippedUnknownSource === 0
        ? []
        : [`${countLabel(skippedUnknownSource, 'captured aura')} with an unknown source`]),
      ...(skippedUnresolvedSource === 0
        ? []
        : [
            `${countLabel(skippedUnresolvedSource, 'captured aura')} whose source did not resolve uniquely in the combat log`,
          ]),
    ];
    diagnostics.push({
      line: 0,
      severity: 'warning',
      message: `Localog omitted ${omittedSources.join(' and ')}; no caster was substituted.`,
    });
  }

  return {
    auras,
    diagnostics,
    summary: {
      completeness: snapshot.completeness,
      capturedAuraCount: snapshot.auras.length,
      materializedAuraCount: auras.length,
      skippedSecret: snapshot.skippedSecret,
      skippedInvalid: snapshot.skippedInvalid,
      skippedUnknownSource,
      skippedUnresolvedSource,
    },
  };
}
