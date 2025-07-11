import { HardhatRuntimeEnvironment } from "hardhat/types";
import { task } from "hardhat/config";
import deployRouterModule from "../ignition/modules/deployRouter";

async function deployRouter(hre: HardhatRuntimeEnvironment) {
  console.log("Starting router deployment...");
  
  try {
    // Deploy the router module with display UI enabled
    const result = await hre.ignition.deploy(deployRouterModule, {
      displayUi: true,
      // You can add additional parameters here if needed
      // parameters: {
      //   owner: "0x...",
      //   token: "0x..."
      // }
    });
    
    console.log("Router deployment completed successfully!");
    console.log("Deployed contracts:");
    console.log("- Router:", result.router.target);
    console.log("- NamespaceManager:", result.namespaceManager.target);
    console.log("- NodeManager:", result.nodeManager.target);
    console.log("- SessionManager:", result.sessionManager.target);
    
    return result;
  } catch (error) {
    console.error("Router deployment failed:", error);
    throw error;
  }
}

// Hardhat task for deployment
task("deploy:router", "Deploy the router with all dependencies")
  .setAction(async (taskArgs, hre) => {
    await deployRouter(hre);
  });

// Export for use in other scripts
export { deployRouter }; 