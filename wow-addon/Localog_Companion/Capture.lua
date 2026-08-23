local _, Localog = ...

local Capture = {}
Localog.Capture = Capture

local MAX_AURA_INDEX = Localog.Protocol.maximumAuras + 1
local HELPFUL_FILTER = "HELPFUL"

local function isIntegerInRange(value, minimum, maximum)
  return type(value) == "number"
    and value == math.floor(value)
    and value >= minimum
    and value <= maximum
end

local function safePredicate(predicate, ...)
  local ok, value = pcall(predicate, ...)
  if not ok or not Localog:IsAccessible(value) or type(value) ~= "boolean" then
    return nil
  end

  return value
end

local function readAuraField(aura, key)
  local ok, value = pcall(function()
    return aura[key]
  end)
  if not ok or not Localog:IsAccessible(value) then
    return nil, false
  end

  return value, true
end

local function readSourceGUID(aura)
  local sourceUnit, readable = readAuraField(aura, "sourceUnit")
  if not readable or sourceUnit == nil then
    return "-"
  end
  if type(sourceUnit) ~= "string" then
    return "-"
  end

  local ok, sourceGUID = pcall(UnitGUID, sourceUnit)
  if not ok or not Localog:IsAccessible(sourceGUID) or sourceGUID == nil then
    return "-"
  end
  if type(sourceGUID) ~= "string" or not Localog.Protocol:IsSourceGUID(sourceGUID) then
    return "-"
  end

  return sourceGUID
end

local function reduceAura(aura)
  if not Localog:IsAccessible(aura) or type(aura) ~= "table" then
    return nil, "secret"
  end

  local spellID, spellReadable = readAuraField(aura, "spellId")
  local applications, applicationsReadable = readAuraField(aura, "applications")
  if not spellReadable or not applicationsReadable then
    return nil, "secret"
  end
  if not isIntegerInRange(spellID, 1, 2147483647) then
    return nil, "invalid"
  end

  if applications == nil or applications == 0 then
    applications = 1
  end
  if not isIntegerInRange(applications, 1, 9007199254740991) then
    return nil, "invalid"
  end
  applications = math.min(applications, 255)

  return {
    spellID = spellID,
    applications = applications,
    sourceGUID = readSourceGUID(aura),
  }
end

local function readPlayerGUID()
  local ok, playerGUID = pcall(UnitGUID, "player")
  if not ok
    or not Localog:IsAccessible(playerGUID)
    or not Localog.Protocol:IsPlayerGUID(playerGUID)
  then
    return nil
  end

  return playerGUID
end

local function readCaptureTime()
  local ok, capturedAt = pcall(GetServerTime)
  if not ok
    or not Localog:IsAccessible(capturedAt)
    or not isIntegerInRange(capturedAt, 1, 9007199254740991)
  then
    return nil
  end

  return capturedAt
end

local function unavailable(reason, details)
  local result = details or {}
  result.status = "unavailable"
  result.reason = reason
  result.auras = nil
  result.protocolBlock = nil
  return result
end

