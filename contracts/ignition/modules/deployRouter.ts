// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { keccak256, toUtf8Bytes } from "ethers";

const TOKEN = "0x0000000000000000000000000000000000000000";

const LockModule = buildModule("DeployRouter", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  const token = m.getParameter("token", TOKEN);

  // Calculate role hashes
  const NAMESPACE_ADMIN_ROLE = keccak256(toUtf8Bytes("NAMESPACE_ADMIN_ROLE"));
  const OWNER_ROLE = keccak256(toUtf8Bytes("OWNER_ROLE"));

  // Deploy NamespaceManager, init with owner
  const namespaceManager = m.contract("NamespaceManager", [], { id: "namespaceManager" });
  m.call(namespaceManager, "initialize", [owner]);

  // Deploy NodeManagerUpgradeable and init, minStakeAmount = 1
  const nodeManager = m.contract("NodeManagerUpgradeable", [], { id: "nodeManager" });
  m.call(nodeManager, "initialize", [namespaceManager, 1]);

  // Deploy SessionManagerUpgradeable init with token, fee target to be self
  const sessionManager = m.contract("SessionManagerUpgradeable", [], { id: "sessionManager" });
  m.call(sessionManager, "initialize", [token, sessionManager, owner]);

  // Deploy RouterUpgradeable
  const router = m.contract("RouterUpgradeable", [], { id: "router" });
  m.call(router, "initialize", [1, owner]); // minAuthoredStake = 1

  // router.setDependencies
  m.call(router, "setDependencies", [nodeManager, sessionManager, namespaceManager]);

  // grantRole, NAMESPACE_ADMIN_ROLE, to router and OWNER_ROLE to owner for both router and nodeManager
  m.call(router, "grantRole", [NAMESPACE_ADMIN_ROLE, router]);
  m.call(router, "grantRole", [OWNER_ROLE, owner]);
  m.call(nodeManager, "grantRole", [OWNER_ROLE, owner]);

  // sessionManager.addDtnContracts([router.target]);
  m.call(sessionManager, "addDtnContracts", [[router]]);

  // namespaceManager.addDtnContracts([router.target, sessionManager.target, nodeManager.target]);
  m.call(namespaceManager, "addDtnContracts", [[router, sessionManager, nodeManager]]);

  return { router, namespaceManager, nodeManager, sessionManager };
});

export default LockModule;
