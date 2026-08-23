local _, Localog = ...

local Protocol = {
  schema = 2,
  maximumAuras = 255,
  maximumBlockBytes = 65536,
  maximumLineBytes = 512,
  startMarker = "### Localog Companion Snapshot",
  endMarker = "### End Localog Companion Snapshot",
}
Localog.Protocol = Protocol

Protocol.statKeys = {
  "strength",
  "agility",
  "stamina",
  "intellect",
  "dodge",
  "parry",
  "block",
  "critMelee",
  "critRanged",
  "critSpell",
  "speed",
  "leech",
  "hasteMelee",
  "hasteRanged",
  "hasteSpell",
  "avoidance",
  "mastery",
  "versatilityDamageDone",
  "versatilityHealingDone",
  "versatilityDamageReduction",
  "armor",
}

local MAX_INTEGER = 2147483647
local MAX_SAFE_INTEGER = 9007199254740991

local function isIntegerInRange(value, minimum, maximum)
  return type(value) == "number"
    and value == math.floor(value)
    and value >= minimum
    and value <= maximum
end

local function isDecimalComponent(value)
  if type(value) ~= "string" or not value:match("^%d+$") then
    return false
  end
  if #value > 1 and value:sub(1, 1) == "0" then
    return false
  end

  return isIntegerInRange(tonumber(value), 0, 65535)
end

