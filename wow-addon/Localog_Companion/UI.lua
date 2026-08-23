local _, Localog = ...

local UI = {}
Localog.UI = UI

local function valueOrUnknown(value)
  if value == nil then
    return "unknown"
  end
  if type(value) == "boolean" then
    return value and "true" or "false"
  end

  return tostring(value)
end

local function restrictionSummary(states)
  if not states then
    return "unavailable"
  end

  return table.concat({
    "combat:" .. valueOrUnknown(states.combat),
    "encounter:" .. valueOrUnknown(states.encounter),
    "challenge_mode:" .. valueOrUnknown(states.challengeMode),
    "pvp_match:" .. valueOrUnknown(states.pvpMatch),
    "map:" .. valueOrUnknown(states.map),
    "chat:" .. valueOrUnknown(states.chat),
  }, ",")
end

local function checkLabel(value, enabledText, disabledText)
  if value == true then
    return "|cff40c040OK|r  " .. enabledText
  end
  if value == false then
    return "|cffff5050NO|r  " .. disabledText
  end

  return "|cffffc040--|r  Unknown"
end

local function setButtonEnabled(button, enabled)
  if enabled then
    button:Enable()
  else
    button:Disable()
  end
end

local function getLoggingCheck(session)
  if session.loggingActive == nil then
    return "|cffffc040--|r  Combat logging unknown"
  end
  if session.loggingActive then
    if session.loggingOwned then
      return "|cff40c040OK|r  Combat logging on (owned by this session)"
    end
    if session.loggingWasPreexisting then
      return "|cff40c040OK|r  Combat logging on (pre-existing; will not stop)"
    end
    return "|cffffc040--|r  Combat logging on (ownership unknown; will not stop)"
  end
  if session.state == "ready" and session.loggingStartedBySession then
    return "|cff40c040OK|r  Combat logging off (owned stop confirmed)"
  end

  return "|cffff5050NO|r  Combat logging off"
end

