local addonName, Localog = ...

Localog.addonName = addonName

local LOGGING_CALL_LIMIT = 5
local LOGGING_CALL_WINDOW_SECONDS = 10
local loggingCallTimes = {}

local function newProbe()
  return {
    armed = false,
    observing = false,
    sequence = 0,
    events = {},
    result = nil,
    snapshot = nil,
  }
end

local function newSession(notice)
  return {
    state = "idle",
    loggingOwned = false,
    loggingStartedBySession = false,
    loggingActive = nil,
    loggingWasPreexisting = false,
    loggingOwnershipUnknown = false,
    advancedLogging = nil,
    simcPublicAPI = nil,
    issue = nil,
    retryAt = nil,
    retryAction = nil,
    cancelRequested = false,
    notice = notice,
  }
end

Localog.probe = newProbe()
Localog.session = newSession()

local frame = CreateFrame("Frame")

local function getMetadata(key)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(addonName, key)
  end

  if GetAddOnMetadata then
    return GetAddOnMetadata(addonName, key)
  end

  return nil
end

local function getCVarValue(name)
  local getter = C_CVar and C_CVar.GetCVar or GetCVar
  if type(getter) ~= "function" then
    return nil
  end

  local ok, value = pcall(getter, name)
  if not ok or not Localog:IsAccessible(value) or type(value) ~= "string" then
    return nil
  end

  if value == "1" then
    return true
  end
  if value == "0" then
    return false
  end

  return nil
end

local function setCVarValue(name, value)
  local setter = C_CVar and C_CVar.SetCVar or SetCVar
  if type(setter) ~= "function" then
    return false
  end

  local ok, success = pcall(setter, name, value)
  return ok and Localog:IsAccessible(success) and success == true
end

