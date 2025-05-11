"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const hardhat_1 = require("hardhat");
const hardhat_network_helpers_1 = require("@nomicfoundation/hardhat-network-helpers");
describe("Router", function () {
    async function deployRouterFixture() {
        // Deploy mock contracts
        const MockToken = await hardhat_1.ethers.getContractFactory("MockERC20");
        const mockToken = await MockToken.deploy("Mock Token", "MTK");
        await mockToken.deployed();
        const MockModelManager = await hardhat_1.ethers.getContractFactory("MockModelManager");
        const mockModelManager = await MockModelManager.deploy();
        await mockModelManager.deployed();
        // Deploy Router
        const Router = await hardhat_1.ethers.getContractFactory("RouterUpgradeable");
        const router = await Router.deploy();
        await router.deployed();
        // Get signers
        const [owner, user1, user2, feeTarget] = await hardhat_1.ethers.getSigners();
        // Initialize Router
        await router.initialize(mockModelManager.address, mockToken.address, feeTarget.address);
        // Mint some tokens to users for testing
        const amount = hardhat_1.ethers.utils.parseEther("1000");
        await mockToken.mint(user1.address, amount);
        await mockToken.mint(user2.address, amount);
        return { router, mockToken, mockModelManager, owner, user1, user2, feeTarget };
    }
    describe("Initialization", function () {
        it("Should set the correct model manager", async function () {
            const { router, mockModelManager } = await (0, hardhat_network_helpers_1.loadFixture)(deployRouterFixture);
            (0, chai_1.expect)(await router.getModelManager()).to.equal(mockModelManager.address);
        });
        it("Should not allow reinitialization", async function () {
            const { router, mockModelManager, mockToken, feeTarget } = await (0, hardhat_network_helpers_1.loadFixture)(deployRouterFixture);
            await (0, chai_1.expect)(router.initialize(mockModelManager.address, mockToken.address, feeTarget.address)).to.be.revertedWith("Initializable: contract is already initialized");
        });
    });
    describe("Session Integration", function () {
        it("Should inherit session management functionality", async function () {
            const { router, mockToken, user1 } = await (0, hardhat_network_helpers_1.loadFixture)(deployRouterFixture);
            const amount = hardhat_1.ethers.utils.parseEther("100");
            await mockToken.connect(user1).approve(router.address, amount);
            await (0, chai_1.expect)(router.connect(user1).startUserSession(amount))
                .to.emit(router, "SessionStarted")
                .withArgs(1, user1.address, amount);
            const session = await router.getSessionById(1);
            (0, chai_1.expect)(session.owner).to.equal(user1.address);
            (0, chai_1.expect)(session.balance).to.equal(amount);
        });
    });
});
