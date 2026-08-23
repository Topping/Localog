local _, Localog = ...

local UI = {}
Localog.UI = UI

local function setButtonEnabled(button, enabled)
  if enabled then
    button:Enable()
  else
    button:Disable()
  end
end

local function createTextFrame()
  local frame = CreateFrame("Frame", "LocalogCompanionExportFrame", UIParent, "BackdropTemplate")
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
  title:SetText("Localog Companion export")

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
    return "Press Start before entering combat to capture the auras active when your practice fight begins."
  end
  if session.state == "starting" then
    return "Getting ready for your practice attempt..."
  end
  if session.state == "armed" then
    return "Start fighting the target dummy. Localog will finish automatically when combat ends."
  end
  if session.state == "captured" then
    if session.issue then
      return "Localog could not capture the pull-time auras. Leave combat to finish safely, then try a new capture."
    end
    if Localog.probe.result and Localog.probe.result.status == "partial" then
      return "Your practice attempt is being recorded. Some hidden auras could not be included. Leave combat when finished."
    end
    return "Your practice attempt is being recorded. Leave combat when finished; Localog will complete it automatically."
  end
  if session.state == "stopping" then
    if session.retryAction == "stop" then
      if retrySeconds > 0 then
        return string.format(
          "Localog could not confirm that combat logging stopped. Try again in %d seconds, or dismiss and stop it manually.",
          retrySeconds
        )
      end
      return "Localog could not confirm that combat logging stopped. Use Stop combat logging to try again."
    end
    return "Leave combat to finish the capture. Localog will complete it automatically."
  end
  if session.state == "ready" then
    local result = Localog.probe.result
    local integration = Localog.SimcIntegration
    if not integration.publicApiAvailable then
      return "Your capture is ready, but the SimulationCraft addon is missing or out of date. Enable or update it, then reload the game."
    end
    if integration.stableStatus == "failed" then
      return "Localog could not create the export. Update the SimulationCraft addon, then try Copy for Localog again."
    end
    if snapshotAgeSeconds and snapshotAgeSeconds >= 900 then
      return string.format(
        "This snapshot is %d minutes old. It will still export; use it for its matching attempt or choose New capture.",
        math.floor(snapshotAgeSeconds / 60)
      )
    end
    if result and result.status == "partial" then
      return "Your export is ready. Some hidden auras could not be included. Copy it, then paste it into Localog and select the matching attempt."
    end
    return "Your export is ready. Copy it, then paste it into Localog and select the matching attempt."
  end

  if retrySeconds > 0 then
    return string.format(
      "World of Warcraft is temporarily limiting combat-log changes. Try again in %d seconds.",
      retrySeconds
    )
  end
  if session.retryAction == "reset" then
    return "No usable pull-time aura snapshot was captured. Reset and try a new practice attempt."
  end
  if session.issue and string.find(session.issue, "restricted_", 1, true) == 1 then
    return "Leave combat or other restricted activity, then try again."
  end
  if session.issue and string.find(session.issue, "advanced_logging", 1, true) then
    return "Localog could not enable advanced logging. Leave combat, then try again."
  end
  return "Localog could not start the capture. Try again; if the problem continues, reload the game."
end

local function getStepTitle(state)
  local labels = {
    idle = "Ready to start",
    starting = "Getting ready",
    armed = "Capture armed",
    captured = "Practice attempt in progress",
    stopping = "Finishing capture",
    ready = "Ready to import",
    limited = "Action needed",
  }

  return labels[state] or "Localog Companion"
end

local function getNoticeText(session, integration)
  if not integration.publicApiAvailable then
    return "|cffff6060SimulationCraft is required to create the final export. Enable or update it, then reload the game.|r"
  end
  if session.state == "ready" and Localog.probe.result and Localog.probe.result.status == "partial" then
    return "|cffffc040Some hidden auras were skipped. The export can still be analyzed.|r"
  end

  return ""
end

function UI:Initialize()
  local frame = CreateFrame("Frame", "LocalogCompanionFrame", UIParent, "BackdropTemplate")
  frame:SetSize(460, 270)
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

  local notice = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  notice:SetPoint("TOPLEFT", 18, -158)
  notice:SetPoint("TOPRIGHT", -18, -158)
  notice:SetJustifyH("LEFT")
  notice:SetJustifyV("TOP")
  notice:SetHeight(52)

  local primary = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  primary:SetSize(250, 28)
  primary:SetPoint("BOTTOMLEFT", 18, 18)
  primary:SetScript("OnClick", function()
    local session = Localog.session
    if session.state == "idle" then
      Localog:StartPracticeCapture()
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

  local dismiss = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  dismiss:SetSize(150, 28)
  dismiss:SetPoint("BOTTOMRIGHT", -18, 18)
  dismiss:SetText("Dismiss")
  dismiss:SetScript("OnClick", function()
    local state = Localog.session.state
    if state == "ready" then
      Localog:StartPracticeCapture()
    elseif state == "armed" or state == "captured" then
      Localog:CancelSession()
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
  frame.notice = notice
  frame.primary = primary
  frame.dismiss = dismiss
  self.frame = frame
  self.textFrame = createTextFrame()
  self:Refresh()
  frame:Hide()
end

function UI:Refresh()
  if not self.frame then
    return
  end

  local session = Localog.session
  local integration = Localog.SimcIntegration
  integration:RefreshAvailability()
  session.simcPublicAPI = integration.publicApiAvailable
  local retrySeconds = Localog:GetLoggingRetrySeconds()
  self.frame.state:SetText(getStepTitle(session.state))
  self.frame.status:SetText(
    getStatusText(session, retrySeconds, Localog:GetSnapshotAgeSeconds())
  )

  self.frame.notice:SetText(getNoticeText(session, integration))

  self.frame.dismiss:Hide()
  if session.state == "idle" then
    self.frame.primary:SetText("Start practice capture")
    setButtonEnabled(self.frame.primary, true)
  elseif session.state == "starting" then
    self.frame.primary:SetText("Starting...")
    setButtonEnabled(self.frame.primary, false)
  elseif session.state == "armed" then
    self.frame.primary:SetText("Capture in progress")
    setButtonEnabled(self.frame.primary, false)
    self.frame.dismiss:SetText("Abort")
    self.frame.dismiss:Show()
  elseif session.state == "captured" then
    self.frame.primary:SetText("Capture in progress")
    setButtonEnabled(self.frame.primary, false)
    self.frame.dismiss:SetText("Abort")
    self.frame.dismiss:Show()
  elseif session.state == "stopping" then
    self.frame.primary:SetText(
      session.retryAction == "stop" and "Stop combat logging" or "Finishing capture..."
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
      self.frame.primary:SetText(retrySeconds > 0 and "Retry (wait)" or "Retry")
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
  if not self.textFrame then
    return
  end

  self.textFrame.title:SetText(title)
  local _, lineBreaks = string.gsub(text, "\n", "")
  self.textFrame.editBox:SetHeight(math.max(380, (lineBreaks + 1) * 15))
  self.textFrame.editBox:SetText(text)
  self.textFrame:Show()
  self.textFrame.editBox:SetFocus()
  self.textFrame.editBox:HighlightText()
end

function UI:ShowSnapshot(text)
  self:ShowText(text, "Localog protocol v1 snapshot")
end

function UI:ShowExport(text)
  self:ShowText(text, "Localog Companion export")
end
