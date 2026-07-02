import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const GoldSignalAgentModule = buildModule("GoldSignalAgentModule", (m) => {
  const goldSignalAgent = m.contract("GoldSignalAgent", [], {
    value: m.getParameter("initialValue", 0n),
  });
  return { goldSignalAgent };
});

export default GoldSignalAgentModule;
