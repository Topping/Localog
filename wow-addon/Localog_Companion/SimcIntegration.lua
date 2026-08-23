local _, Localog = ...

-- Combined export and the isolated /simc compatibility adapter land in CA-03.
-- CA-00 only reports whether the future public integration seam is present.
Localog.SimcIntegration = {}

function Localog.SimcIntegration:GetProbeStatus()
  return SimulationcraftAPI ~= nil and type(SimulationcraftAPI.GetSimcProfile) == "function"
end
