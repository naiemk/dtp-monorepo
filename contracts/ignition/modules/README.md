# Contract Upgrade Scripts

This directory contains Hardhat Ignition modules for upgrading the DTN smart contracts. All contracts use the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Available Upgrade Scripts

- `upgradeRouter.ts` - Upgrade the RouterUpgradeable contract
- `upgradeNamespaceManager.ts` - Upgrade the NamespaceManager contract  
- `upgradeNodeManager.ts` - Upgrade the NodeManagerUpgradeable contract
- `upgradeSessionManager.ts` - Upgrade the SessionManagerUpgradeable contract

## Usage

### Prerequisites

1. Make sure you have the existing contract addresses from your previous deployment
2. Ensure you have the correct network configuration in your Hardhat config
3. Make sure you have sufficient funds in your deployer account

### Running an Upgrade

To upgrade a specific contract, use the following command:

```bash
npx hardhat ignition deploy contracts/ignition/modules/upgrade[ContractName].ts --parameters '{"existing[ContractName]Address": "0x..."}'
```

### Examples

#### Upgrade Router
```bash
npx hardhat ignition deploy contracts/ignition/modules/upgradeRouter.ts \
  --parameters '{"existingRouterAddress": "0x1234567890123456789012345678901234567890"}'
```

#### Upgrade NamespaceManager
```bash
npx hardhat ignition deploy contracts/ignition/modules/upgradeNamespaceManager.ts \
  --parameters '{"existingNamespaceManagerAddress": "0x1234567890123456789012345678901234567890"}'
```

#### Upgrade NodeManager
```bash
npx hardhat ignition deploy contracts/ignition/modules/upgradeNodeManager.ts \
  --parameters '{"existingNodeManagerAddress": "0x1234567890123456789012345678901234567890"}'
```

#### Upgrade SessionManager
```bash
npx hardhat ignition deploy contracts/ignition/modules/upgradeSessionManager.ts \
  --parameters '{"existingSessionManagerAddress": "0x1234567890123456789012345678901234567890"}'
```

## Parameters

Each upgrade script accepts the following parameters:

- `owner` (optional): The owner address. Defaults to the first account (account 0)
- `existing[ContractName]Address` (required): The address of the existing proxy contract to upgrade

Additional parameters for specific contracts:

### NodeManager
- `namespaceManagerAddress` (optional): Required if re-initialization is needed

### SessionManager  
- `token` (optional): The token address. Defaults to zero address (0x0000...)

## Important Notes

1. **UUPS Pattern**: All contracts use the UUPS upgrade pattern, which means:
   - The proxy contract remains the same address
   - Only the implementation contract is upgraded
   - State is preserved during upgrades
   - Re-initialization is typically not required

2. **Re-initialization**: If your new contract version requires re-initialization, uncomment the relevant lines in the upgrade script. This is rarely needed with UUPS contracts.

3. **Permissions**: Make sure the account running the upgrade has the necessary permissions (typically UPGRADER_ROLE or OWNER_ROLE) on the proxy contract.

4. **Testing**: Always test upgrades on a testnet before deploying to mainnet.

5. **Verification**: After upgrading, verify the new implementation contract on block explorers like Etherscan.

## Security Considerations

- Only upgrade contracts from trusted sources
- Verify the new implementation contract before upgrading
- Test thoroughly on testnets
- Consider using a timelock for mainnet upgrades
- Ensure proper access controls are in place 