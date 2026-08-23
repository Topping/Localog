local _, Localog = ...

local Integration = {
  minimumTestedVersion = "12.0.5-04",
  publicApiAvailable = false,
  convenienceHooked = false,
  convenienceIssue = nil,
  convenienceStatus = "not_attempted",
  stableStatus = "not_attempted",
}
Localog.SimcIntegration = Integration

local CHECKSUM_PREFIX = "# Checksum: "
local ADLER_MODULUS = 65521

local function getSimcVersion()
  local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  if type(getter) ~= "function" then
    return nil
  end

  local ok, version = pcall(getter, "Simulationcraft", "Version")
  if not ok or type(version) ~= "string" or version == "" then
    return nil
  end

  return version
end

local function adler32(value)
  local s1, s2 = 1, 0
  for index = 1, #value do
    s1 = (s1 + string.byte(value, index)) % ADLER_MODULUS
    s2 = (s2 + s1) % ADLER_MODULUS
  end

  return (s2 * 65536) + s1
end

local function toLowerHex(value)
  local digits = "0123456789abcdef"
  local result = ""
  repeat
    local remainder = value % 16
    result = digits:sub(remainder + 1, remainder + 1) .. result
    value = math.floor(value / 16)
  until value == 0

  return result
end

local function countExactChecksumLines(profile)
  local count = 0
  for line in (profile .. "\n"):gmatch("(.-)\n") do
    if line:match("^# Checksum: [0-9a-fA-F]+$") then
      count = count + 1
    end
  end

  return count
end

