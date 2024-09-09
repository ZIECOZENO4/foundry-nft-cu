// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BFXSea} from "../src/BFXSea.sol";
import {console} from "forge-std/console.sol";

contract DeployBFXSea is Script {
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public deployerKey;

    function run() external returns (BFXSea) {
        if (block.chainid == 31337) {
            deployerKey = DEFAULT_ANVIL_PRIVATE_KEY;
        } else {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }

        vm.startBroadcast(deployerKey);
        
        // Determine if we're deploying to mainnet or testnet
        bool isMainnet = (block.chainid == 1); // Ethereum mainnet

        BFXSea bfxSea = new BFXSea(isMainnet);
        
        vm.stopBroadcast();
        
        return bfxSea;
    }
}