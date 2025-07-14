// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { keccak256, toUtf8Bytes, ZeroAddress } from "ethers";

const TOKEN = "0x0000000000000000000000000000000000000000";

const LockModule = buildModule("DeployRouter", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));
  const token = m.getParameter("token", TOKEN);
  console.log("owner", owner.defaultValue);

  // Calculate role hashes
  const NAMESPACE_ADMIN_ROLE = keccak256(toUtf8Bytes("NAMESPACE_ADMIN_ROLE"));

  // Deploy NamespaceManager implementation and proxy
  const namespaceManagerImpl = m.contract("NamespaceManager", [], { id: "namespaceManagerImpl" });
  let namespaceManagerInitCalldata = m.encodeFunctionCall(namespaceManagerImpl, "initialize", [owner]);
  const namespaceManagerProxy = m.contract("ERC1967Proxy", [namespaceManagerImpl, namespaceManagerInitCalldata], { id: "namespaceManagerProxy" });
  const namespaceManager = m.contractAt("NamespaceManager", namespaceManagerProxy, { id: "namespaceManager" });

  // Deploy ModelManagerUpgradeable implementation and proxy
  const modelManagerImpl = m.contract("ModelManagerUpgradeable", [], { id: "modelManagerImpl" });
  let modelManagerInitCalldata = m.encodeFunctionCall(modelManagerImpl, "initialize", [owner]);
  const modelManagerProxy = m.contract("ERC1967Proxy", [modelManagerImpl, modelManagerInitCalldata], { id: "modelManagerProxy" });
  const modelManager = m.contractAt("ModelManagerUpgradeable", modelManagerProxy, { id: "modelManager" });

  // Deploy NodeManagerUpgradeable implementation and proxy, minStakeAmount = 1
  const nodeManagerImpl = m.contract("NodeManagerUpgradeable", [], { id: "nodeManagerImpl" });
  let nodeManagerInitCalldata = m.encodeFunctionCall(nodeManagerImpl, "initialize", [namespaceManager, 1]);
  const nodeManagerProxy = m.contract("ERC1967Proxy", [nodeManagerImpl, nodeManagerInitCalldata], { id: "nodeManagerProxy" });
  const nodeManager = m.contractAt("NodeManagerUpgradeable", nodeManagerProxy, { id: "nodeManager" });

  // Deploy SessionManagerUpgradeable implementation and proxy
  const sessionManagerImpl = m.contract("SessionManagerUpgradeable", [], { id: "sessionManagerImpl" });
  let sessionManagerInitCalldata = m.encodeFunctionCall(sessionManagerImpl, "initialize", [token, ZeroAddress, owner]);
  const sessionManagerProxy = m.contract("ERC1967Proxy", [sessionManagerImpl, sessionManagerInitCalldata], { id: "sessionManagerProxy" });
  const sessionManager = m.contractAt("SessionManagerUpgradeable", sessionManagerProxy, { id: "sessionManager" });
  m.call(sessionManager, "setFeeTarget", [sessionManager], { id: "sessionManagerSetFeeTarget" });
  
  // Deploy RouterUpgradeable implementation and proxy
  const routerImpl = m.contract("RouterUpgradeable", [], { id: "routerImpl" });
  let routerInitCalldata = m.encodeFunctionCall(routerImpl, "initialize", [1, owner]); // minAuthoredStake = 1
  const routerProxy = m.contract("ERC1967Proxy", [routerImpl, routerInitCalldata], { id: "routerProxy" });
  const router = m.contractAt("RouterUpgradeable", routerProxy, { id: "router" });

  // Set dependencies for all contracts (after initialization)
  m.call(router, "setDependencies", [nodeManager, sessionManager, modelManager, namespaceManager], { id: "routerSetDeps" });
  m.call(modelManager, "setRouter", [router], { id: "modelManagerSetRouter" });

  // sessionManager.addDtnContracts([router.target]);
  m.call(sessionManager, "addDtnContracts", [[router]], { id: "sessionManagerAddDtnContracts" });

  // namespaceManager.addDtnContracts([router.target, sessionManager.target, nodeManager.target]);
  m.call(namespaceManager, "addDtnContracts", [[router, sessionManager, nodeManager]], { id: "namespaceManagerAddDtnContracts" });

  return { router, namespaceManager, nodeManager, sessionManager, modelManager };
});

export default LockModule;