local function pruneLoggingCalls(now)
  local retained = {}
  for _, callTime in ipairs(loggingCallTimes) do
    if now - callTime < LOGGING_CALL_WINDOW_SECONDS then
      retained[#retained + 1] = callTime
    end
  end
  loggingCallTimes = retained
end

function Localog:GetVersion()
  return getMetadata("Version") or "unknown"
end

function Localog:GetRestrictionEnums()
  local restrictionType = Enum and Enum.AddOnRestrictionType
  local restrictionState = Enum and Enum.AddOnRestrictionState

  if not restrictionType or not restrictionState then
    return nil
  end

  return {
    type = {
      combat = restrictionType.Combat,
      encounter = restrictionType.Encounter,
      challengeMode = restrictionType.ChallengeMode,
      pvpMatch = restrictionType.PvPMatch,
      map = restrictionType.Map,
      chat = restrictionType.Chat,
    },
    state = {
      inactive = restrictionState.Inactive,
      activating = restrictionState.Activating,
      active = restrictionState.Active,
    },
  }
end

function Localog:IsAccessible(value)
  if canaccessvalue then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end

  if issecretvalue then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
  end

  return false
end

function Localog:GetRestrictionState(restrictionType)
  if not C_RestrictedActions or not C_RestrictedActions.GetAddOnRestrictionState then
    return nil
  end

  local ok, state = pcall(C_RestrictedActions.GetAddOnRestrictionState, restrictionType)
  if not ok or not self:IsAccessible(state) or type(state) ~= "number" then
    return nil
  end

  return state
end

function Localog:ObserveRestrictionStates()
  local enums = self:GetRestrictionEnums()
  if not enums then
    return nil
  end

  return {
    combat = self:GetRestrictionState(enums.type.combat),
    encounter = self:GetRestrictionState(enums.type.encounter),
    challengeMode = self:GetRestrictionState(enums.type.challengeMode),
    pvpMatch = self:GetRestrictionState(enums.type.pvpMatch),
    map = self:GetRestrictionState(enums.type.map),
    chat = self:GetRestrictionState(enums.type.chat),
  }
end

function Localog:GetRestrictionBlocker()
  local enums = self:GetRestrictionEnums()
  local states = self:ObserveRestrictionStates()
  if not enums or not states then
    return "unknown"
  end

  local orderedStates = {
    { name = "combat", state = states.combat },
    { name = "encounter", state = states.encounter },
    { name = "challenge_mode", state = states.challengeMode },
    { name = "pvp_match", state = states.pvpMatch },
    { name = "map", state = states.map },
    { name = "chat", state = states.chat },
  }
  for _, entry in ipairs(orderedStates) do
    if entry.state == nil then
      return "unknown"
    end
    if entry.state ~= enums.state.inactive then
      return entry.name
    end
  end

  if InCombatLockdown() then
    return "combat_lockdown"
  end

  return nil
end

function Localog:GetClientContext()
  local version, build, _, toc = GetBuildInfo()
  local mapID = nil

  if C_Map and C_Map.GetBestMapForUnit then
    local ok, value = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and self:IsAccessible(value) and type(value) == "number" then
      mapID = value
    end
  end

  return {
    addonVersion = self:GetVersion(),
    clientVersion = version,
    clientBuild = tonumber(build),
    clientToc = tonumber(toc),
    projectID = WOW_PROJECT_ID,
    mapID = mapID,
  }
end

function Localog:CheckProbeSupport()
  local enums = self:GetRestrictionEnums()
  if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    return false, "unsupported_project"
  end
  if not enums then
    return false, "missing_restriction_enums"
  end
  if type(enums.type.combat) ~= "number"
    or type(enums.type.encounter) ~= "number"
    or type(enums.type.challengeMode) ~= "number"
    or type(enums.type.pvpMatch) ~= "number"
    or type(enums.type.map) ~= "number"
    or type(enums.type.chat) ~= "number"
    or type(enums.state.inactive) ~= "number"
    or type(enums.state.activating) ~= "number"
    or type(enums.state.active) ~= "number"
  then
    return false, "incomplete_restriction_enums"
  end
  if not C_RestrictedActions or not C_RestrictedActions.GetAddOnRestrictionState then
    return false, "missing_restriction_api"
  end
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
    return false, "missing_indexed_aura_api"
  end
  if not C_Secrets or not C_Secrets.ShouldAurasBeSecret then
    return false, "missing_aura_secrecy_api"
  end
  if not canaccessvalue and not issecretvalue then
    return false, "missing_value_secrecy_api"
  end

  return true
end

function Localog:CheckSessionSupport()
  local supported, reason = self:CheckProbeSupport()
  if not supported then
    return false, reason
  end
  if type(LoggingCombat) ~= "function" then
    return false, "missing_logging_api"
  end
  if type(C_CVar and C_CVar.GetCVar or GetCVar) ~= "function"
    or type(C_CVar and C_CVar.SetCVar or SetCVar) ~= "function"
  then
    return false, "missing_cvar_api"
  end
  return true
end

function Localog:SetLimited(issue, retryAction)
  self.session.state = "limited"
  self.session.issue = issue
  self.session.retryAction = retryAction
  self:RefreshUI()
end

function Localog:GetLoggingRetrySeconds()
  local retryAt = self.session.retryAt
  if not retryAt then
    return 0
  end

  return math.max(0, math.ceil(retryAt - GetTime()))
end

function Localog:GetSnapshotAgeSeconds()
  local snapshot = self.probe and self.probe.snapshot
  if not snapshot or type(snapshot.capturedAt) ~= "number" then
    return nil
  end

  local ok, now = pcall(GetServerTime)
  if not ok or not self:IsAccessible(now) or type(now) ~= "number" then
    return nil
  end

  return math.max(0, math.floor(now - snapshot.capturedAt))
end

function Localog:CallLoggingCombat(desiredState)
  local now = GetTime()
  pruneLoggingCalls(now)
  if #loggingCallTimes >= LOGGING_CALL_LIMIT then
    self.session.retryAt = loggingCallTimes[1] + LOGGING_CALL_WINDOW_SECONDS
    return nil, "local_rate_limit"
  end

  loggingCallTimes[#loggingCallTimes + 1] = now
  local ok, active
  if desiredState == nil then
    ok, active = pcall(LoggingCombat)
  else
    ok, active = pcall(LoggingCombat, desiredState)
  end

  if not ok or not self:IsAccessible(active) or type(active) ~= "boolean" then
    self.session.retryAt = now + LOGGING_CALL_WINDOW_SECONDS
    return nil, ok and "shared_rate_limit" or "logging_api_error"
  end

  self.session.retryAt = nil
  self.session.loggingActive = active
  return active, nil
end

function Localog:ConfirmAdvancedLogging()
  local enabled = getCVarValue("advancedCombatLogging")
  if enabled == false then
    if not setCVarValue("advancedCombatLogging", "1") then
      return nil, "advanced_logging_enable_failed"
    end
    enabled = getCVarValue("advancedCombatLogging")
  end

  self.session.advancedLogging = enabled
  if enabled == nil then
    return nil, "advanced_logging_unknown"
  end
  if not enabled then
    return false, "advanced_logging_disabled"
  end

  return true
end

function Localog:ArmCaptureSession()
  self.probe = {
    armed = true,
    observing = true,
    sequence = 0,
    events = {},
    result = nil,
    snapshot = nil,
    armedAt = GetServerTime(),
    startedProfileMs = debugprofilestop(),
    context = self:GetClientContext(),
    armedRestrictions = self:ObserveRestrictionStates(),
  }
  self.session.state = "armed"
  self.session.issue = nil
  self.session.retryAction = nil
  self:RefreshUI()
end

function Localog:StartPracticeCapture(preserveUnknownOwnership)
  self.probe = newProbe()
  self.session = newSession()
  self.SimcIntegration:ResetAttemptStatus()
  self.session.loggingOwnershipUnknown = preserveUnknownOwnership == true
  self.session.state = "starting"
  self.session.startedAt = GetServerTime()
  self:RefreshUI()

  local supported, reason = self:CheckSessionSupport()
  self.session.simcPublicAPI = self.SimcIntegration:GetProbeStatus()
  if not supported then
    self:SetLimited(reason, "preflight")
    return false
  end

  local restriction = self:GetRestrictionBlocker()
  if restriction then
    self:SetLimited("restricted_" .. restriction, "preflight")
    return false
  end

  local advanced, advancedReason = self:ConfirmAdvancedLogging()
  if not advanced then
    self:SetLimited(advancedReason, "preflight")
    return false
  end

  local loggingActive, loggingReason = self:CallLoggingCombat(nil)
  if loggingActive == nil then
    self:SetLimited("logging_query_unknown_" .. loggingReason, "preflight")
    return false
  end

  if loggingActive then
    if not self.session.loggingOwnershipUnknown then
      self.session.loggingWasPreexisting = true
    end
    self:ArmCaptureSession()
    return true
  end

  local started, startReason = self:CallLoggingCombat(true)
  if started == nil then
    self.session.loggingOwnershipUnknown = true
    self:SetLimited("logging_start_unknown_" .. startReason, "preflight")
    return false
  end
  if not started then
    self:SetLimited("logging_start_failed", "preflight")
    return false
  end

  self.session.loggingOwned = true
  self.session.loggingStartedBySession = true
  self.session.loggingOwnershipUnknown = false
  self:ArmCaptureSession()
  return true
end

function Localog:RetryPreflight()
  return self:StartPracticeCapture(self.session.loggingOwnershipUnknown)
end

function Localog:FinalizeAfterLoggingStop()
  self.probe.observing = false
  if self.session.cancelRequested then
    self:ResetSession(self.session.cancelNotice)
    return
  end

  if self.probe.result
    and (self.probe.result.status == "complete" or self.probe.result.status == "partial")
    and type(self.probe.result.protocolBlock) == "string"
  then
    self.session.state = "ready"
    self.session.issue = nil
    self.session.retryAction = nil
  else
    self:SetLimited(
      "capture_" .. (self.probe.result and self.probe.result.reason or "missing"),
      "reset"
    )
    return
  end

  self:RefreshUI()
end

function Localog:StopOwnedLogging()
  if not self.session.loggingOwned then
    self:FinalizeAfterLoggingStop()
    return true
  end

  self.session.state = "stopping"
  self.session.issue = nil
  self.session.retryAction = nil
  local active, reason = self:CallLoggingCombat(false)
  if active == false then
    self.session.loggingOwned = false
    self:FinalizeAfterLoggingStop()
    return true
  end

  if active == true then
    self.session.retryAt = GetTime() + LOGGING_CALL_WINDOW_SECONDS
    reason = "logging_remained_active"
  end
  self.session.issue = "logging_stop_unknown_" .. (reason or "unknown")
  self.session.retryAction = "stop"
  self:RefreshUI()
  return false
end

function Localog:RestrictionsCleared()
  local blocker = self:GetRestrictionBlocker()
  if blocker then
    self.session.issue = "waiting_for_restriction_" .. blocker
    self:RefreshUI()
    return false
  end

  return true
end

function Localog:FinishAttempt()
  if self.session.state ~= "captured"
    and self.session.state ~= "stopping"
    and not self.session.cancelRequested
  then
    return
  end
  if self.session.state == "stopping" and self.session.retryAction == "stop" then
    return
  end
  if not self:RestrictionsCleared() then
    return
  end

  self:StopOwnedLogging()
end

function Localog:RetryStop()
  if self:GetLoggingRetrySeconds() > 0 then
    return false
  end
  if not self:RestrictionsCleared() then
    return false
  end

  return self:StopOwnedLogging()
end

function Localog:OnCaptureFinished(result)
  self.session.captureStatus = result.status
  self.session.state = "captured"
  if result.status ~= "complete" and result.status ~= "partial" then
    self.session.issue = "capture_" .. (result.reason or "unknown")
  end
  self:RefreshUI()
end

function Localog:CancelSession()
  if self.session.state == "idle" then
    return
  end

  self.probe.armed = false
  self.probe.observing = false
  self.session.cancelRequested = true
  if not self.probe.result then
    self.session.cancelNotice = "capture_canceled_before_combat"
  else
    self.session.cancelNotice = "capture_canceled"
  end

  if self.session.loggingOwned then
    if self:RestrictionsCleared() then
      self:StopOwnedLogging()
    else
      self.session.state = "stopping"
    end
    return
  end

  self:ResetSession(self.session.cancelNotice)
end

function Localog:ResetSession(notice)
  self.probe = newProbe()
  self.session = newSession(notice)
  self.SimcIntegration:ResetAttemptStatus()
  self.session.simcPublicAPI = self.SimcIntegration:GetProbeStatus()
  self:RefreshUI()
end

function Localog:RecordRestrictionEvent(restrictionType, restrictionState)
  if not self.probe.observing then
    return
  end
  if not self:IsAccessible(restrictionType) or not self:IsAccessible(restrictionState) then
    return
  end
  if type(restrictionType) ~= "number" or type(restrictionState) ~= "number" then
    return
  end

  self.probe.sequence = self.probe.sequence + 1
  local startedProfileMs = self.probe.startedProfileMs or debugprofilestop()
  local elapsedMs = math.max(0, math.floor(debugprofilestop() - startedProfileMs))
  local observedState = self:GetRestrictionState(restrictionType)

  self.probe.events[#self.probe.events + 1] = {
    sequence = self.probe.sequence,
    elapsedMs = elapsedMs,
    restrictionType = restrictionType,
    eventState = restrictionState,
    observedState = observedState,
  }
end

function Localog:RefreshUI()
  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end
end

function Localog:OnAddonLoaded(loadedAddonName)
  if loadedAddonName ~= addonName then
    return
  end

  frame:UnregisterEvent("ADDON_LOADED")
  if self.SimcIntegration and self.SimcIntegration.Initialize then
    self.SimcIntegration:Initialize()
    self.session.simcPublicAPI = self.SimcIntegration:GetProbeStatus()
  end
  if self.UI and self.UI.Initialize then
    self.UI:Initialize()
  end
  self:RegisterSlashCommands()
end

function Localog:OnRestrictionStateChanged(restrictionType, restrictionState)
  self:RecordRestrictionEvent(restrictionType, restrictionState)

  if self.Capture and self.Capture.OnRestrictionStateChanged then
    self.Capture:OnRestrictionStateChanged(restrictionType, restrictionState)
  end

  local enums = self:GetRestrictionEnums()
  if enums and restrictionState == enums.state.inactive then
    self:FinishAttempt()
  end

  self:RefreshUI()
end

function Localog:RegisterSlashCommands()
  SLASH_LOCALOGCOMPANION1 = "/localog"
  SlashCmdList.LOCALOGCOMPANION = function(message)
    local command = string.lower(strtrim(message or ""))

    if command == "start" or command == "arm" then
      self:ShowUI()
      self:StartPracticeCapture()
    elseif command == "cancel" or command == "reset" then
      self:CancelSession()
      self:ShowUI()
    elseif command == "retry" then
      self:ShowUI()
      if self.session.retryAction == "stop" then
        self:RetryStop()
      else
        self:RetryPreflight()
      end
    elseif command == "snapshot" then
      self:ShowSnapshot()
    elseif command == "export" then
      self:ShowCombinedExport()
    elseif command == "copy" or command == "evidence" then
      self:ShowEvidence()
    else
      self:ShowUI()
    end
  end
end

function Localog:ShowUI()
  if self.UI and self.UI.Show then
    self.UI:Show()
  end
end

function Localog:ShowEvidence()
  if self.UI and self.UI.ShowEvidence then
    self.UI:ShowEvidence(self:BuildEvidenceText())
  end
end

function Localog:ShowSnapshot()
  local snapshot = self.probe.snapshot
  if self.session.state ~= "ready" then
    self.session.issue = "snapshot_not_ready"
    self:RefreshUI()
    self:ShowUI()
    return false
  end
  if not snapshot or type(snapshot.protocolBlock) ~= "string" then
    self:SetLimited("snapshot_block_unavailable", "reset")
    self:ShowUI()
    return false
  end
  if self.UI and self.UI.ShowSnapshot then
    self.UI:ShowSnapshot(snapshot.protocolBlock)
    return true
  end

  return false
end

function Localog:ShowCombinedExport()
  if self.session.state ~= "ready" then
    self.session.issue = "export_not_ready"
    self:RefreshUI()
    self:ShowUI()
    return false
  end

  local snapshot = self.probe.snapshot
  if not snapshot or type(snapshot.protocolBlock) ~= "string" then
    self:SetLimited("snapshot_block_unavailable", "reset")
    self:ShowUI()
    return false
  end

  local combined, reason = self.SimcIntegration:GenerateCombinedExport(snapshot.protocolBlock)
  self.session.simcPublicAPI = self.SimcIntegration:GetProbeStatus()
  if not combined then
    self.session.issue = "export_" .. (reason or "unknown")
    self:RefreshUI()
    self:ShowUI()
    return false
  end

  self.session.issue = nil
  self:RefreshUI()
  if self.UI and self.UI.ShowExport then
    self.UI:ShowExport(combined)
    return true
  end

  return false
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    Localog:OnAddonLoaded(...)
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    Localog:OnRestrictionStateChanged(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    Localog:FinishAttempt()
  elseif event == "PLAYER_LOGIN" then
    Localog:RefreshUI()
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
