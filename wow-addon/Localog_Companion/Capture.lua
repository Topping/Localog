local _, Localog = ...

local Capture = {}
Localog.Capture = Capture

local MAX_AURAS = 255
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
  if type(sourceGUID) ~= "string" then
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
  if not isIntegerInRange(applications, 1, 255) then
    return nil, "invalid"
  end

  return {
    spellID = spellID,
    applications = applications,
    sourceGUID = readSourceGUID(aura),
  }
end

local function snapshotHelpfulAuras()
  local startedMs = debugprofilestop()
  local shouldAurasBeSecret = safePredicate(C_Secrets.ShouldAurasBeSecret)
  if shouldAurasBeSecret == nil then
    return { status = "unavailable", reason = "aura_secrecy_predicate_failed" }
  end

  local indexPredicate = C_Secrets.ShouldUnitAuraIndexBeSecret
  if shouldAurasBeSecret and not indexPredicate then
    return {
      status = "unavailable",
      reason = "missing_index_secrecy_predicate",
      shouldAurasBeSecret = true,
    }
  end

  local auras = {}
  local skippedSecret = 0
  local skippedInvalid = 0
  local terminatorIndex = nil

  for index = 1, MAX_AURAS do
    if indexPredicate then
      local indexIsSecret = safePredicate(indexPredicate, "player", index, HELPFUL_FILTER)
      if indexIsSecret == nil then
        return {
          status = "unavailable",
          reason = "index_secrecy_predicate_failed",
          failedIndex = index,
          shouldAurasBeSecret = shouldAurasBeSecret,
          skippedSecret = skippedSecret,
          skippedInvalid = skippedInvalid,
          elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
        }
      end
      if indexIsSecret then
        skippedSecret = skippedSecret + 1
      else
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, HELPFUL_FILTER)
        if not ok then
          return {
            status = "unavailable",
            reason = "indexed_aura_query_failed",
            failedIndex = index,
            shouldAurasBeSecret = shouldAurasBeSecret,
            skippedSecret = skippedSecret,
            skippedInvalid = skippedInvalid,
            elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
          }
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
        end
      end
    else
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, HELPFUL_FILTER)
      if not ok then
        return {
          status = "unavailable",
          reason = "indexed_aura_query_failed",
          failedIndex = index,
          shouldAurasBeSecret = shouldAurasBeSecret,
          skippedSecret = skippedSecret,
          skippedInvalid = skippedInvalid,
          elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
        }
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
      end
    end
  end

  if not terminatorIndex then
    return {
      status = "unavailable",
      reason = "iteration_bound_reached",
      shouldAurasBeSecret = shouldAurasBeSecret,
      skippedSecret = skippedSecret,
      skippedInvalid = skippedInvalid,
      elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    }
  end

  local status = (skippedSecret > 0 or skippedInvalid > 0) and "partial" or "complete"
  return {
    status = status,
    reason = nil,
    auras = auras,
    capturedAt = GetServerTime(),
    skippedSecret = skippedSecret,
    skippedInvalid = skippedInvalid,
    terminatorIndex = terminatorIndex,
    shouldAurasBeSecret = shouldAurasBeSecret,
    elapsedMs = math.max(0, math.floor(debugprofilestop() - startedMs)),
    restrictions = Localog:ObserveRestrictionStates(),
    inCombatLockdown = InCombatLockdown() == true,
  }
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

  local result = snapshotHelpfulAuras()
  probe.result = result
  probe.armed = false
  if result.status == "complete" or result.status == "partial" then
    probe.snapshot = result
  else
    probe.snapshot = nil
  end
end