function Localog:BuildEvidenceText()
  local probe = self.probe
  local session = self.session
  local context = probe.context or self:GetClientContext()
  local enums = self:GetRestrictionEnums()
  local lines = {
    "Localog Companion CA-01 evidence",
    "addon_version=" .. valueOrUnknown(context.addonVersion),
    "client_version=" .. valueOrUnknown(context.clientVersion),
    "client_build=" .. valueOrUnknown(context.clientBuild),
    "client_toc=" .. valueOrUnknown(context.clientToc),
    "project_id=" .. valueOrUnknown(context.projectID),
    "map_id=" .. valueOrUnknown(context.mapID),
    "session_state=" .. valueOrUnknown(session.state),
    "session_issue=" .. valueOrUnknown(session.issue or "none"),
    "advanced_logging=" .. valueOrUnknown(session.advancedLogging),
    "logging_active=" .. valueOrUnknown(session.loggingActive),
    "logging_owned=" .. valueOrUnknown(session.loggingOwned),
    "logging_started_by_session=" .. valueOrUnknown(session.loggingStartedBySession),
    "logging_was_preexisting=" .. valueOrUnknown(session.loggingWasPreexisting),
    "logging_ownership_unknown=" .. valueOrUnknown(session.loggingOwnershipUnknown),
    "logging_retry_seconds=" .. valueOrUnknown(self:GetLoggingRetrySeconds()),
    "simc_public_api=" .. valueOrUnknown(session.simcPublicAPI),
    "armed_at=" .. valueOrUnknown(probe.armedAt),
    "armed_restrictions=" .. restrictionSummary(probe.armedRestrictions),
  }

  if enums then
    lines[#lines + 1] = table.concat({
      "restriction_type_enums=",
      "combat:" .. valueOrUnknown(enums.type.combat),
      ",encounter:" .. valueOrUnknown(enums.type.encounter),
      ",challenge_mode:" .. valueOrUnknown(enums.type.challengeMode),
      ",pvp_match:" .. valueOrUnknown(enums.type.pvpMatch),
      ",map:" .. valueOrUnknown(enums.type.map),
      ",chat:" .. valueOrUnknown(enums.type.chat),
    })
    lines[#lines + 1] = table.concat({
      "restriction_state_enums=",
      "inactive:" .. valueOrUnknown(enums.state.inactive),
      ",activating:" .. valueOrUnknown(enums.state.activating),
      ",active:" .. valueOrUnknown(enums.state.active),
    })
  else
    lines[#lines + 1] = "restriction_enums=unavailable"
  end

  for _, event in ipairs(probe.events or {}) do
    lines[#lines + 1] = table.concat({
      "event=",
      valueOrUnknown(event.sequence),
      ",elapsed_ms:",
      valueOrUnknown(event.elapsedMs),
      ",type:",
      valueOrUnknown(event.restrictionType),
      ",event_state:",
      valueOrUnknown(event.eventState),
      ",observed_state:",
      valueOrUnknown(event.observedState),
    })
  end

  local result = probe.result
  if not result then
    lines[#lines + 1] = "capture_status=pending"
    return table.concat(lines, "\n")
  end

  lines[#lines + 1] = "capture_status=" .. valueOrUnknown(result.status)
  lines[#lines + 1] = "capture_reason=" .. (result.reason or "none")
  lines[#lines + 1] = "captured_at=" .. valueOrUnknown(result.capturedAt)
  lines[#lines + 1] = "should_auras_be_secret=" .. valueOrUnknown(result.shouldAurasBeSecret)
  lines[#lines + 1] = "readable_auras=" .. valueOrUnknown(result.auras and #result.auras or 0)
  lines[#lines + 1] = "skipped_secret=" .. valueOrUnknown(result.skippedSecret)
  lines[#lines + 1] = "skipped_invalid=" .. valueOrUnknown(result.skippedInvalid)
  lines[#lines + 1] = "terminator_index=" .. valueOrUnknown(result.terminatorIndex)
  lines[#lines + 1] = "failed_index=" .. valueOrUnknown(result.failedIndex or "none")
  lines[#lines + 1] = "capture_elapsed_ms=" .. valueOrUnknown(result.elapsedMs)
  lines[#lines + 1] = "capture_restrictions=" .. restrictionSummary(result.restrictions)
  lines[#lines + 1] = "in_combat_lockdown_during_capture="
    .. valueOrUnknown(result.inCombatLockdown)

  return table.concat(lines, "\n")
end

local function createEvidenceFrame()
  local frame = CreateFrame("Frame", "LocalogCompanionEvidenceFrame", UIParent, "BackdropTemplate")
  frame:SetSize(620, 460)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Localog CA-01 evidence")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, -48)
  scroll:SetPoint("BOTTOMRIGHT", -34, 18)

  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(550)
  editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  scroll:SetScrollChild(editBox)

  frame.editBox = editBox
  frame:Hide()
  return frame
end

local function getStatusText(session, retrySeconds)
  if session.state == "idle" then
    return "Ready to configure advanced logging and record one target-dummy attempt."
  end
  if session.state == "starting" then
    return "Checking the client, SimulationCraft, and combat logging..."
  end
  if session.state == "armed" then
    if session.loggingOwnershipUnknown then
      return "Armed. Logging is active but ownership is unknown, so Localog will leave it on. Begin combat."
    end
    if session.loggingWasPreexisting then
      return "Armed. Combat logging was already on, so Localog will leave it on. Begin combat."
    end
    return "Armed. Localog started combat logging. Begin your target-dummy attempt."
  end
  if session.state == "captured" then
    if session.issue then
      return "The pull-boundary snapshot was unavailable. Finish combat so logging can be handled safely."
    end
    return "Snapshot captured. Finish combat; owned logging will stop after restrictions clear."
  end
  if session.state == "stopping" then
    if session.retryAction == "stop" then
      if retrySeconds > 0 then
        return string.format(
          "Logging stop is not confirmed. Retry is available in %d seconds, or dismiss the session and stop logging manually.",
          retrySeconds
        )
      end
      return "Logging stop is not confirmed. Use Stop combat logging to retry."
    end
    return "Restrictions are still active. Finish combat before owned logging can be stopped."
  end
  if session.state == "ready" then
    if session.loggingOwnershipUnknown then
      return "Capture ready. Combat logging ownership was unknown, so Localog left it on."
    end
    if session.loggingWasPreexisting then
      return "Capture ready. Pre-existing combat logging remains on. Combined export arrives in CA-02/CA-03."
    end
    return "Capture ready and owned combat logging is off. Combined export arrives in CA-02/CA-03."
  end

  if retrySeconds > 0 then
    if session.loggingOwnershipUnknown then
      return string.format(
        "Logging ownership is unknown (%s). Retry in %d seconds; Localog will not stop an unowned logger.",
        valueOrUnknown(session.issue),
        retrySeconds
      )
    end
    return string.format(
      "Preflight is limited (%s). Retry in %d seconds or dismiss the session.",
      valueOrUnknown(session.issue),
      retrySeconds
    )
  end
  if session.retryAction == "reset" then
    return "Capture unavailable (" .. valueOrUnknown(session.issue) .. "). Reset and try a new attempt."
  end
  return "Preflight is limited (" .. valueOrUnknown(session.issue) .. "). Retry when ready."
end

function UI:Initialize()
  local frame = CreateFrame("Frame", "LocalogCompanionFrame", UIParent, "BackdropTemplate")
  frame:SetSize(460, 330)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Localog companion")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local state = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  state:SetPoint("TOPLEFT", 18, -48)
  state:SetPoint("TOPRIGHT", -18, -48)
  state:SetJustifyH("LEFT")

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  status:SetPoint("TOPLEFT", 18, -76)
  status:SetPoint("TOPRIGHT", -18, -76)
  status:SetJustifyH("LEFT")
  status:SetJustifyV("TOP")
  status:SetHeight(70)

  local checks = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  checks:SetPoint("TOPLEFT", 18, -154)
  checks:SetPoint("TOPRIGHT", -18, -154)
  checks:SetJustifyH("LEFT")
  checks:SetJustifyV("TOP")
  checks:SetHeight(80)

  local primary = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  primary:SetSize(190, 28)
  primary:SetPoint("BOTTOMLEFT", 18, 18)
  primary:SetScript("OnClick", function()
    local session = Localog.session
    if session.state == "idle" then
      Localog:StartPracticeCapture()
    elseif session.state == "armed" or session.state == "captured" then
      Localog:CancelSession()
    elseif session.state == "ready" then
      Localog:StartPracticeCapture()
    elseif session.state == "stopping" then
      Localog:RetryStop()
    elseif session.state == "limited" then
      if session.retryAction == "reset" then
        Localog:ResetSession()
      else
        Localog:RetryPreflight()
      end
    end
  end)

  local evidence = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  evidence:SetSize(110, 28)
  evidence:SetPoint("BOTTOMRIGHT", -18, 18)
  evidence:SetText("Copy evidence")
  evidence:SetScript("OnClick", function()
    Localog:ShowEvidence()
  end)

  local dismiss = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  dismiss:SetSize(110, 28)
  dismiss:SetPoint("RIGHT", evidence, "LEFT", -8, 0)
  dismiss:SetText("Dismiss")
  dismiss:SetScript("OnClick", function()
    Localog:ResetSession()
  end)

  frame:SetScript("OnUpdate", function(_, elapsed)
    UI.refreshElapsed = (UI.refreshElapsed or 0) + elapsed
    if UI.refreshElapsed >= 0.25 then
      UI.refreshElapsed = 0
      if Localog.session.retryAt then
        UI:Refresh()
      end
    end
  end)

  frame.state = state
  frame.status = status
  frame.checks = checks
  frame.primary = primary
  frame.dismiss = dismiss
  self.frame = frame
  self.evidenceFrame = createEvidenceFrame()
  self:Refresh()
  frame:Hide()
end

function UI:Refresh()
  if not self.frame then
    return
  end

  local session = Localog.session
  local probe = Localog.probe
  local retrySeconds = Localog:GetLoggingRetrySeconds()
  self.frame.state:SetText("State: " .. string.upper(session.state))
  self.frame.status:SetText(getStatusText(session, retrySeconds))

  local snapshotReady = probe.result ~= nil
    and (probe.result.status == "complete" or probe.result.status == "partial")
  self.frame.checks:SetText(table.concat({
    checkLabel(session.advancedLogging, "Advanced logging enabled", "Advanced logging disabled"),
    getLoggingCheck(session),
    checkLabel(snapshotReady, "Pull-boundary snapshot captured", "Snapshot not captured"),
    checkLabel(session.simcPublicAPI, "SimulationCraft API available", "SimulationCraft API unavailable"),
  }, "\n"))

  self.frame.dismiss:Hide()
  if session.state == "idle" then
    self.frame.primary:SetText("Start practice capture")
    setButtonEnabled(self.frame.primary, true)
  elseif session.state == "starting" then
    self.frame.primary:SetText("Starting...")
    setButtonEnabled(self.frame.primary, false)
  elseif session.state == "armed" then
    self.frame.primary:SetText("Cancel capture")
    setButtonEnabled(self.frame.primary, true)
  elseif session.state == "captured" then
    self.frame.primary:SetText("Cancel after combat")
    setButtonEnabled(self.frame.primary, true)
  elseif session.state == "stopping" then
    self.frame.primary:SetText(
      session.retryAction == "stop" and "Stop combat logging" or "Waiting for combat..."
    )
    setButtonEnabled(self.frame.primary, retrySeconds == 0 and session.retryAction == "stop")
    if session.retryAction == "stop" then
      self.frame.dismiss:Show()
    end
  elseif session.state == "ready" then
    self.frame.primary:SetText("Start another capture")
    setButtonEnabled(self.frame.primary, true)
  else
    self.frame.dismiss:Show()
    if session.retryAction == "reset" then
      self.frame.primary:SetText("Reset capture")
      setButtonEnabled(self.frame.primary, true)
    else
      self.frame.primary:SetText(retrySeconds > 0 and "Retry preflight (wait)" or "Retry preflight")
      setButtonEnabled(self.frame.primary, retrySeconds == 0)
    end
  end
end

function UI:Show()
  if self.frame then
    self:Refresh()
    self.frame:Show()
  end
end

function UI:ShowEvidence(text)
  if not self.evidenceFrame then
    return
  end

  local _, lineBreaks = string.gsub(text, "\n", "")
  self.evidenceFrame.editBox:SetHeight(math.max(380, (lineBreaks + 1) * 15))
  self.evidenceFrame.editBox:SetText(text)
  self.evidenceFrame:Show()
  self.evidenceFrame.editBox:SetFocus()
  self.evidenceFrame.editBox:HighlightText()
end
