LOCALOG COMPANION 0.5.0
=======================

Localog Companion records one target-dummy attempt and adds the readable pull-time
auras to a fresh SimulationCraft profile. It does not upload anything.

REQUIREMENTS

- Retail World of Warcraft 12.1.0 (interface 120100)
- SimulationCraft addon 12.0.5-04 or newer (12.1.0-03 is verified)
- Localog's current target-dummy importer

INSTALL

1. Exit World of Warcraft or log out to the character screen.
2. Copy this entire Localog_Companion folder into Retail's Interface/AddOns folder.
   The final path must be:

     World of Warcraft/_retail_/Interface/AddOns/Localog_Companion/

   Localog_Companion.toc must be directly inside that folder, not inside a second
   nested Localog_Companion folder.
3. Enable both SimulationCraft and Localog Companion in the AddOns list.
4. Enter the world and run /localog.

ONE-CAPTURE FLOW

1. Out of combat, click Start practice capture.
2. Wait for ARMED, then fight the target dummy.
3. Leave combat normally and wait for READY.
4. Click Copy for Localog. The complete combined export is selected automatically.
5. Copy it, open Localog's local combat-log importer, choose the matching character
   and attempt, and paste it into the SimulationCraft addon export field.
6. Import selected attempt.

Running /simc after READY is a convenience. Copy for Localog is the stable fallback.
New capture replaces the current in-memory snapshot. If Localog says the snapshot is
old, it will still export; choose the attempt that belongs to that capture.

PRIVACY

- The addon reads only helpful auras affecting the current player at pull activation.
- It stores the snapshot only in memory. /reload, logout, or a client crash clears it.
- It has no networking, uploads, addon communication, or SavedVariables.
- The combined clipboard text contains the normal SimulationCraft character profile,
  the player GUID, readable aura spell/source IDs, client build, and capture time.
  Treat that text as private. Copy evidence produces a sanitized diagnostic instead.
- Localog processes the chosen combat log in the browser and does not upload the file.

LIMITATIONS AND RECOVERY

- Capture only starts out of combat and while addon restrictions are inactive.
- If combat logging was already on, the addon leaves it on and never claims ownership.
- If logging is rate-limited, wait for the panel countdown and use Retry preflight or
  Stop combat logging. The addon never assumes an unknown result succeeded.
- A partial snapshot exports only safely readable auras and reports exact skipped
  counts. An unavailable snapshot is never replaced with stale aura data.
- Aura durations, expiration times, hostile units, and other players are not captured.
- Aura sources that Localog cannot resolve safely are omitted rather than fabricated.
- Localog trusts the character and attempt selected in its UI. Choose the attempt that
  matches the capture; capture time is diagnostic only.
- The combat log, snapshot, and SimulationCraft profile must use the same supported
  client build. Wrong players or builds are rejected before report creation.

COMMANDS

/localog          Open the state panel
/localog start    Start a new capture
/localog retry    Retry a rate-limited preflight or owned logging stop
/localog cancel   Cancel and discard the current capture
/localog export   Open a fresh combined export when READY
/localog copy     Open sanitized evidence

Source and license: https://github.com/Topping/WoWAnalyzer
