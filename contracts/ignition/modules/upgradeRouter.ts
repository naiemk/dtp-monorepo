// This setup uses Hardhat Ignition to upgrade the RouterUpgradeable contract.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ROUTER_ADDRESS = "0x45B80f551646fDaC777A4991FbdA748Fc5A72194";

const UpgradeRouterModule = buildModule("UpgradeRouter", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  
  // Deploy new RouterUpgradeable implementation
  const newRouter = m.contract("RouterUpgradeable", [], { id: "newRouter_2" });
  
  // Get existing router proxy address
  const existingRouterAddress = m.getParameter("existingRouterAddress", ROUTER_ADDRESS);
  const existingRouter = m.contractAt("RouterUpgradeable", existingRouterAddress, { id: "existingRouter_2" });
  
  // Upgrade the router proxy to new implementation
  m.call(existingRouter, "upgradeToAndCall", [newRouter, "0x"]);
  
  // Re-initialize if needed (only if the new version requires it)
  // Note: UUPS contracts typically don't need re-initialization after upgrade
  // Uncomment the following line if your new version requires initialization:
  // m.call(existingRouter, "initialize", [1, owner]); // minAuthoredStake = 1
  
  return { newRouter, existingRouter };
});

export default UpgradeRouterModule; 