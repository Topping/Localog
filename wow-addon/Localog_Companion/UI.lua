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

local function getSnapshotCheck(result)
  if not result then
    return "|cffff5050NO|r  Snapshot not captured"
  end
  if result.status == "complete" then
    return string.format("|cff40c040OK|r  Complete snapshot (%d auras)", #result.auras)
  end
  if result.status == "partial" then
    return string.format(
      "|cffffc040--|r  Partial snapshot (%d auras; %d secret, %d invalid skipped)",
      #result.auras,
      result.skippedSecret,
      result.skippedInvalid
    )
  end

  return "|cffff5050NO|r  Snapshot unavailable"
end

function Localog:BuildEvidenceText()
  local probe = self.probe
  local session = self.session
  local integration = self.SimcIntegration
  integration:RefreshAvailability()
  local context = probe.context or self:GetClientContext()
  local enums = self:GetRestrictionEnums()
  local lines = {
    "Localog Companion CA-06 evidence",
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
    "session_notice=" .. valueOrUnknown(session.notice or "none"),
    "snapshot_age_seconds=" .. valueOrUnknown(self:GetSnapshotAgeSeconds()),
    "simc_addon_version=" .. valueOrUnknown(integration.simcVersion),
    "simc_minimum_tested_version=" .. valueOrUnknown(integration.minimumTestedVersion),
    "simc_public_api=" .. valueOrUnknown(integration.publicApiAvailable),
    "simc_convenience_hooked=" .. valueOrUnknown(integration.convenienceHooked),
    "simc_convenience_status=" .. valueOrUnknown(integration.convenienceStatus),
    "simc_convenience_issue=" .. valueOrUnknown(integration.convenienceIssue or "none"),
    "simc_stable_export_status=" .. valueOrUnknown(integration.stableStatus),
    "simc_stable_export_issue=" .. valueOrUnknown(integration.stableIssue or "none"),
    "simc_stable_export_count=" .. valueOrUnknown(integration.stableExportCount),
    "simc_convenience_export_count=" .. valueOrUnknown(integration.convenienceExportCount),
    "simc_convenience_distinct_outputs="
      .. valueOrUnknown(integration.convenienceDistinctOutputCount),
    "armed_at=" .. valueOrUnknown(probe.armedAt),
    "armed_restrictions=" .. restrictionSummary(probe.armedRestrictions),
  }

  local stableMetrics = integration.stableMetrics
  lines[#lines + 1] = "simc_stable_input_checksum_verified="
    .. valueOrUnknown(stableMetrics and stableMetrics.inputChecksumVerified)
  lines[#lines + 1] = "simc_stable_original_bytes="
    .. valueOrUnknown(stableMetrics and stableMetrics.originalBytes)
  lines[#lines + 1] = "simc_stable_snapshot_bytes="
    .. valueOrUnknown(stableMetrics and stableMetrics.snapshotBytes)
  lines[#lines + 1] = "simc_stable_combined_bytes="
    .. valueOrUnknown(stableMetrics and stableMetrics.combinedBytes)
  lines[#lines + 1] = "simc_stable_terminal_checksum_lines="
    .. valueOrUnknown(stableMetrics and stableMetrics.terminalChecksumLines)
  lines[#lines + 1] = "simc_stable_companion_blocks="
    .. valueOrUnknown(stableMetrics and stableMetrics.companionBlocks)
  lines[#lines + 1] = "simc_stable_snapshot_before_checksum="
    .. valueOrUnknown(stableMetrics and stableMetrics.snapshotImmediatelyBeforeChecksum)
  lines[#lines + 1] = "simc_stable_added_lines_comments="
    .. valueOrUnknown(stableMetrics and stableMetrics.addedLinesAreComments)
  lines[#lines + 1] = "simc_stable_output_checksum="
    .. valueOrUnknown(stableMetrics and stableMetrics.outputChecksum)

  local convenienceMetrics = integration.convenienceMetrics
  lines[#lines + 1] = "simc_convenience_input_checksum_verified="
    .. valueOrUnknown(convenienceMetrics and convenienceMetrics.inputChecksumVerified)
  lines[#lines + 1] = "simc_convenience_combined_bytes="
    .. valueOrUnknown(convenienceMetrics and convenienceMetrics.combinedBytes)
  lines[#lines + 1] = "simc_convenience_terminal_checksum_lines="
    .. valueOrUnknown(convenienceMetrics and convenienceMetrics.terminalChecksumLines)
  lines[#lines + 1] = "simc_convenience_companion_blocks="
    .. valueOrUnknown(convenienceMetrics and convenienceMetrics.companionBlocks)

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
  lines[#lines + 1] = "duplicates_collapsed=" .. valueOrUnknown(result.duplicatesCollapsed)
  lines[#lines + 1] = "skipped_secret=" .. valueOrUnknown(result.skippedSecret)
  lines[#lines + 1] = "skipped_invalid=" .. valueOrUnknown(result.skippedInvalid)
  lines[#lines + 1] = "terminator_index=" .. valueOrUnknown(result.terminatorIndex)
  lines[#lines + 1] = "failed_index=" .. valueOrUnknown(result.failedIndex or "none")
  lines[#lines + 1] = "capture_elapsed_ms=" .. valueOrUnknown(result.elapsedMs)
  lines[#lines + 1] = "capture_restrictions=" .. restrictionSummary(result.restrictions)
  lines[#lines + 1] = "in_combat_lockdown_during_capture="
    .. valueOrUnknown(result.inCombatLockdown)
  lines[#lines + 1] = "protocol_schema=" .. valueOrUnknown(Localog.Protocol.schema)
  lines[#lines + 1] = "protocol_serialized=" .. valueOrUnknown(result.protocolBlock ~= nil)
  lines[#lines + 1] = "protocol_bytes=" .. valueOrUnknown(result.protocolBytes)

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
  title:SetText("Localog CA-06 evidence")

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
  frame.title = title
  frame:Hide()
  return frame
end

local function getStatusText(session, retrySeconds, snapshotAgeSeconds)
  if session.state == "idle" then
    if session.notice == "capture_canceled_before_combat" then
      return "Capture canceled before combat. No pull snapshot was kept. Start again when ready."
    end
    if session.notice == "capture_canceled" then
      return "Capture canceled. Its pull snapshot was discarded. Start again when ready."
    end
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
    if Localog.probe.result and Localog.probe.result.status == "partial" then
      return "A partial pull snapshot was captured. Finish combat to review the exact skipped counts."
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
    local result = Localog.probe.result
    local integration = Localog.SimcIntegration
    if result and result.status == "partial" then
      if not integration.publicApiAvailable then
        return "Partial snapshot ready, but combined export is unavailable. Update SimulationCraft."
      end
    end
    if not integration.publicApiAvailable then
      return "Snapshot ready, but combined export is unavailable. Update SimulationCraft; the raw snapshot remains available with /localog snapshot."
    end
    if integration.stableStatus == "failed" then
      return "Combined export blocked ("
        .. valueOrUnknown(integration.stableIssue)
        .. "). Update SimulationCraft and retry."
    end
    if snapshotAgeSeconds and snapshotAgeSeconds >= 900 then
      return string.format(
        "This snapshot is %d minutes old. It will still export; use it for its matching attempt or choose New capture.",
        math.floor(snapshotAgeSeconds / 60)
      )
    end
    if integration.convenienceStatus == "failed" then
      return "/simc was left unchanged ("
        .. valueOrUnknown(integration.convenienceIssue)
        .. "). Copy for Localog remains available."
    end
    if not integration.convenienceHooked then
      return "Combined export is ready through Copy for Localog. /simc compatibility is unavailable and /simc will remain unchanged."
    end
    if result and result.status == "partial" then
      return string.format(
        "Partial combined export ready: %d readable auras; %d secret and %d invalid entries skipped. Copy for Localog or /simc.",
        #result.auras,
        result.skippedSecret,
        result.skippedInvalid
      )
    end
    if session.loggingOwnershipUnknown then
      return "Combined export ready. Logging ownership was unknown, so Localog left it on. Copy it, then paste it into Localog's target-dummy import."
    end
    if session.loggingWasPreexisting then
      return "Combined export ready. Pre-existing combat logging remains on. Copy it, then paste it into Localog's target-dummy import."
    end
    return "Combined export ready and owned combat logging is off. Copy it, then paste it into Localog's target-dummy import."
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
  checks:SetHeight(96)

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
      Localog:ShowCombinedExport()
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
    if Localog.session.state == "ready" then
      Localog:StartPracticeCapture()
    else
      Localog:ResetSession()
    end
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
  local integration = Localog.SimcIntegration
  integration:RefreshAvailability()
  session.simcPublicAPI = integration.publicApiAvailable
  local retrySeconds = Localog:GetLoggingRetrySeconds()
  self.frame.state:SetText("State: " .. string.upper(session.state))
  self.frame.status:SetText(
    getStatusText(session, retrySeconds, Localog:GetSnapshotAgeSeconds())
  )

  self.frame.checks:SetText(table.concat({
    checkLabel(session.advancedLogging, "Advanced logging enabled", "Advanced logging disabled"),
    getLoggingCheck(session),
    getSnapshotCheck(probe.result),
    checkLabel(
      integration.publicApiAvailable,
      "SimulationCraft public export API available",
      "SimulationCraft public export API unavailable"
    ),
    checkLabel(
      integration.convenienceHooked,
      "/simc convenience hook installed",
      "/simc left unchanged; use Copy for Localog"
    ),
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
    self.frame.primary:SetText(
      integration.publicApiAvailable and "Copy for Localog" or "Export unavailable"
    )
    setButtonEnabled(self.frame.primary, integration.publicApiAvailable)
    self.frame.dismiss:SetText("New capture")
    self.frame.dismiss:Show()
  else
    self.frame.dismiss:SetText("Dismiss")
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

function UI:ShowText(text, title)
  if not self.evidenceFrame then
    return
  end

  self.evidenceFrame.title:SetText(title)
  local _, lineBreaks = string.gsub(text, "\n", "")
  self.evidenceFrame.editBox:SetHeight(math.max(380, (lineBreaks + 1) * 15))
  self.evidenceFrame.editBox:SetText(text)
  self.evidenceFrame:Show()
  self.evidenceFrame.editBox:SetFocus()
  self.evidenceFrame.editBox:HighlightText()
end

function UI:ShowEvidence(text)
  self:ShowText(text, "Localog CA-06 evidence")
end

function UI:ShowSnapshot(text)
  self:ShowText(text, "Localog protocol v1 snapshot")
end

function UI:ShowExport(text)
  self:ShowText(text, "SimulationCraft profile with Localog snapshot")
end