local function snapshotHelpfulAuras(context)
  local startedMs = debugprofilestop()
  local playerGUID = readPlayerGUID()
  if not playerGUID then
    return unavailable("player_guid_unavailable")
  end

  local capturedAt = readCaptureTime()
  if not capturedAt then
    return unavailable("capture_time_unavailable")
  end

  local shouldAurasBeSecret = safePredicate(C_Secrets.ShouldAurasBeSecret)
  if shouldAurasBeSecret == nil then
    return unavailable("aura_secrecy_predicate_failed")
  end

  local indexPredicate = C_Secrets.ShouldUnitAuraIndexBeSecret
  if shouldAurasBeSecret and not indexPredicate then
    return unavailable("missing_index_secrecy_predicate", {
      shouldAurasBeSecret = true,
    })
  end

  local auras = {}
  local skippedSecret = 0
  local skippedInvalid = 0
  local terminatorIndex = nil

  for index = 1, MAX_AURA_INDEX do
    if indexPredicate then
      local indexIsSecret = safePredicate(indexPredicate, "player", index, HELPFUL_FILTER)
      if indexIsSecret == nil then
        return unavailable("index_secrecy_predicate_failed", {
          failedIndex = index,
          shouldAurasBeSecret = shouldAurasBeSecret,
          skippedSecret = skippedSecret,
          skippedInvalid = skippedInvalid,
          elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
        })
      end
      if indexIsSecret then
        skippedSecret = skippedSecret + 1
        if skippedSecret > 255 then
          return unavailable("skipped_count_exceeded", {
            failedIndex = index,
            shouldAurasBeSecret = shouldAurasBeSecret,
            skippedSecret = skippedSecret,
            skippedInvalid = skippedInvalid,
            elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
          })
        end
      else
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, HELPFUL_FILTER)
        if not ok then
          return unavailable("indexed_aura_query_failed", {
            failedIndex = index,
            shouldAurasBeSecret = shouldAurasBeSecret,
            skippedSecret = skippedSecret,
            skippedInvalid = skippedInvalid,
            elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
          })
        end
        if not Localog:IsAccessible(aura) then
          skippedSecret = skippedSecret + 1
        elseif aura == nil then
          terminatorIndex = index
          break
        else
          local reduced, skippedReason = reduceAura(aura)
          if reduced then
            auras[#auras + 1] = reduced
          elseif skippedReason == "secret" then
            skippedSecret = skippedSecret + 1
          else
            skippedInvalid = skippedInvalid + 1
          end
          if skippedSecret > 255 or skippedInvalid > 255 then
            return unavailable("skipped_count_exceeded", {
              failedIndex = index,
              shouldAurasBeSecret = shouldAurasBeSecret,
              skippedSecret = skippedSecret,
              skippedInvalid = skippedInvalid,
              elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
            })
          end
        end
      end
    else
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, HELPFUL_FILTER)
      if not ok then
        return unavailable("indexed_aura_query_failed", {
          failedIndex = index,
          shouldAurasBeSecret = shouldAurasBeSecret,
          skippedSecret = skippedSecret,
          skippedInvalid = skippedInvalid,
          elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
        })
      end
      if not Localog:IsAccessible(aura) then
        skippedSecret = skippedSecret + 1
      elseif aura == nil then
        terminatorIndex = index
        break
      else
        local reduced, skippedReason = reduceAura(aura)
        if reduced then
          auras[#auras + 1] = reduced
        elseif skippedReason == "secret" then
          skippedSecret = skippedSecret + 1
        else
          skippedInvalid = skippedInvalid + 1
        end
        if skippedSecret > 255 or skippedInvalid > 255 then
          return unavailable("skipped_count_exceeded", {
            failedIndex = index,
            shouldAurasBeSecret = shouldAurasBeSecret,
            skippedSecret = skippedSecret,
            skippedInvalid = skippedInvalid,
            elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
          })
        end
      end
    end
  end

  if not terminatorIndex then
    return unavailable("iteration_bound_reached", {
      shouldAurasBeSecret = shouldAurasBeSecret,
      skippedSecret = skippedSecret,
      skippedInvalid = skippedInvalid,
      elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    })
  end

  local normalizedAuras, normalizationReason, duplicatesCollapsed =
    Localog.Protocol:NormalizeAuras(auras)
  if not normalizedAuras then
    return unavailable("normalization_" .. normalizationReason, {
      shouldAurasBeSecret = shouldAurasBeSecret,
      skippedSecret = skippedSecret,
      skippedInvalid = skippedInvalid,
      terminatorIndex = terminatorIndex,
      elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    })
  end

  local status = (skippedSecret > 0 or skippedInvalid > 0) and "partial" or "complete"
  local snapshot = {
    status = status,
    reason = nil,
    addonVersion = context and context.addonVersion,
    playerGUID = playerGUID,
    clientVersion = context and context.clientVersion,
    clientBuild = context and context.clientBuild,
    clientToc = context and context.clientToc,
    capturedAt = capturedAt,
    trigger = "combat_activating",
    auras = normalizedAuras,
    skippedSecret = skippedSecret,
    skippedInvalid = skippedInvalid,
    duplicatesCollapsed = duplicatesCollapsed,
    terminatorIndex = terminatorIndex,
    shouldAurasBeSecret = shouldAurasBeSecret,
    elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    restrictions = Localog:ObserveRestrictionStates(),
    inCombatLockdown = InCombatLockdown() == true,
  }

  local protocolBlock, serializationReason =
    Localog.Protocol:SerializeSnapshot(snapshot, capturedAt)
  if not protocolBlock then
    return unavailable("serialization_" .. serializationReason, {
      shouldAurasBeSecret = shouldAurasBeSecret,
      skippedSecret = skippedSecret,
      skippedInvalid = skippedInvalid,
      terminatorIndex = terminatorIndex,
      elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    })
  end
  snapshot.protocolBlock = protocolBlock
  snapshot.protocolBytes = #protocolBlock

  return snapshot
end

function Capture:OnRestrictionStateChanged(restrictionType, restrictionState)
  local probe = Localog.probe
  if not probe.armed or probe.result then
    return
  end

  local enums = Localog:GetRestrictionEnums()
  if not enums
    or restrictionType ~= enums.type.combat
    or restrictionState ~= enums.state.activating
  then
    return
  end

  local result = snapshotHelpfulAuras(probe.context)
  probe.result = result
  probe.armed = false
  if result.status == "complete" or result.status == "partial" then
    probe.snapshot = result
  else
    probe.snapshot = nil
  end

  Localog:OnCaptureFinished(result)
end
