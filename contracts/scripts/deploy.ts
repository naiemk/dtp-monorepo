import { HardhatRuntimeEnvironment } from "hardhat/types";
import { task } from "hardhat/config";
import deployRouterModule from "../ignition/modules/deployRouter";
import dotenv from "dotenv";
dotenv.config();

async function deployRouter(hre: HardhatRuntimeEnvironment) {
  console.log("Starting router deployment...");
  
  try {
    // Deploy the router module with display UI enabled
    const chainId = await hre.ethers.provider.getNetwork().then(n => n.chainId);
    console.log("chainId", chainId.toString());
    
    const tokenAddress = process.env['TOKEN_' + chainId.toString()];
    console.log('Fee token:', tokenAddress);
    
    // Validate that token address is provided
    if (!tokenAddress || tokenAddress === '0x0000000000000000000000000000000000000000') {
      throw new Error(`Token address not provided for chain ${chainId}. Please set TOKEN_${chainId} in your .env file.`);
    }
    
    const result = await hre.ignition.deploy(deployRouterModule, {
      displayUi: true,
      parameters: {
        'DeployRouter': {
          token: tokenAddress
        }
      }
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
    console.log("- ModelManager:", result.modelManager.target);
    console.log("Fee token configured:", tokenAddress);
    
    // Verify the fee token was set correctly in deployed contracts
    console.log("\n=== Fee Token Verification ===");
    
    // Query the router's fee token
    const routerFeeToken = await result.router.feeToken();
    console.log("Router.feeToken():", routerFeeToken);
    console.log("Expected token:", tokenAddress);
    console.log("Router fee token matches expected:", routerFeeToken.toString().toLowerCase() === tokenAddress.toLowerCase());
    
    // Query the session manager's fee token
    const sessionManagerFeeToken = await result.sessionManager.getFeeToken();
    console.log("SessionManager.getFeeToken():", sessionManagerFeeToken);
    console.log("SessionManager fee token matches expected:", sessionManagerFeeToken.toString().toLowerCase() === tokenAddress.toLowerCase());
    
    // Query the session manager's fee target
    const sessionManagerFeeTarget = await result.sessionManager.getFeeTarget();
    console.log("SessionManager.getFeeTarget():", sessionManagerFeeTarget);
    console.log("Fee target matches session manager:", sessionManagerFeeTarget.toString().toLowerCase() === result.sessionManager.target.toString().toLowerCase());
    
    console.log("=== Verification Complete ===\n");
    
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