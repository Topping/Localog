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

function Localog:BuildEvidenceText()
  local probe = self.probe
  local context = probe.context or self:GetClientContext()
  local enums = self:GetRestrictionEnums()
  local lines = {
    "Localog Companion CA-00 evidence",
    "addon_version=" .. valueOrUnknown(context.addonVersion),
    "client_version=" .. valueOrUnknown(context.clientVersion),
    "client_build=" .. valueOrUnknown(context.clientBuild),
    "client_toc=" .. valueOrUnknown(context.clientToc),
    "project_id=" .. valueOrUnknown(context.projectID),
    "map_id=" .. valueOrUnknown(context.mapID),
    "simc_public_api=" .. valueOrUnknown(self.SimcIntegration:GetProbeStatus()),
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
  frame:SetSize(620, 420)
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
  title:SetText("Localog CA-00 evidence")

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

function UI:Initialize()
  local frame = CreateFrame("Frame", "LocalogCompanionProbeFrame", UIParent, "BackdropTemplate")
  frame:SetSize(390, 210)
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
  title:SetText("Localog companion probe")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  status:SetPoint("TOPLEFT", 18, -50)
  status:SetPoint("TOPRIGHT", -18, -50)
  status:SetJustifyH("LEFT")
  status:SetJustifyV("TOP")
  status:SetHeight(70)

  local primary = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  primary:SetSize(170, 26)
  primary:SetPoint("BOTTOMLEFT", 18, 18)
  primary:SetScript("OnClick", function()
    if Localog.probe.armed or Localog.probe.result then
      Localog:ResetProbe()
    else
      Localog:ArmProbe()
    end
  end)

  local evidence = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  evidence:SetSize(170, 26)
  evidence:SetPoint("BOTTOMRIGHT", -18, 18)
  evidence:SetText("Copy evidence")
  evidence:SetScript("OnClick", function()
    Localog:ShowEvidence()
  end)

  frame.status = status
  frame.primary = primary
  self.frame = frame
  self.evidenceFrame = createEvidenceFrame()
  self:Refresh()
  frame:Hide()
end

function UI:Refresh()
  if not self.frame then
    return
  end

  local probe = Localog.probe
  if probe.armed then
    self.frame.status:SetText(
      "Armed. Start a target-dummy pull. Aura data will be inspected synchronously when the Combat restriction begins."
    )
    self.frame.primary:SetText("Cancel probe")
  elseif probe.result then
    local result = probe.result
    if result.status == "complete" then
      self.frame.status:SetText(
        string.format("Complete: %d readable helpful auras. Copy the sanitized evidence.", #result.auras)
      )
    elseif result.status == "partial" then
      self.frame.status:SetText(string.format(
        "Partial: %d readable auras; %d secret and %d invalid entries skipped.",
        #result.auras,
        result.skippedSecret,
        result.skippedInvalid
      ))
    else
      self.frame.status:SetText(
        "Unavailable (" .. valueOrUnknown(result.reason) .. "). Copy the evidence before resetting."
      )
    end
    self.frame.primary:SetText("Reset probe")
  else
    self.frame.status:SetText(
      "Development evidence probe. Arm it out of combat, then begin a target-dummy pull. No data survives /reload."
    )
    self.frame.primary:SetText("Arm probe")
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
  self.evidenceFrame.editBox:SetHeight(math.max(340, (lineBreaks + 1) * 15))
  self.evidenceFrame.editBox:SetText(text)
  self.evidenceFrame:Show()
  self.evidenceFrame.editBox:SetFocus()
  self.evidenceFrame.editBox:HighlightText()
end
