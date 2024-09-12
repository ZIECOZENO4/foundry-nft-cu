// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BFXSea} from "../src/BFXSea.sol";
import {console} from "forge-std/console.sol";

contract DeployBFXSea is Script {
    function run() external returns (BFXSea) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);

        console.log("Deploying BFXSea contract with address:", deployerAddress);

        vm.startBroadcast(deployerKey);
        
        // Determine if we're deploying to mainnet or testnet
        // For Sepolia testnet, this should be false
        bool isMainnet = false;

        BFXSea bfxSea = new BFXSea(isMainnet);
        
        vm.stopBroadcast();
        
        console.log("BFXSea deployed at:", address(bfxSea));
        console.log("Is Mainnet:", isMainnet);
        
        return bfxSea;
    }
}