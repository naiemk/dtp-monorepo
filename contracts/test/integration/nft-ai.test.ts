import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { RouterUpgradeable } from "../../typechain-types";
import { MockERC20 } from "../../typechain-types";
import { NftAi } from "../../typechain-types";
import { ModelManagerUpgradeable } from "../../typechain-types";

interface TestContext {
  router: RouterUpgradeable;
  token: MockERC20;
  nftAi: NftAi;
}

describe("Run and end-to-end create image and get callback and mint", function () {
  async function deployRouterFixture() {
    const [owner] = await ethers.getSigners();
    // Deploy and configure the contracts
    const tokenF = await ethers.getContractFactory("MockERC20");
    const token = await tokenF.deploy("USDT", "USDT") as MockERC20;
    await token.mint(owner.address, ethers.parseEther("10000"));
    
    const routerF = await ethers.getContractFactory("RouterUpgradeable");
    const router = await routerF.deploy() as RouterUpgradeable;
    const nftAiF = await ethers.getContractFactory("NftAi");
    const nftAi = await nftAiF.deploy() as NftAi;
    await nftAi.initialize(router.target, ethers.parseEther("0.0001"));
    return { router, token, nftAi } as TestContext;
  }

  describe("End-to-end", function () {
    it("Should send request tocreate image", async function () {
      const ctx = await loadFixture(deployRouterFixture);

      await ctx.token.approve(ctx.router.target, ethers.parseEther("100"));
      await ctx.nftAi.purchaseNft("A beautiful image of a cat", {
        value: ethers.parseEther("0.0001") });

      console.log(`Now check if there is a request, ready for the node to pick up`)
      const requestCount = await ctx.router.getRequests();
      expect(requestCount).to.not.be.undefined;
    });
  });
}); 