import { execSync } from 'child_process';
import path from 'path';

/**
 * Simple keystore manager that uses foundry-keystore-cli (cckey) to read private keys
 */
export class KeystoreManager {
    private keystorePath: string;
    private passphrase: string;

    constructor() {
        const keystoreDir = process.env.FOUNDRY_KEYSTORE_PATH || path.join(process.env.HOME || '~', '.foundry', 'keystores');
        this.keystorePath = path.join(keystoreDir, 'keystore.db');
        this.passphrase = process.env.FOUNDRY_KEYSTORE_PASSPHRASE || '';
    }

    /**
     * Load a private key from the keystore by address using foundry-keystore-cli (cckey)
     */
    async loadPrivateKey(address: string, passphrase?: string): Promise<string> {
        const usePassphrase = passphrase || this.passphrase;
        
        if (!usePassphrase) {
            throw new Error(`Passphrase is required to load key '${address}'. Set FOUNDRY_KEYSTORE_PASSPHRASE environment variable or provide passphrase.`);
        }

        try {
            // Use foundry-keystore-cli to export the private key
            const command = `cckey export --keys-path "${this.keystorePath}" --address "${address}" --passphrase "${usePassphrase}"`;
            const privateKey = execSync(command, { 
                encoding: 'utf8',
                stdio: 'pipe'
            }).trim();

            if (!privateKey || !privateKey.startsWith('0x')) {
                throw new Error(`Invalid private key format received for address '${address}'`);
            }

            return privateKey;
        } catch (error) {
            if (error instanceof Error) {
                // Parse the error to provide more helpful messages
                if (error.message.includes('No such file') || error.message.includes('command not found')) {
                    throw new Error(`foundry-keystore-cli (cckey) not found. Make sure it's installed and in PATH.`);
                }
                if (error.message.includes('not found') || error.message.includes('No key')) {
                    throw new Error(`Address '${address}' not found in keystore at ${this.keystorePath}`);
                }
                if (error.message.includes('passphrase') || error.message.includes('password')) {
                    throw new Error(`Invalid passphrase for address '${address}'`);
                }
                throw new Error(`Failed to load private key '${address}': ${error.message}`);
            }
            throw new Error(`Failed to load private key '${address}': Unknown error`);
        }
    }

    /**
     * Check if an address exists in the keystore
     */
    async hasKey(address: string): Promise<boolean> {
        try {
            const command = `cckey list --keys-path "${this.keystorePath}"`;
            const output = execSync(command, { 
                encoding: 'utf8',
                stdio: 'pipe'
            });
            
            // Check if the address appears in the output
            return output.includes(address);
        } catch (error) {
            return false;
        }
    }
}

// Default instance
export const keystoreManager = new KeystoreManager();