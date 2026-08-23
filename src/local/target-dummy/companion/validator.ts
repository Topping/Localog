import type { TargetDummySessionCandidate } from '../contracts';
import type { ParsedSimcAddonProfile } from '../simc/contracts';
import {
  COMPANION_CAPTURE_TIME_TOLERANCE_MS,
  type CompanionResult,
  type CompanionSnapshot,
  type CompanionSnapshotFailureCode,
} from './contracts';

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

/** Convert the UTC-encoded wall clock retained by discovery into local Unix time. */
function combatLogWallClockToEpoch(timestamp: number): number {
  const wallClock = new Date(timestamp);
  return new Date(
    wallClock.getUTCFullYear(),
    wallClock.getUTCMonth(),
    wallClock.getUTCDate(),
    wallClock.getUTCHours(),
    wallClock.getUTCMinutes(),
    wallClock.getUTCSeconds(),
    wallClock.getUTCMilliseconds(),
  ).getTime();
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

  const capturedAt = snapshot.capturedAt * 1000;
  const activityStart = combatLogWallClockToEpoch(binding.session.activityStart);
  const activityEnd = combatLogWallClockToEpoch(binding.session.end);
  if (
    capturedAt < activityStart - COMPANION_CAPTURE_TIME_TOLERANCE_MS ||
    capturedAt > activityEnd + COMPANION_CAPTURE_TIME_TOLERANCE_MS
  ) {
    return failure(
      'COMPANION_CAPTURE_TIME_MISMATCH',
      'The Localog companion snapshot was not captured during the selected target-dummy attempt.',
      'Select the matching attempt or record a fresh standalone attempt and companion export.',
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
