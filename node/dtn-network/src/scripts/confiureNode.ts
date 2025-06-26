import fs from 'fs';
import yaml from 'yaml';
import { ethers } from 'ethers';
import type { NodeConfig, ModelApiConfig, CustomModelConfig } from '../types';

/**
 * This script is used to configure a node for the dtn network.
 * It will:
 * 1. Register the user, if not already registered
 * 2. Register the node, if not already registered
 * 3. Register model APIs if not already registered
 * 3. Register models
 */

// Contract ABIs - simplified versions for the functions we need
const NODE_MANAGER_ABI = [
    "function registerUser(string memory namespace, address staker) external",
    "function registerNode(string memory username, string memory nodeName, address worker) external payable",
    "function setNodeModels(bytes32 nodeId, bytes32[] calldata modelIds) external",
    "function getNode(bytes32 nodeId) external view returns (tuple(address owner, address staker, address worker, bytes32[] trustNamespaces, uint256[] trustNamespaceExpirations, bytes32 nodeNamespaceId, bool isActive, uint256 stakedAmount, bytes32 id))",
    "function getNodeModels(bytes32 nodeId) external view returns (bytes32[] memory)"
];

const MODEL_MANAGER_ABI = [
    "function registerModelAPI(string memory namespace, string memory apiName, string memory specs, string memory docs) external",
    "function registerModel(string memory namespace, string memory modelName, string memory modelApi) external returns (bytes32)",
    "function modelExists(bytes32 modelId) external view returns (bool)"
];

function loadConfig(configPath: string): NodeConfig {
    const config = fs.readFileSync(configPath, 'utf8');
    const configObj = yaml.parse(config);
    configObj.keys.ownerPrivateKey = process.env[configObj.keys.ownerPrivateKey];
    configObj.keys.workerPrivateKey = process.env[configObj.keys.workerPrivateKey];

    if (!configObj.keys.workerPrivateKey) {
        throw new Error('WORKER_PRIVATE_KEY is not set. Make sure to include the environment variable in the config file.');
    }
    return configObj;
}

/**
 * Register a user if not already registered
 */
async function registerUserIfNotExists(ownerWallet: ethers.Wallet, username: string, config: NodeConfig) {
    console.log(`Checking if user '${username}' is already registered...`);
    
    const nodeManager = new ethers.Contract(config.network.nodeManagerAddress, NODE_MANAGER_ABI, ownerWallet);
    
    try {
        // Try to get user info to check if registered
        const userId = ethers.solidityPackedKeccak256(['string'], [`node.${username}`]);
        await nodeManager.getNode!(userId);
        console.log(`User '${username}' is already registered.`);
    } catch (error) {
        console.log(`User '${username}' is not registered. Registering now...`);
        try {
            const tx = await nodeManager.registerUser!(`node.${username}`, ownerWallet.address);
            await tx.wait();
            console.log(`✅ User '${username}' registered successfully. Transaction: ${tx.hash}`);
        } catch (registerError) {
            console.error(`❌ Failed to register user '${username}':`, registerError);
            throw registerError;
        }
    }
}

/**
 * Register a node if not already registered
 */
async function registerNodeIfNotExists(ownerWallet: ethers.Wallet, nodeName: string, workerAddress: string, config: NodeConfig) {
    console.log(`Checking if node '${nodeName}' is already registered...`);
    
    const nodeManager = new ethers.Contract(config.network.nodeManagerAddress, NODE_MANAGER_ABI, ownerWallet);
    
    try {
        // Try to get node info to check if registered
        const nodeId = ethers.solidityPackedKeccak256(['string'], [`node.${config.node.username}.${nodeName}`]);
        await nodeManager.getNode!(nodeId);
        console.log(`Node '${nodeName}' is already registered.`);
    } catch (error) {
        console.log(`Node '${nodeName}' is not registered. Registering now...`);
        try {
            // Note: This might require a stake amount, but we'll use 0 for now
            const tx = await nodeManager.registerNode!(config.node.username, nodeName, workerAddress, { value: 0 });
            await tx.wait();
            console.log(`✅ Node '${nodeName}' registered successfully. Transaction: ${tx.hash}`);
        } catch (registerError) {
            console.error(`❌ Failed to register node '${nodeName}':`, registerError);
            throw registerError;
        }
    }
}

/**
 * Register model APIs if not already registered
 */
