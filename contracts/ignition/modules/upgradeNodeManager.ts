// This setup uses Hardhat Ignition to upgrade the NodeManagerUpgradeable contract.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UpgradeNodeManagerModule = buildModule("UpgradeNodeManager", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  
  // Deploy new NodeManagerUpgradeable implementation
  const newNodeManager = m.contract("NodeManagerUpgradeable", [], { id: "newNodeManager" });
  
  // Get existing node manager proxy address
  const existingNodeManagerAddress = m.getParameter("existingNodeManagerAddress");
  const existingNodeManager = m.contractAt("NodeManagerUpgradeable", existingNodeManagerAddress, { id: "existingNodeManager" });
  
  // Upgrade the node manager proxy to new implementation
  m.call(existingNodeManager, "upgradeTo", [newNodeManager]);
  
  // Re-initialize if needed (only if the new version requires it)
  // Note: UUPS contracts typically don't need re-initialization after upgrade
  // Uncomment the following lines if your new version requires initialization:
  // const namespaceManagerAddress = m.getParameter("namespaceManagerAddress");
  // m.call(existingNodeManager, "initialize", [namespaceManagerAddress, 1]); // minStakeAmount = 1
  
  return { newNodeManager, existingNodeManager };
});

export default UpgradeNodeManagerModule; 