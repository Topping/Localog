local addonName, Localog = ...

Localog.addonName = addonName
Localog.probe = {
  armed = false,
  observing = false,
  sequence = 0,
  events = {},
  result = nil,
  snapshot = nil,
}

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

function Localog:ArmProbe()
  local supported, reason = self:CheckProbeSupport()
  if not supported then
    self.probe.armed = false
    self.probe.observing = false
    self.probe.result = { status = "unavailable", reason = reason }
    self:RefreshUI()
    return false
  end

  local enums = self:GetRestrictionEnums()
  local combatState = self:GetRestrictionState(enums.type.combat)
  if InCombatLockdown() or combatState ~= enums.state.inactive then
    self.probe.armed = false
    self.probe.observing = false
    self.probe.result = { status = "unavailable", reason = "combat_already_restricted" }
    self:RefreshUI()
    return false
  end

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
  self:RefreshUI()
  return true
end

function Localog:ResetProbe()
  self.probe = {
    armed = false,
    observing = false,
    sequence = 0,
    events = {},
    result = nil,
    snapshot = nil,
  }
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
  if enums
    and self.probe.result
    and restrictionType == enums.type.combat
    and restrictionState == enums.state.inactive
  then
    self.probe.observing = false
  end

  self:RefreshUI()
end

function Localog:RegisterSlashCommands()
  SLASH_LOCALOGCOMPANION1 = "/localog"
  SlashCmdList.LOCALOGCOMPANION = function(message)
    local command = string.lower(strtrim(message or ""))

    if command == "arm" then
      self:ShowUI()
      self:ArmProbe()
    elseif command == "reset" then
      self:ResetProbe()
      self:ShowUI()
    elseif command == "copy" then
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

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    Localog:OnAddonLoaded(...)
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    Localog:OnRestrictionStateChanged(...)
  elseif event == "PLAYER_LOGIN" then
    Localog:RefreshUI()
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
frame:RegisterEvent("PLAYER_LOGIN")
