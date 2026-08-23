import type { LocalActor } from '../LocalCombatLogParser';
import type {
  PreparedTargetDummyInput,
  TargetDummyPreparationFailure,
  TargetDummyPreparationInput,
} from '../localCombatLogProtocol';
import { buildCombatantInfoEvent } from './combatant-info/builder';
import { INSTALLED_TALENT_SNAPSHOTS } from './combatant-info/data/installed';
import { decodeTalentExport } from './combatant-info/talents';
import type { TargetDummyBuildBinding } from './combatant-info/validator';
import { parseCompanionSnapshot } from './companion/parser';
import { materializeCompanionAuras } from './companion/materializer';
import { validateCompanionSnapshotBinding } from './companion/validator';
import type { TargetDummyActorDiscoveryResult } from './contracts';
import { parseSimcAddonProfile } from './simc/parser';
import type { SimcProfileFailure, SimcResult } from './simc/contracts';

type TargetDummyPreparationResult =
  | { readonly ok: true; readonly value: PreparedTargetDummyInput }
  | { readonly ok: false; readonly error: TargetDummyPreparationFailure };

function malformedSelection(message: string): SimcResult<never> {
  return {
    ok: false,
    error: {
      code: 'SIMC_PROFILE_MALFORMED',
      message,
      recoverable: true,
      suggestedAction: 'Choose a player and attempt from the current discovery results.',
    },
  };
}

export function prepareTargetDummyInput(
  discovery: TargetDummyActorDiscoveryResult,
  localActors: readonly LocalActor[],
  build: TargetDummyBuildBinding,
  input: TargetDummyPreparationInput,
): TargetDummyPreparationResult {
  const player = discovery.players.find((candidate) => candidate.guid === input.playerGuid);
  const session = discovery.sessions.find((candidate) => candidate.id === input.sessionId);
  const localActor = localActors.find((actor) => actor.guid === input.playerGuid);
  if (!player || !session || session.playerGuid !== player.guid || !localActor) {
    return malformedSelection(
      'The selected target-dummy player or attempt is no longer available.',
    );
  }

  const companion = parseCompanionSnapshot(input.simcProfile);
  if (!companion.ok) {
    return companion;
  }
  const profile = parseSimcAddonProfile(input.simcProfile);
  if (!profile.ok) {
    return profile;
  }
  const companionBinding = validateCompanionSnapshotBinding(companion.value, {
    playerGuid: player.guid,
    session,
    profile: profile.value,
  });
  if (!companionBinding.ok) {
    return companionBinding;
  }
  const talents = decodeTalentExport(profile.value.talentExport, INSTALLED_TALENT_SNAPSHOTS, {
    wowVersion: profile.value.provenance.wowVersion,
  });
  if (!talents.ok) {
    return talents;
  }
  const pullTimeAuras =
    companionBinding.value === undefined
      ? undefined
      : materializeCompanionAuras(companionBinding.value, localActors);
  const combatantInfo = buildCombatantInfoEvent({
    profile: profile.value,
    talents: talents.value,
    player: { name: player.name ?? localActor.name, sourceId: localActor.id },
    build,
    timestamp: session.fightStart,
    factionChoice: input.factionChoice,
    pullTimeStats: companionBinding.value?.stats,
    pullTimeAuras,
  });
  if (!combatantInfo.ok) {
    return combatantInfo;
  }
  return {
    ok: true,
    value: {
      playerGuid: player.guid,
      session,
      combatantInfo: combatantInfo.value,
      ...(companionBinding.value === undefined
        ? {}
        : { companionSnapshot: companionBinding.value }),
    },
  };
}

export function targetDummyPreparationError(error: unknown): SimcProfileFailure {
  return {
    code: 'SIMC_PROFILE_MALFORMED',
    message: error instanceof Error ? error.message : 'Unable to prepare the target-dummy input.',
    recoverable: true,
    suggestedAction:
      'Review the selected attempt and paste the complete matching Localog Companion export.',
  };
}
