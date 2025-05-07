import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("SessionManager", function () {
  async function deploySessionManagerFixture() {
    // Deploy mock ERC20 token for testing
    const MockToken = await ethers.getContractFactory("MockERC20");
    const mockToken = await MockToken.deploy("Mock Token", "MTK");
    await mockToken.deployed();

    // Deploy SessionManager test implementation
    const SessionManagerTest = await ethers.getContractFactory("SessionManagerTest");
    const sessionManager = await SessionManagerTest.deploy();
    await sessionManager.deployed();

    // Get signers
    const [owner, user1, user2, feeTarget] = await ethers.getSigners();

    // Initialize SessionManager
    await sessionManager.initialize(mockToken.address, feeTarget.address);

    // Mint some tokens to users for testing
    const amount = ethers.utils.parseEther("1000");
    await mockToken.mint(user1.address, amount);
    await mockToken.mint(user2.address, amount);

    return { sessionManager, mockToken, owner, user1, user2, feeTarget };
  }

  describe("Session Management", function () {
    it("Should start a new session", async function () {
      const { sessionManager, mockToken, user1, feeTarget } = await loadFixture(deploySessionManagerFixture);
      const amount = ethers.utils.parseEther("100");

      // Approve tokens
      await mockToken.connect(user1).approve(sessionManager.address, amount);

      // Start session
      await expect(sessionManager.connect(user1).startUserSession(amount))
        .to.emit(sessionManager, "SessionStarted")
        .withArgs(1, user1.address, amount);

      const session = await sessionManager.getSessionById(1);
      expect(session.owner).to.equal(user1.address);
      expect(session.balance).to.equal(amount);
    });

    it("Should charge a session", async function () {
      const { sessionManager, mockToken, user1 } = await loadFixture(deploySessionManagerFixture);
      const startAmount = ethers.utils.parseEther("100");
      const chargeAmount = ethers.utils.parseEther("50");

      await mockToken.connect(user1).approve(sessionManager.address, startAmount);
      await sessionManager.connect(user1).startUserSession(startAmount);

      await expect(sessionManager.connect(user1).chargeUserSession(1, chargeAmount))
        .to.emit(sessionManager, "SessionCharged")
        .withArgs(1, chargeAmount);

      const session = await sessionManager.getSessionById(1);
      expect(session.balance).to.equal(startAmount.sub(chargeAmount));
    });

    it("Should close a session", async function () {
      const { sessionManager, mockToken, user1 } = await loadFixture(deploySessionManagerFixture);
      const amount = ethers.utils.parseEther("100");

      await mockToken.connect(user1).approve(sessionManager.address, amount);
      await sessionManager.connect(user1).startUserSession(amount);

      await expect(sessionManager.connect(user1).closeUserSession(1))
        .to.emit(sessionManager, "SessionClosed")
        .withArgs(1, amount);

      const session = await sessionManager.getSessionById(1);
      expect(session.owner).to.equal(ethers.constants.AddressZero);
    });

    it("Should revert on insufficient balance", async function () {
      const { sessionManager, mockToken, user1 } = await loadFixture(deploySessionManagerFixture);
      const startAmount = ethers.utils.parseEther("100");
      const chargeAmount = ethers.utils.parseEther("150");

      await mockToken.connect(user1).approve(sessionManager.address, startAmount);
      await sessionManager.connect(user1).startUserSession(startAmount);

      await expect(
        sessionManager.connect(user1).chargeUserSession(1, chargeAmount)
      ).to.be.revertedWithCustomError(sessionManager, "InsufficientBalance");
    });

    it("Should return correct user sessions", async function () {
      const { sessionManager, mockToken, user1 } = await loadFixture(deploySessionManagerFixture);
      const amount = ethers.utils.parseEther("100");

      await mockToken.connect(user1).approve(sessionManager.address, amount.mul(2));
      await sessionManager.connect(user1).startUserSession(amount);
      await sessionManager.connect(user1).startUserSession(amount);

      const sessionIds = await sessionManager.getUserSessionIds(user1.address);
      expect(sessionIds.length).to.equal(2);
      expect(sessionIds[0]).to.equal(1);
      expect(sessionIds[1]).to.equal(2);

      const sessions = await sessionManager.getUserSessions(user1.address);
      expect(sessions.length).to.equal(2);
      expect(sessions[0].owner).to.equal(user1.address);
      expect(sessions[1].owner).to.equal(user1.address);
    });
  });
}); 