import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { RouterUpgradeable } from "../../typechain-types";
import { MockERC20 } from "../../typechain-types";
import { CallAiExample } from "../../typechain-types";
import { NodeManagerUpgradeable } from "../../typechain-types";
import { NamespaceManager } from "../../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { SessionManagerUpgradeable } from "../../typechain-types";

interface TestContext {
  owner: HardhatEthersSigner;
  router: RouterUpgradeable;
  token: MockERC20;
  callAi: CallAiExample;
  nodeManager: NodeManagerUpgradeable;
  namespaceManager: NamespaceManager;
}

async function deployRouter() {
  const [owner] = await ethers.getSigners();
  
  // Deploy and configure the contracts
  const tokenF = await ethers.getContractFactory("MockERC20");
  const token = await tokenF.deploy("USDT", "USDT") as MockERC20;
  await token.mint(owner.address, ethers.parseEther("10000"));
  
  // Deploy NamespaceManager first
  const namespaceManagerF = await ethers.getContractFactory("NamespaceManager");
  const namespaceManager = await namespaceManagerF.deploy() as NamespaceManager;
  await namespaceManager.initialize(owner.address);
  
  // Deploy NodeManager
  const nodeManagerF = await ethers.getContractFactory("NodeManagerUpgradeable");
  const nodeManager = await nodeManagerF.deploy() as NodeManagerUpgradeable;
  await nodeManager.initialize(namespaceManager.target, '1');

  // Deploy SessionManager
  const sessionManagerF = await ethers.getContractFactory("SessionManagerUpgradeable");
  const sessionManager = await sessionManagerF.deploy() as SessionManagerUpgradeable;
  await sessionManager.initialize(token.target, sessionManager.target, owner.address);
  
  // Deploy Router
  const routerF = await ethers.getContractFactory("RouterUpgradeable");
  const router = await routerF.deploy() as RouterUpgradeable;
  
  // Initialize Router with all dependencies
  await router.initialize(
    ethers.parseEther("1"), // minAuthoredStake
    ethers.parseEther("1"), // minNodeStake
    owner.address
  );
  
  // Set up dependencies
  await router.setDependencies(nodeManager.target, sessionManager.target);
  await sessionManager.addDtnContracts([router.target, sessionManager.target]);
  
  // Deploy CallAiExample
  const callAiF = await ethers.getContractFactory("CallAiExample");
  const callAi = await callAiF.deploy(router.target) as CallAiExample;
  
  return { owner, router, token, callAi, nodeManager, namespaceManager } as TestContext;
}

describe("Run and end-to-end call ai and print result", function () {
    it("Should send request to call ai", async function () {
      const ctx = await deployRouter();

      console.log(`Owner: ${ctx.owner.address}, Router: ${ctx.router.target} token: ${ctx.token.target}`);
      await ctx.token.approve(ctx.callAi.target, ethers.parseEther("100"));

      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.", {
        value: ethers.parseEther("0.0001") });

      console.log(`Now check if there is a request, ready for the node to pick up`)
      const reqId = await ctx.callAi.requestId();
      console.log(`Request ID: ${reqId}`);
      expect(reqId).to.not.be.undefined;
    });

    it("Should call ai and print result", async function () {
      // const ctx = await deployRouter();
      // await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.", {
      //   value: ethers.parseEther("0.0001") });

      // TODO: we need to register node, and model, etc. then use the node worker, to response to the 
      // request.
    });
}); 