local function splitDotComponents(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end

  local components = {}
  local startIndex = 1
  while true do
    local separatorIndex = value:find(".", startIndex, true)
    local component = separatorIndex and value:sub(startIndex, separatorIndex - 1)
      or value:sub(startIndex)
    if not isDecimalComponent(component) then
      return nil
    end
    components[#components + 1] = component
    if not separatorIndex then
      return components
    end
    startIndex = separatorIndex + 1
  end
end

local function isAddonVersion(value)
  local components = splitDotComponents(value)
  return components ~= nil and #components == 3
end

local function isClientVersion(value)
  local components = splitDotComponents(value)
  return components ~= nil and #components >= 2 and #components <= 4
end

local function isGUID(value, requirePlayerPrefix)
  if type(value) ~= "string" then
    return false
  end
  if #value < (requirePlayerPrefix and 8 or 3) or #value > 128 then
    return false
  end
  if requirePlayerPrefix and value:sub(1, 7) ~= "Player-" then
    return false
  end

  return value:match("^[A-Za-z0-9%-]+$") ~= nil
end

function Protocol:IsSourceGUID(value)
  return value == "-" or isGUID(value, false)
end

function Protocol:IsPlayerGUID(value)
  return isGUID(value, true)
end

function Protocol:NormalizeAuras(auras)
  if type(auras) ~= "table" then
    return nil, "auras_missing"
  end

  local recordsByKey = {}
  local duplicatesCollapsed = 0
  for _, aura in ipairs(auras) do
    if type(aura) ~= "table"
      or not isIntegerInRange(aura.spellID, 1, MAX_INTEGER)
      or not isIntegerInRange(aura.applications, 1, 255)
      or not self:IsSourceGUID(aura.sourceGUID)
    then
      return nil, "aura_invalid"
    end

    local key = tostring(aura.spellID) .. "," .. aura.sourceGUID
    local existing = recordsByKey[key]
    if existing then
      duplicatesCollapsed = duplicatesCollapsed + 1
      if aura.applications > existing.applications then
        existing.applications = aura.applications
      end
    else
      recordsByKey[key] = {
        spellID = aura.spellID,
        applications = aura.applications,
        sourceGUID = aura.sourceGUID,
      }
    end
  end

  local normalized = {}
  for _, aura in pairs(recordsByKey) do
    normalized[#normalized + 1] = aura
  end
  if #normalized > self.maximumAuras then
    return nil, "aura_count_exceeded"
  end

  table.sort(normalized, function(left, right)
    if left.spellID == right.spellID then
      return left.sourceGUID < right.sourceGUID
    end
    return left.spellID < right.spellID
  end)

  return normalized, nil, duplicatesCollapsed
end

local function validateAuraOrder(auras)
  local previous = nil
  for _, aura in ipairs(auras) do
    if type(aura) ~= "table"
      or not isIntegerInRange(aura.spellID, 1, MAX_INTEGER)
      or not isIntegerInRange(aura.applications, 1, 255)
      or not Protocol:IsSourceGUID(aura.sourceGUID)
    then
      return false, "aura_invalid"
    end

    if previous then
      if aura.spellID < previous.spellID
        or (aura.spellID == previous.spellID and aura.sourceGUID <= previous.sourceGUID)
      then
        return false, "aura_order_or_duplicate_invalid"
      end
    end
    previous = aura
  end

  return true
end

local function validateStats(stats)
  if type(stats) ~= "table" then
    return false, "stats_missing"
  end

  for _, key in ipairs(Protocol.statKeys) do
    if not isIntegerInRange(stats[key], 0, MAX_INTEGER) then
      return false, "stats_invalid"
    end
  end

  return true
end

function Protocol:ValidateSnapshot(snapshot, generatedAt)
  if type(snapshot) ~= "table" then
    return false, "snapshot_missing"
  end
  if not isAddonVersion(snapshot.addonVersion) then
    return false, "addon_version_invalid"
  end
  if not self:IsPlayerGUID(snapshot.playerGUID) then
    return false, "player_guid_invalid"
  end
  if not isClientVersion(snapshot.clientVersion) then
    return false, "client_version_invalid"
  end
  if not isIntegerInRange(snapshot.clientBuild, 1, MAX_INTEGER) then
    return false, "client_build_invalid"
  end
  if not isIntegerInRange(snapshot.clientToc, 1, MAX_INTEGER) then
    return false, "client_toc_invalid"
  end
  if not isIntegerInRange(snapshot.capturedAt, 1, MAX_SAFE_INTEGER)
    or not isIntegerInRange(generatedAt, 1, MAX_SAFE_INTEGER)
    or snapshot.capturedAt > generatedAt
  then
    return false, "captured_at_invalid"
  end
  if snapshot.trigger ~= "combat_activating" then
    return false, "trigger_invalid"
  end
  if snapshot.status ~= "complete" and snapshot.status ~= "partial" then
    return false, "completeness_invalid"
  end
  if not isIntegerInRange(snapshot.skippedSecret, 0, 255)
    or not isIntegerInRange(snapshot.skippedInvalid, 0, 255)
  then
    return false, "skipped_count_invalid"
  end
  if snapshot.status == "complete"
    and (snapshot.skippedSecret ~= 0 or snapshot.skippedInvalid ~= 0)
  then
    return false, "complete_with_skipped_entries"
  end
  if snapshot.status == "partial"
    and snapshot.skippedSecret == 0
    and snapshot.skippedInvalid == 0
  then
    return false, "partial_without_skipped_entries"
  end
  local statsValid, statsReason = validateStats(snapshot.stats)
  if not statsValid then
    return false, statsReason
  end
  if type(snapshot.auras) ~= "table" or #snapshot.auras > self.maximumAuras then
    return false, "aura_count_invalid"
  end

  return validateAuraOrder(snapshot.auras)
end

local function addLine(lines, line)
  if #line > Protocol.maximumLineBytes then
    return false
  end
  lines[#lines + 1] = line
  return true
end

function Protocol:SerializeSnapshot(snapshot, generatedAt)
  local valid, reason = self:ValidateSnapshot(snapshot, generatedAt)
  if not valid then
    return nil, reason
  end

  local lines = {}
  local function field(key, value)
    return addLine(lines, "# localog." .. key .. "=" .. tostring(value))
  end

  if not addLine(lines, self.startMarker)
    or not field("schema", self.schema)
    or not field("addon_version", snapshot.addonVersion)
    or not field("player_guid", snapshot.playerGUID)
    or not field("client_version", snapshot.clientVersion)
    or not field("client_build", snapshot.clientBuild)
    or not field("client_toc", snapshot.clientToc)
    or not field("captured_at", snapshot.capturedAt)
    or not field("trigger", snapshot.trigger)
    or not field("completeness", snapshot.status)
    or not field("skipped_secret", snapshot.skippedSecret)
    or not field("skipped_invalid", snapshot.skippedInvalid)
  then
    return nil, "line_size_exceeded"
  end

  local serializedStats = {}
  for _, key in ipairs(self.statKeys) do
    serializedStats[#serializedStats + 1] = tostring(snapshot.stats[key])
  end
  if not field("stats", table.concat(serializedStats, ",")) then
    return nil, "line_size_exceeded"
  end

  for _, aura in ipairs(snapshot.auras) do
    if not field(
      "aura",
      table.concat({ tostring(aura.spellID), tostring(aura.applications), aura.sourceGUID }, ",")
    ) then
      return nil, "line_size_exceeded"
    end
  end

  if not addLine(lines, self.endMarker) then
    return nil, "line_size_exceeded"
  end

  local block = table.concat(lines, "\n") .. "\n"
  if #block > self.maximumBlockBytes then
    return nil, "block_size_exceeded"
  end

  return block
end
