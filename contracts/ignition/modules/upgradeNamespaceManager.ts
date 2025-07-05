// This setup uses Hardhat Ignition to upgrade the NamespaceManager contract.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UpgradeNamespaceManagerModule = buildModule("UpgradeNamespaceManager", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  
  // Deploy new NamespaceManager implementation
  const newNamespaceManager = m.contract("NamespaceManager", [], { id: "newNamespaceManager" });
  
  // Get existing namespace manager proxy address
  const existingNamespaceManagerAddress = m.getParameter("existingNamespaceManagerAddress");
  const existingNamespaceManager = m.contractAt("NamespaceManager", existingNamespaceManagerAddress, { id: "existingNamespaceManager" });
  
  // Upgrade the namespace manager proxy to new implementation
  m.call(existingNamespaceManager, "upgradeTo", [newNamespaceManager]);
  
  // Re-initialize if needed (only if the new version requires it)
  // Note: UUPS contracts typically don't need re-initialization after upgrade
  // Uncomment the following line if your new version requires initialization:
  // m.call(existingNamespaceManager, "initialize", [owner]);
  
  return { newNamespaceManager, existingNamespaceManager };
});

export default UpgradeNamespaceManagerModule; 