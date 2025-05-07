import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("Router", function () {
  async function deployRouterFixture() {
    // Deploy mock contracts
    const MockToken = await ethers.getContractFactory("MockERC20");
    const mockToken = await MockToken.deploy("Mock Token", "MTK");
    await mockToken.deployed();

    const MockModelManager = await ethers.getContractFactory("MockModelManager");
    const mockModelManager = await MockModelManager.deploy();
    await mockModelManager.deployed();

    // Deploy Router
    const Router = await ethers.getContractFactory("RouterUpgradeable");
    const router = await Router.deploy();
    await router.deployed();

    // Get signers
    const [owner, user1, user2, feeTarget] = await ethers.getSigners();

    // Initialize Router
    await router.initialize(mockModelManager.address, mockToken.address, feeTarget.address);

    // Mint some tokens to users for testing
    const amount = ethers.utils.parseEther("1000");
    await mockToken.mint(user1.address, amount);
    await mockToken.mint(user2.address, amount);

    return { router, mockToken, mockModelManager, owner, user1, user2, feeTarget };
  }

  describe("Initialization", function () {
    it("Should set the correct model manager", async function () {
      const { router, mockModelManager } = await loadFixture(deployRouterFixture);
      expect(await router.getModelManager()).to.equal(mockModelManager.address);
    });

    it("Should not allow reinitialization", async function () {
      const { router, mockModelManager, mockToken, feeTarget } = await loadFixture(deployRouterFixture);
      await expect(
        router.initialize(mockModelManager.address, mockToken.address, feeTarget.address)
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });
  });

  describe("Session Integration", function () {
    it("Should inherit session management functionality", async function () {
      const { router, mockToken, user1 } = await loadFixture(deployRouterFixture);
      const amount = ethers.utils.parseEther("100");

      await mockToken.connect(user1).approve(router.address, amount);
      
      await expect(router.connect(user1).startUserSession(amount))
        .to.emit(router, "SessionStarted")
        .withArgs(1, user1.address, amount);

      const session = await router.getSessionById(1);
      expect(session.owner).to.equal(user1.address);
      expect(session.balance).to.equal(amount);
    });
  });
}); 