local function validateSnapshotBlock(snapshotBlock)
  if type(snapshotBlock) ~= "string" or snapshotBlock == "" then
    return false, "snapshot_block_missing"
  end
  if snapshotBlock:sub(1, #Localog.Protocol.startMarker) ~= Localog.Protocol.startMarker then
    return false, "snapshot_start_marker_missing"
  end

  local expectedEnding = Localog.Protocol.endMarker .. "\n"
  if snapshotBlock:sub(-#expectedEnding) ~= expectedEnding then
    return false, "snapshot_end_marker_missing"
  end
  if snapshotBlock:find(CHECKSUM_PREFIX, 1, true) then
    return false, "snapshot_contains_checksum"
  end

  for line in snapshotBlock:gmatch("([^\n]+)") do
    if line:sub(1, 1) ~= "#" then
      return false, "snapshot_non_comment_line"
    end
  end

  return true
end

function Integration:GetProbeStatus()
  return SimulationcraftAPI ~= nil
    and type(SimulationcraftAPI.GetSimcProfile) == "function"
end

function Integration:RefreshAvailability()
  self.simcVersion = getSimcVersion()
  self.publicApiAvailable = self:GetProbeStatus()
  return self.publicApiAvailable
end

function Integration:ResetAttemptStatus()
  self.stableStatus = "not_attempted"
  self.stableIssue = nil
  self.convenienceStatus = self.convenienceHooked and "awaiting_profile" or "unavailable"
  if self.convenienceHooked then
    self.convenienceIssue = nil
  end
end

function Integration:BuildCombinedExport(profile, snapshotBlock)
  if type(profile) ~= "string" or profile == "" then
    return nil, "profile_missing"
  end
  if profile:find(Localog.Protocol.startMarker, 1, true)
    or profile:find(Localog.Protocol.endMarker, 1, true)
  then
    return nil, "profile_already_contains_snapshot"
  end

  local snapshotValid, snapshotReason = validateSnapshotBlock(snapshotBlock)
  if not snapshotValid then
    return nil, snapshotReason
  end
  if countExactChecksumLines(profile) ~= 1 then
    return nil, "checksum_line_count_invalid"
  end

  local body, checksumHex = profile:match("^(.*\n)# Checksum: ([0-9a-fA-F]+)$")
  if not body or not checksumHex then
    return nil, "terminal_checksum_missing"
  end

  local suppliedChecksum = tonumber(checksumHex, 16)
  local clipboardBody = body:gsub("||", "|")
  local expectedChecksum = adler32(clipboardBody)
  if not suppliedChecksum or suppliedChecksum ~= expectedChecksum then
    return nil, "input_checksum_mismatch"
  end

  local combinedBody = body .. snapshotBlock
  local combinedClipboardBody = combinedBody:gsub("||", "|")
  local combinedChecksum = adler32(combinedClipboardBody)
  local combinedChecksumHex = toLowerHex(combinedChecksum)
  local combined = combinedBody .. CHECKSUM_PREFIX .. combinedChecksumHex

  return combined, nil, {
    originalBytes = #profile,
    snapshotBytes = #snapshotBlock,
    combinedBytes = #combined,
    inputChecksumVerified = true,
    terminalChecksumLines = countExactChecksumLines(combined),
    companionBlocks = 1,
    snapshotImmediatelyBeforeChecksum = true,
    addedLinesAreComments = true,
    outputChecksum = combinedChecksumHex,
  }
end

function Integration:GenerateCombinedExport(snapshotBlock)
  self:RefreshAvailability()
  if not self.publicApiAvailable then
    self.stableStatus = "failed"
    self.stableIssue = "missing_public_api"
    return nil, self.stableIssue
  end

  local ok, profile, simcError = pcall(
    SimulationcraftAPI.GetSimcProfile,
    SimulationcraftAPI,
    false,
    false,
    false,
    nil
  )
  if not ok then
    self.stableStatus = "failed"
    self.stableIssue = "profile_generation_error"
    return nil, self.stableIssue
  end
  if simcError ~= nil and simcError ~= "" then
    self.stableStatus = "failed"
    self.stableIssue = "profile_generation_rejected"
    return nil, self.stableIssue
  end

  local combined, reason = self:BuildCombinedExport(profile, snapshotBlock)
  if not combined then
    self.stableStatus = "failed"
    self.stableIssue = reason
    return nil, reason
  end

  self.stableStatus = "complete"
  self.stableIssue = nil
  return combined
end

function Integration:WarnConvenience(reason)
  self.convenienceIssue = reason
  self.convenienceStatus = "failed"
  if self.lastWarnedConvenienceIssue == reason then
    return
  end
  self.lastWarnedConvenienceIssue = reason

  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(
      "Localog Companion: /simc was left unchanged (" .. reason
        .. "). Use Copy for Localog from the companion panel."
    )
  end
end

function Integration:HandleSimcFrame(profile)
  if Localog.session.state ~= "ready" then
    self.convenienceStatus = "snapshot_not_ready"
    return
  end

  local snapshot = Localog.probe.snapshot
  if not snapshot or type(snapshot.protocolBlock) ~= "string" then
    self:WarnConvenience("snapshot_block_unavailable")
    Localog:RefreshUI()
    return
  end

  local editBox = _G.SimcEditBox
  if not editBox
    or type(editBox.GetText) ~= "function"
    or type(editBox.SetText) ~= "function"
    or type(editBox.HighlightText) ~= "function"
  then
    self:WarnConvenience("simc_edit_box_unavailable")
    Localog:RefreshUI()
    return
  end
  if type(profile) ~= "string" or editBox:GetText() ~= profile then
    self:WarnConvenience("simc_frame_contract_changed")
    Localog:RefreshUI()
    return
  end

  local combined, reason = self:BuildCombinedExport(profile, snapshot.protocolBlock)
  if not combined then
    self:WarnConvenience(reason)
    Localog:RefreshUI()
    return
  end

  editBox:SetText(combined)
  editBox:HighlightText()
  self.convenienceStatus = "complete"
  self.convenienceIssue = nil
  Localog:RefreshUI()
end

function Integration:InstallConvenienceHook()
  if self.convenienceHooked then
    return true
  end
  if type(hooksecurefunc) ~= "function" or type(LibStub) ~= "table" then
    self.convenienceIssue = "missing_hook_or_ace_registry"
    return false
  end

  local aceOk, aceAddon = pcall(function()
    return LibStub("AceAddon-3.0")
  end)
  if not aceOk or not aceAddon or type(aceAddon.GetAddon) ~= "function" then
    self.convenienceIssue = "missing_ace_addon_registry"
    return false
  end

  local addonOk, simcAddon = pcall(aceAddon.GetAddon, aceAddon, "Simulationcraft", true)
  if not addonOk or not simcAddon or type(simcAddon.GetMainFrame) ~= "function" then
    self.convenienceIssue = "missing_get_main_frame"
    return false
  end

  local hookOk = pcall(hooksecurefunc, simcAddon, "GetMainFrame", function(_, profile)
    Integration:HandleSimcFrame(profile)
  end)
  if not hookOk then
    self.convenienceIssue = "get_main_frame_hook_failed"
    return false
  end

  self.convenienceHooked = true
  self.convenienceIssue = nil
  self.convenienceStatus = "awaiting_profile"
  return true
end

function Integration:Initialize()
  self:RefreshAvailability()
  self:InstallConvenienceHook()
end
