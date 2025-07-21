import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, keccak256, Signer } from "ethers";
import { ModelManagerUpgradeable, RouterUpgradeable } from "../../typechain-types";
import { MockERC20 } from "../../typechain-types";
import { CallAiExample } from "../../typechain-types";
import { NodeManagerUpgradeable } from "../../typechain-types";
import { NamespaceManager } from "../../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { SessionManagerUpgradeable } from "../../typechain-types";

const abi = ethers.AbiCoder.defaultAbiCoder();

interface TestContext {
  owner: HardhatEthersSigner;
  acc1: HardhatEthersSigner;
  router: RouterUpgradeable;
  token: MockERC20;
  callAi: CallAiExample;
  nodeManager: NodeManagerUpgradeable;
  namespaceManager: NamespaceManager;
  modelManager: ModelManagerUpgradeable;
}

async function deployRouter() {
  const [owner, acc1] = await ethers.getSigners();
  
  // Deploy and configure the contracts
  const tokenF = await ethers.getContractFactory("MockERC20");
  const token = await tokenF.deploy("USDT", "USDT") as MockERC20;
  await token.mint(owner.address, ethers.parseEther("10000"));
  
  // Deploy NamespaceManager first
  const namespaceManagerF = await ethers.getContractFactory("NamespaceManager");
  const namespaceManager = await namespaceManagerF.deploy() as NamespaceManager;
  await namespaceManager.initialize(owner.address);
  console.log('NS OWNER', await namespaceManager.getNamespaceOwner(keccak256(abi.encode(['string'], ['model.system']))));
  
  // Deploy NodeManager
  const nodeManagerF = await ethers.getContractFactory("NodeManagerUpgradeable");
  const nodeManager = await nodeManagerF.deploy() as NodeManagerUpgradeable;
  await nodeManager.initialize(namespaceManager.target, '1');

  // Deploy ModelManager
  const modelManagerF = await ethers.getContractFactory("ModelManagerUpgradeable");
  const modelManager = await modelManagerF.deploy() as ModelManagerUpgradeable;
  await modelManager.initialize(owner.address);

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
    owner.address
  );
  
  // Set up dependencies
  await router.setDependencies(nodeManager.target, sessionManager.target, modelManager.target);
  await modelManager.setDependencies(router.target, namespaceManager.target);
  await sessionManager.addDtnContracts([router.target]);
  await namespaceManager.addDtnContracts([router.target, sessionManager.target, nodeManager.target]);

  // Register the namespace, then the model API, then the model
  await modelManager.registerModelAPI('api.system', 'openai-gpt-4', 'specs', 'docs');
  await modelManager.registerModel('model.system', 'openai-gpt-4', 'api.system.openai-gpt-4');

  // Deploy CallAiExample
  const callAiF = await ethers.getContractFactory("CallAiExample");
  const callAi = await callAiF.deploy(router.target) as CallAiExample;
  
  return { owner, acc1, router, token, callAi, nodeManager, namespaceManager, modelManager } as TestContext;
}

describe("Run and end-to-end call ai and print result", function () {
    it("Should send request to call ai", async function () {
      const ctx = await deployRouter();

      console.log(`Owner: ${ctx.owner.address}, Router: ${ctx.router.target} token: ${ctx.token.target}`);
      await ctx.token.approve(ctx.callAi.target, ethers.parseEther("100"));

      console.log("NS MGR", await ctx.modelManager.getNamespaceManager());
      console.log("NS MGR", await ctx.modelManager.getRouter());

      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.",
        "node.tester.node1",
        "model.system.openai-gpt-4",
        { value: ethers.parseEther("0.0001") });

      console.log(`Now check if there is a request, ready for the node to pick up`)
      const reqId = await ctx.callAi.requestId();
      console.log(`Request ID: ${reqId}`);
      expect(reqId).to.not.be.undefined;
    });

    it("Should call ai and print result", async function () {
      const ctx = await deployRouter();
      console.log(`Register a node`);
      await ctx.nodeManager.registerUser("tester", ctx.acc1.address);
      await ctx.nodeManager.registerNode("tester", "node1", ctx.acc1.address);
      const nodeId = ethers.solidityPackedKeccak256(['string'], ['node.tester.node1']);
      await ctx.nodeManager.setNodeModels(nodeId, [ethers.solidityPackedKeccak256(['string'], ['model.system.openai-gpt-4'])]);

      await ctx.token.approve(ctx.callAi.target, ethers.parseEther("100"));
      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.",
        "node.tester.node1",
        "model.system.openai-gpt-4",
        { value: ethers.parseEther("0.0001") });

      console.log(`Now we will act as the node: worker is: ${ctx.acc1.address}, callAi is: ${ctx.callAi.target}`);
      console.log(`Request ID: ${await ctx.callAi.requestId()}`);
      await ctx.router.connect(ctx.acc1).respondToRequest(
        await ctx.callAi.requestId(),
        1, // success
        'successful response',
        abi.encode(['string'], ['22']),
        nodeId,
        0,
        0);

      console.log(`Now let's check the result`);
      const result = await ctx.callAi.result();
      console.log(`Result: ${result}`);
      expect(result).to.equal('22');
    });

    it("Should show execution error, when node rejects", async function () {
      const ctx = await deployRouter();
      await ctx.nodeManager.registerUser("tester", ctx.acc1.address);
      await ctx.nodeManager.registerNode("tester", "node1", ctx.acc1.address);
      const nodeId = ethers.solidityPackedKeccak256(['string'], ['node.tester.node1']);
      await ctx.nodeManager.setNodeModels(nodeId, [ethers.solidityPackedKeccak256(['string'], ['model.system.openai-gpt-4'])]);

      await ctx.token.approve(ctx.callAi.target, ethers.parseEther("100"));
      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.",
        "node.tester.node1",
        "model.system.openai-gpt-4",
        { value: ethers.parseEther("0.0001") });

      await ctx.router.connect(ctx.acc1).respondToRequest(
        await ctx.callAi.requestId(),
        2, // FAILURE
        'ER101: Node errored',
        '0x',
        nodeId,
        0,
        0);

      const error = await ctx.callAi.error();
      expect(error).to.equal('ER101: Node errored');
    });

}); 
