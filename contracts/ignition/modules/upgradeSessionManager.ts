// This setup uses Hardhat Ignition to upgrade the SessionManagerUpgradeable contract.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ZeroAddress } from "ethers";

const SESSION_MANAGER_ADDRESS = "0x8aaEb07881eb18183fFE98afF10b55f8e7318536";

const ROUTER_ADDRESS = "0x45B80f551646fDaC777A4991FbdA748Fc5A72194";
const TOKEN_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const NODE_MANAGER_ADDRESS = "0xa579c301bB320276b85Ec12C6693eCf9f493146B";
const MODEL_MANAGER_ADDRESS = "0x27d0BAEcb181c3bB1B5850049092D40eE7b1fE3d";

const UpgradeSessionManagerModule = buildModule("UpgradeSessionManager", (m) => {
  const owner = m.getParameter("owner", m.getAccount(0));


    // Deploy SessionManagerUpgradeable implementation and proxy
    const sessionManagerImpl = m.contract("SessionManagerUpgradeable", [], { id: "sessionManagerImpl2" });
    let sessionManagerInitCalldata = m.encodeFunctionCall(sessionManagerImpl, "initialize", [TOKEN_ADDRESS, ZeroAddress, owner]);
    const sessionManagerProxy = m.contract("ERC1967Proxy", [sessionManagerImpl, sessionManagerInitCalldata], { id: "sessionManagerProxyNewVersionUpgradeable" });
    const sessionManager = m.contractAt("SessionManagerUpgradeable", sessionManagerProxy, { id: "sessionManagerTmp1" });
    m.call(sessionManager, "setFeeTarget", [sessionManager], { id: "sessionManagerSetFeeTargetTmp1" });

    const router = m.contractAt("RouterUpgradeable", ROUTER_ADDRESS, { id: "router" });
    m.call(router, "setDependencies", [NODE_MANAGER_ADDRESS, sessionManager, MODEL_MANAGER_ADDRESS], { id: "routerSetDepsTmp1" });

    return { sessionManager };
  
  // // Deploy new SessionManagerUpgradeable implementation
  // const newSessionManager = m.contract("SessionManagerUpgradeable", [], { id: "newSessionManager" });
  
  // // Get existing session manager proxy address
  // const existingSessionManagerAddress = m.getParameter("existingSessionManagerAddress", SESSION_MANAGER_ADDRESS);
  // const existingSessionManager = m.contractAt("SessionManagerUpgradeable", existingSessionManagerAddress, { id: "existingSessionManager" });

  
  // // Upgrade the session manager proxy to new implementation
  // m.call(existingSessionManager, "upgradeToAndCall", [newSessionManager, "0x"]);
  
  // Re-initialize if needed (only if the new version requires it)
  // Note: UUPS contracts typically don't need re-initialization after upgrade
  // Uncomment the following lines if your new version requires initialization:
  // const token = m.getParameter("token", "0x0000000000000000000000000000000000000000");
  // m.call(existingSessionManager, "initialize", [token, existingSessionManager, owner]);
  
  // return { newSessionManager, existingSessionManager };
});

export default UpgradeSessionManagerModule; 