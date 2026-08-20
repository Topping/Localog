import { FormEvent, useMemo, useState } from 'react';
import { formatDuration } from 'common/format';
import type {
  TargetDummyInputRequest,
  TargetDummyPreparationInput,
} from 'local/localCombatLogProtocol';

interface Props {
  request: TargetDummyInputRequest;
  disabled: boolean;
  onSubmit: (input: TargetDummyPreparationInput) => void;
}

const actorName = (request: TargetDummyInputRequest, guid: string) =>
  request.discovery.actors.find((actor) => actor.guid === guid)?.name ?? guid;

const initialPlayerGuid = (request: TargetDummyInputRequest) =>
  request.discovery.proposedRecorderGuid ??
  (request.discovery.players.length === 1 ? request.discovery.players[0].guid : '');

const formatAttemptTime = (timestamp: number) =>
  new Date(timestamp).toLocaleTimeString(undefined, {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });

export default function TargetDummyImportInput({ request, disabled, onSubmit }: Props) {
  const [playerGuid, setPlayerGuid] = useState(() => initialPlayerGuid(request));
  const [sessionId, setSessionId] = useState('');
  const [simcProfile, setSimcProfile] = useState('');
  const [factionChoice, setFactionChoice] = useState<1 | 2 | undefined>();
  const sessions = useMemo(
    () => request.discovery.sessions.filter((session) => session.playerGuid === playerGuid),
    [playerGuid, request.discovery.sessions],
  );
  const selectedPlayer = request.discovery.players.find((player) => player.guid === playerGuid);
  const needsCharacterChoice =
    request.discovery.players.length > 1 && !request.discovery.proposedRecorderGuid;
  const needsFaction = request.validationError?.code === 'SIMC_FACTION_CHOICE_REQUIRED';

  const changePlayer = (guid: string) => {
    setPlayerGuid(guid);
    setSessionId('');
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!playerGuid || !sessionId || !simcProfile.trim() || (needsFaction && !factionChoice))
      return;
    onSubmit({ playerGuid, sessionId, simcProfile, factionChoice });
  };

  return (
    <form onSubmit={submit} style={{ marginTop: 20 }} aria-label="Prepare target-dummy import">
      <div className="alert alert-info" role="status">
        This log contains target-dummy activity instead of a complete encounter. Choose the
        character and attempt, then paste that character's current SimulationCraft addon export.
      </div>

      <div className="form-group">
        <label htmlFor="target-dummy-player">Character</label>
        {needsCharacterChoice ? (
          <select
            id="target-dummy-player"
            className="form-control"
            value={playerGuid}
            onChange={(event) => changePlayer(event.target.value)}
            disabled={disabled}
            required
          >
            <option value="">Choose a character</option>
            {request.discovery.players.map((player) => (
              <option key={player.guid} value={player.guid}>
                {player.name ?? player.guid}
              </option>
            ))}
          </select>
        ) : (
          <div id="target-dummy-player">
            <strong>{selectedPlayer?.name ?? selectedPlayer?.guid}</strong>
          </div>
        )}
      </div>

      <fieldset disabled={disabled || !playerGuid} style={{ marginTop: 15 }}>
        <legend style={{ fontSize: 'inherit', fontWeight: 600 }}>Attempt</legend>
        {sessions.map((session) => {
          const targets = session.targetGuids.map((guid) => actorName(request, guid));
          const targetLabel =
            targets.length === 1 ? targets[0] : `${targets[0]} and ${targets.length - 1} more`;
          return (
            <label key={session.id} style={{ display: 'block', marginBottom: 10 }}>
              <input
                type="radio"
                name="target-dummy-session"
                value={session.id}
                checked={sessionId === session.id}
                onChange={(event) => setSessionId(event.target.value)}
                required
              />{' '}
              {selectedPlayer?.name ?? selectedPlayer?.guid} ·{' '}
              {formatAttemptTime(session.activityStart)} · {formatDuration(session.durationMs)} ·{' '}
              {targetLabel} · {session.confidence}
            </label>
          );
        })}
      </fieldset>

      <div className="form-group" style={{ marginTop: 15 }}>
        <label htmlFor="target-dummy-simc">SimulationCraft addon export</label>
        <textarea
          id="target-dummy-simc"
          className="form-control"
          rows={10}
          value={simcProfile}
          onChange={(event) => setSimcProfile(event.target.value)}
          placeholder="In World of Warcraft, run /simc on the selected character and paste the complete output here."
          disabled={disabled}
          required
        />
      </div>

      {request.validationError && (
        <div className="alert alert-danger" role="alert">
          <strong>{request.validationError.message}</strong>{' '}
          {request.validationError.suggestedAction}
        </div>
      )}

      {needsFaction && (
        <div className="form-group">
          <label htmlFor="target-dummy-faction">Faction</label>
          <select
            id="target-dummy-faction"
            className="form-control"
            value={factionChoice ?? ''}
            onChange={(event) => setFactionChoice(Number(event.target.value) as 1 | 2)}
            disabled={disabled}
            required
          >
            <option value="">Choose a faction</option>
            <option value="1">Alliance</option>
            <option value="2">Horde</option>
          </select>
        </div>
      )}

      <p>
        <small>
          Identity, specialization, talents, and equipment come from this profile. Live ratings and
          pull-time auras are unavailable and will use explicit defaults.
        </small>
      </p>
      <button className="btn btn-primary" type="submit" disabled={disabled}>
        {disabled ? 'Validating…' : 'Import selected attempt'}
      </button>
    </form>
  );
}
