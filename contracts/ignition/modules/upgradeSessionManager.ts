// This setup uses Hardhat Ignition to upgrade the SessionManagerUpgradeable contract.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UpgradeSessionManagerModule = buildModule("UpgradeSessionManager", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  
  // Deploy new SessionManagerUpgradeable implementation
  const newSessionManager = m.contract("SessionManagerUpgradeable", [], { id: "newSessionManager" });
  
  // Get existing session manager proxy address
  const existingSessionManagerAddress = m.getParameter("existingSessionManagerAddress");
  const existingSessionManager = m.contractAt("SessionManagerUpgradeable", existingSessionManagerAddress, { id: "existingSessionManager" });
  
  // Upgrade the session manager proxy to new implementation
  m.call(existingSessionManager, "upgradeTo", [newSessionManager]);
  
  // Re-initialize if needed (only if the new version requires it)
  // Note: UUPS contracts typically don't need re-initialization after upgrade
  // Uncomment the following lines if your new version requires initialization:
  // const token = m.getParameter("token", "0x0000000000000000000000000000000000000000");
  // m.call(existingSessionManager, "initialize", [token, existingSessionManager, owner]);
  
  return { newSessionManager, existingSessionManager };
});

export default UpgradeSessionManagerModule; 