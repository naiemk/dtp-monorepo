
// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { keccak256, toUtf8Bytes } from "ethers";

const DTN_AI = "0x45B80f551646fDaC777A4991FbdA748Fc5A72194";

const LockModule = buildModule("DeployCallAi", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  const dtn_ai = m.getParameter("dtn_ai", DTN_AI);

  // Deploy NamespaceManager, init with owner
  const dtnAi = m.contract("CallAiExample", [dtn_ai], { id: "callAiExample_6" });
  return { dtnAi };
});

export default LockModule;
