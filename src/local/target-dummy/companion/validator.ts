import type { TargetDummySessionCandidate } from '../contracts';
import type { ParsedSimcAddonProfile } from '../simc/contracts';
import type { CompanionResult, CompanionSnapshot, CompanionSnapshotFailureCode } from './contracts';

interface CompanionSnapshotBinding {
  readonly playerGuid: string;
  readonly session: TargetDummySessionCandidate;
  readonly profile: ParsedSimcAddonProfile;
}

function failure(
  code: CompanionSnapshotFailureCode,
  message: string,
  suggestedAction: string,
): CompanionResult<never> {
  return { ok: false, error: { code, message, recoverable: true, suggestedAction } };
}

export function validateCompanionSnapshotBinding(
  snapshot: CompanionSnapshot | undefined,
  binding: CompanionSnapshotBinding,
): CompanionResult<CompanionSnapshot | undefined> {
  if (snapshot === undefined) return { ok: true, value: undefined };
  if (snapshot.playerGuid !== binding.playerGuid) {
    return failure(
      'COMPANION_PLAYER_MISMATCH',
      'The Localog companion snapshot belongs to a different combat-log player.',
      'Select the matching character or make a new capture on the selected character.',
    );
  }

  const provenance = binding.profile.provenance;
  const log = binding.session.logMetadata;
  const versionMismatch =
    (provenance.wowVersion !== undefined && provenance.wowVersion !== snapshot.clientVersion) ||
    (log?.wowVersion !== undefined && log.wowVersion !== snapshot.clientVersion);
  const buildMismatch =
    (provenance.wowBuild !== undefined && provenance.wowBuild !== String(snapshot.clientBuild)) ||
    (log?.clientBuild !== undefined && log.clientBuild !== snapshot.clientBuild);
  const tocMismatch =
    (provenance.tocVersion !== undefined && provenance.tocVersion !== snapshot.clientToc) ||
    (log?.clientToc !== undefined && log.clientToc !== snapshot.clientToc);
  if (versionMismatch || buildMismatch || tocMismatch) {
    return failure(
      'COMPANION_BUILD_MISMATCH',
      'The Localog companion snapshot, SimulationCraft profile, and combat log do not describe the same client build.',
      'Use the combat log and Copy for Localog export from the same game session.',
    );
  }

  if (log?.advancedLogging !== true) {
    return failure(
      'COMPANION_ADVANCED_LOG_REQUIRED',
      'The selected combat-log segment does not explicitly confirm advanced logging.',
      'Enable advanced logging with Localog Companion and record a new standalone attempt.',
    );
  }
  return { ok: true, value: snapshot };
}
