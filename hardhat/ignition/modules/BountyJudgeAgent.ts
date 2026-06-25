import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("BountyJudgeAgentModule", (m) => {
  const agent = m.contract("BountyJudgeAgent", [], {});
  return { agent };
});