async function registerModelApisIfNotExists(ownerWallet: ethers.Wallet, modelApis: { [key: string]: ModelApiConfig }, config: NodeConfig) {
    console.log('Checking and registering model APIs...');
    
    const modelManager = new ethers.Contract(config.network.modelManagerAddress, MODEL_MANAGER_ABI, ownerWallet);
    
    for (const [apiName, apiConfig] of Object.entries(modelApis)) {
        console.log(`Checking model API '${apiName}'...`);
        try {
            // Try to register the API - if it fails, it might already exist
            const tx = await modelManager.registerModelAPI!(
                `api.${config.node.username}`,
                apiName,
                apiConfig.specs,
                apiConfig.docs
            );
            await tx.wait();
            console.log(`✅ Model API '${apiName}' registered successfully. Transaction: ${tx.hash}`);
        } catch (error) {
            // Check if it's an "already exists" error or something else
            const errorMessage = error instanceof Error ? error.message : String(error);
            if (errorMessage.includes('already exists')) {
                console.log(`Model API '${apiName}' is already registered.`);
            } else {
                console.error(`❌ Failed to register model API '${apiName}':`, error);
                throw error;
            }
        }
    }
}

/**
 * Register custom models if not already registered
 */
async function registerCustomModelsIfNotExists(ownerWallet: ethers.Wallet, customModels: CustomModelConfig[], config: NodeConfig) {
    console.log('Checking and registering custom models...');
    
    const modelManager = new ethers.Contract(config.network.modelManagerAddress, MODEL_MANAGER_ABI, ownerWallet);
    
    for (const {name: fullModelName, api: modelApi} of customModels) {
        console.log(`Checking custom model '${fullModelName}'...`);
        
        try {
            // Parse the full model name to extract namespace and model name
            const parts = fullModelName.split('.');
            if (parts.length < 2) {
                console.error(`❌ Invalid model name format '${fullModelName}'. Expected format: <namespace.modelName>`);
                continue;
            }
            
            const modelName = parts.pop()!; // Get the last part as model name
            const namespace = parts.join('.'); // Join remaining parts as namespace
            
            console.log(`  Namespace: ${namespace}, Model Name: ${modelName}, API: ${modelApi}`);
            
            // Check if model already exists
            const modelId = ethers.solidityPackedKeccak256(['string'], [fullModelName]);
            const modelExists = await modelManager.modelExists!(modelId);
            
            if (modelExists) {
                console.log(`Custom model '${fullModelName}' is already registered.`);
                continue;
            }
            
            // Register the model
            const tx = await modelManager.registerModel!(
                namespace,
                modelName,
                modelApi
            );
            await tx.wait();
            console.log(`✅ Custom model '${fullModelName}' registered successfully. Transaction: ${tx.hash}`);
            
        } catch (error) {
            // Check if it's an "already exists" error or something else
            const errorMessage = error instanceof Error ? error.message : String(error);
            if (errorMessage.includes('already exists') || errorMessage.includes('AlreadyExists')) {
                console.log(`Custom model '${fullModelName}' is already registered.`);
            } else {
                console.error(`❌ Failed to register custom model '${fullModelName}':`, error);
                throw error;
            }
        }
    }
}

/**
 * Set node models if not already set
 */
async function setNodeModelsIfNotSet(ownerWallet: ethers.Wallet, nodeId: string, modelIds: string[], config: NodeConfig) {
    console.log('Checking and setting node models...');
    
    const nodeManager = new ethers.Contract(config.network.nodeManagerAddress, NODE_MANAGER_ABI, ownerWallet);
    
    try {
        // Get current node models
        const currentModels = await nodeManager.getNodeModels!(nodeId);
        console.log(`Current node models: ${currentModels.length} models`);
        
        // Check if all required models are already set
        const missingModels = modelIds.filter(modelId => !currentModels.includes(modelId));
        
        if (missingModels.length === 0) {
            console.log('All required models are already set for this node.');
            return;
        }
        
        console.log(`Setting ${missingModels.length} new models for the node...`);
        const tx = await nodeManager.setNodeModels!(nodeId, modelIds);
        await tx.wait();
        console.log(`✅ Node models updated successfully. Transaction: ${tx.hash}`);
        console.log(`Models set: ${modelIds.join(', ')}`);
    } catch (error) {
        console.error(`❌ Failed to set node models:`, error);
        throw error;
    }
}

export async function configureNode(configPath: string) {
    const config = loadConfig(configPath);
    const provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
    const { ownerPrivateKey, workerPrivateKey } = config.keys;
    const ownerWallet = ownerPrivateKey ? new ethers.Wallet(ownerPrivateKey, provider) : null;

    if (ownerWallet) {
        await registerUserIfNotExists(ownerWallet, config.node.username, config);
        await registerNodeIfNotExists(ownerWallet, config.node.nodeName, config.node.worker, config);
        await registerModelApisIfNotExists(ownerWallet, config.modelApis, config);
        await registerCustomModelsIfNotExists(ownerWallet, config.customModels, config);
        const nodeId = ethers.solidityPackedKeccak256(['string'],
            [`node.${config.node.username}.${config.node.nodeName}`]);
        const modelIds = config.models.map(model =>
            ethers.solidityPackedKeccak256(['string'], [model.name]));
        await setNodeModelsIfNotSet(ownerWallet, nodeId, modelIds, config);
    } else {
        console.log('Owner private key is not set. Skipping node configuration.');
    }
}