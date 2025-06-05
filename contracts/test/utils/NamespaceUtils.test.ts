import { expect } from "chai";
import { ethers } from "hardhat";

describe("NamespaceUtils Gas Analysis", function() {
  it("measures gas for 60 character string", async function() {
    const NamespaceUtils = await ethers.getContractFactory("NamespaceUtils");
    const utils = await NamespaceUtils.deploy();
    await utils.deployed();

    // Create a 60 char string with a dot somewhere in middle
    const testStr = "namespace.very.long.resource.name.that.is.exactly.sixty.chars.long.here";
    
    // Measure gas
    const tx = await utils.testGasUsage(testStr);
    const receipt = await tx.wait();
    
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
  });
}); 