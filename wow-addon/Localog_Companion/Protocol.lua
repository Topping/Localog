local _, Localog = ...

-- Serialization is intentionally deferred to CA-02. These constants keep the
-- evidence spike aligned with the protocol limits without emitting a block.
Localog.Protocol = {
  schema = 1,
  maximumAuras = 255,
  addonVersion = "0.1.0",
}
