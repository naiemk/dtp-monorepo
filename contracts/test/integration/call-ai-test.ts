import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { RouterUpgradeable } from "../../typechain-types";
import { MockERC20 } from "../../typechain-types";
import { CallAiExample } from "../../typechain-types";

interface TestContext {
  router: RouterUpgradeable;
  token: MockERC20;
  callAi: CallAiExample;
}

describe("Run and end-to-end call ai and print result", function () {
  async function deployRouterFixture() {
    const [owner] = await ethers.getSigners();
    // Deploy and configure the contracts
    const tokenF = await ethers.getContractFactory("MockERC20");
    const token = await tokenF.deploy("USDT", "USDT") as MockERC20;
    await token.mint(owner.address, ethers.parseEther("10000"));
    
    const routerF = await ethers.getContractFactory("RouterUpgradeable");
    const router = await routerF.deploy() as RouterUpgradeable;
    const callAiF = await ethers.getContractFactory("CallAiExample");
    const callAi = await callAiF.deploy(router.target) as CallAiExample;
    return { router, token, callAi } as TestContext;
  }

  describe("End-to-end-then-call-ai", function () {
    it("Should send request to call ai", async function () {
      const ctx = await loadFixture(deployRouterFixture);

      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.", {
        value: ethers.parseEther("0.0001") });

      console.log(`Now check if there is a request, ready for the node to pick up`)
      const reqId = await ctx.callAi.requestId();
      console.log(`Request ID: ${reqId}`);
      expect(reqId).to.not.be.undefined;
    });

    it("Should call ai and print result", async function () {
      const ctx = await loadFixture(deployRouterFixture);
      await ctx.callAi.doCallAi("What is A+B, if A=10 and B=12. Write only one single number as response.", {
        value: ethers.parseEther("0.0001") });

        // TODO: we need to register node, and model, etc. then use the node worker, to response to the 
        // request.
    });
  });
}); 
