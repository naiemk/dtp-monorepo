import { describe, it, expect, beforeEach, afterEach, test } from "bun:test";
import { execSync } from "child_process";
import { KeystoreManager } from "../src/keystore";
import path from "path";
import fs from "fs";

describe("Keystore Integration Test", () => {
    let testKeystoreDir: string;
    let keystoreManager: KeystoreManager;
    const testPassphrase = "test-password-123";
    const testPrivateKey = "02fe70bae08a7abf242172937b56260694fc5cbdbb10517c479fa33460036a3f";

    beforeEach(async () => {
        // Create a unique temporary keystore directory for testing
        const testId = Math.random().toString(36).substring(7);
        testKeystoreDir = path.join(process.cwd(), `test-keystore-${testId}`);
        if (fs.existsSync(testKeystoreDir)) {
            fs.rmSync(testKeystoreDir, { recursive: true, force: true });
        }
        fs.mkdirSync(testKeystoreDir, { recursive: true });

        // Set the environment variable so KeystoreManager uses our test directory
        process.env.FOUNDRY_KEYSTORE_PATH = testKeystoreDir;
        process.env.FOUNDRY_KEYSTORE_PASSPHRASE = testPassphrase;

        // Create a new KeystoreManager instance with test directory
        keystoreManager = new KeystoreManager();
    });

    afterEach(async () => {
        // Clean up test keystore directory
        if (fs.existsSync(testKeystoreDir)) {
            fs.rmSync(testKeystoreDir, { recursive: true, force: true });
        }
        
        // Clean up environment variables
        delete process.env.FOUNDRY_KEYSTORE_PATH;
        delete process.env.FOUNDRY_KEYSTORE_PASSPHRASE;
    });

    it("should import a private key using keystoreManager.importPrivateKey() and read it back correctly", async () => {
        // Step 1: Import the private key using keystoreManager.importPrivateKey()
        console.log("Step 1: Importing private key using keystoreManager.importPrivateKey()...");
        
        const address = await keystoreManager.importPrivateKey(testPrivateKey, testPassphrase);
        console.log("Import result:", address);

        // Step 2: Verify the key exists using keystoreManager
        console.log("Step 2: Verifying key exists using keystoreManager...");
        console.log("Keystore path:", (keystoreManager as any).keystorePath);
        console.log("Test keystore dir:", testKeystoreDir);
        console.log("Files in test dir:", fs.readdirSync(testKeystoreDir));
        
        const hasKey = await keystoreManager.hasKey(address);
        console.log("Has key result:", hasKey);
        expect(hasKey).toBe(true);

        // Step 3: Verify that the key can be exported using keystoreManager
        console.log("Step 3: Verifying key can be exported using keystoreManager...");
        
        const exportResult = await keystoreManager.loadPrivateKey(address, testPassphrase);
        console.log("Export result:", exportResult.substring(0, 100) + "...");

        // Step 4: Verify the export returns the correct private key
        expect(exportResult).toBe(testPrivateKey);
    });

    it("should load private key using keystoreManager.loadPrivateKey()", async () => {
        // First import a key using keystoreManager.importPrivateKey()
        console.log("Step 1: Importing private key using keystoreManager.importPrivateKey()...");
        
        const address = await keystoreManager.importPrivateKey(testPrivateKey, testPassphrase);
        console.log("Imported address:", address);

        // Step 2: Test keystoreManager.loadPrivateKey() directly
        console.log("Step 2: Testing keystoreManager.loadPrivateKey()...");
        
        const loadedKey = await keystoreManager.loadPrivateKey(address, testPassphrase);
        console.log("Loaded key (first 100 chars):", loadedKey.substring(0, 100) + "...");

        // Step 3: Verify the result is the correct private key
        console.log("Step 3: Verifying private key...");
        expect(loadedKey).toBe(testPrivateKey);
        
        // This verifies that the keystore was created correctly and can be read back using KeystoreManager
    });

    it("should import a private key using keystore.sh import-private-key command", async () => {
        // Step 1: Import the private key using keystore.sh import-private-key command
        console.log("Step 1: Importing private key using keystore.sh import-private-key...");
        
        const importCommand = `FOUNDRY_KEYSTORE_PATH="${testKeystoreDir}" ./keystore.sh import-private-key "${testPrivateKey}" --passphrase "${testPassphrase}"`;
        
        try {
            const importResult = execSync(importCommand, { 
                encoding: 'utf8',
                cwd: process.cwd(),
                stdio: 'pipe'
            });
            console.log("Import result:", importResult);
        } catch (error) {
            console.error("Import failed:", error);
            throw error;
        }

        // Step 2: List keys to get the address that was created
        console.log("Step 2: Listing keys to get the address...");
        
        const listCommand = `FOUNDRY_KEYSTORE_PATH="${testKeystoreDir}" ./keystore.sh list`;
        let address: string;
        
        try {
            const listResult = execSync(listCommand, { 
                encoding: 'utf8',
                cwd: process.cwd(),
                stdio: 'pipe'
            });
            console.log("List result:", listResult);
            
            // Extract address from the list output
            const addressMatch = listResult.match(/ccc[a-zA-Z0-9]+/);
            if (!addressMatch) {
                throw new Error("No address found in keystore list output");
            }
            address = addressMatch[0];
            console.log("Found address:", address);
        } catch (error) {
            console.error("List failed:", error);
            throw error;
        }

        // Step 3: Verify the key exists using keystoreManager
        console.log("Step 3: Verifying key exists using keystoreManager...");
        
        const hasKey = await keystoreManager.hasKey(address);
        console.log("Has key result:", hasKey);
        expect(hasKey).toBe(true);

        // Step 4: Verify that the key can be exported using keystoreManager
        console.log("Step 4: Verifying key can be exported using keystoreManager...");
        
        const exportResult = await keystoreManager.loadPrivateKey(address, testPassphrase);
        console.log("Export result:", exportResult.substring(0, 100) + "...");
        expect(exportResult).toBe(testPrivateKey);
    });

    it("should handle invalid passphrase correctly", async () => {
        // First import a key using keystoreManager.importPrivateKey()
        const address = await keystoreManager.importPrivateKey(testPrivateKey, testPassphrase);

        // Try to read with wrong passphrase using keystoreManager
        await expect(keystoreManager.loadPrivateKey(address, "wrong-password"))
            .rejects
            .toThrow("Invalid passphrase");
    });

    it("should handle non-existent address correctly", async () => {
        const nonExistentAddress = "ccc000000000000000000000000000000000000000";
        
        // Check if key exists using keystoreManager
        const hasKey = await keystoreManager.hasKey(nonExistentAddress);
        expect(hasKey).toBe(false);

        // Try to read non-existent key using keystoreManager
        // Note: cckey might return "Invalid passphrase" for non-existent addresses
        await expect(keystoreManager.loadPrivateKey(nonExistentAddress, testPassphrase))
            .rejects
            .toThrow();
    });
});
