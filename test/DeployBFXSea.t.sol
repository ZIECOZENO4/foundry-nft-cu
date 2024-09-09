// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployBFXSea} from "../script/DeployBFXSea.s.sol";
import {BFXSea} from "../src/BFXSea.sol";

contract DeployBFXSeaTest is Test {
    DeployBFXSea public deployer;
    BFXSea public bfxSea;

    function setUp() public {
        deployer = new DeployBFXSea();
    }

    function testDeploymentOnAnvil() public {
        vm.chainId(31337);
        bfxSea = deployer.run();
        assertTrue(address(bfxSea) != address(0), "BFXSea contract was not deployed");
        assertFalse(bfxSea.isMainnet(), "isMainnet should be false for Anvil");
        assertEq(vm.addr(deployer.DEFAULT_ANVIL_PRIVATE_KEY()), bfxSea.owner(), "Incorrect owner for Anvil deployment");
    }

    function testDeploymentOnMainnet() public {
        vm.chainId(1);
        vm.setEnv("PRIVATE_KEY", "1");
        bfxSea = deployer.run();
        assertTrue(address(bfxSea) != address(0), "BFXSea contract was not deployed");
        assertTrue(bfxSea.isMainnet(), "isMainnet should be true for Ethereum mainnet");
        assertEq(vm.addr(uint256(1)), bfxSea.owner(), "Incorrect owner for mainnet deployment");
    }

    function testDeploymentOnTestnet() public {
        vm.chainId(5);
        vm.setEnv("PRIVATE_KEY", "2");
        bfxSea = deployer.run();
        assertTrue(address(bfxSea) != address(0), "BFXSea contract was not deployed");
        assertFalse(bfxSea.isMainnet(), "isMainnet should be false for testnet");
        assertEq(vm.addr(uint256(2)), bfxSea.owner(), "Incorrect owner for testnet deployment");
    }

    function testDeploymentWithDifferentFeeRecipient() public {
        address payable newFeeRecipient = payable(address(0x123));
        vm.setEnv("FEE_RECIPIENT", vm.toString(address(newFeeRecipient)));
        vm.chainId(1); // Set to mainnet for this test
        bfxSea = deployer.run();
        assertEq(bfxSea.feeRecipient(), newFeeRecipient, "Fee recipient not set correctly");
    }

    function testDeploymentWithCustomCreationFees() public {
        uint256 customMainnetFee = 0.002 ether;
        uint256 customTestnetFee = 0.1 ether;
        vm.setEnv("CREATION_FEE_MAINNET", vm.toString(customMainnetFee));
        vm.setEnv("CREATION_FEE_TESTNET", vm.toString(customTestnetFee));

        vm.chainId(1);
        bfxSea = deployer.run();
        assertEq(bfxSea.CREATION_FEE_MAINNET(), customMainnetFee, "Custom mainnet fee not set correctly");

        vm.chainId(5);
        bfxSea = deployer.run();
        assertEq(bfxSea.CREATION_FEE_TESTNET(), customTestnetFee, "Custom testnet fee not set correctly");
    }

    function testDeploymentFailsWithInvalidChainId() public {
        vm.chainId(999);
        vm.expectRevert("Unsupported chain ID");
        bfxSea = deployer.run();
    }

    function testDeploymentWithDefaultValues() public {
        vm.chainId(1); // Set to mainnet
        bfxSea = deployer.run();
        assertEq(bfxSea.CREATION_FEE_MAINNET(), 0.001 ether, "Default mainnet fee not set correctly");
        assertEq(bfxSea.CREATION_FEE_TESTNET(), 0.05 ether, "Default testnet fee not set correctly");
        assertEq(bfxSea.feeRecipient(), payable(0xB8622ea337FE15296Cb62b984E41dC6cda7E91b5), "Default fee recipient not set correctly");
    }

    function testDeploymentWithMixedCustomValues() public {
        uint256 customMainnetFee = 0.003 ether;
        address payable newFeeRecipient = payable(address(0x456));
        vm.setEnv("CREATION_FEE_MAINNET", vm.toString(customMainnetFee));
        vm.setEnv("FEE_RECIPIENT", vm.toString(address(newFeeRecipient)));

        vm.chainId(1);
        bfxSea = deployer.run();
        assertEq(bfxSea.CREATION_FEE_MAINNET(), customMainnetFee, "Custom mainnet fee not set correctly");
        assertEq(bfxSea.CREATION_FEE_TESTNET(), 0.05 ether, "Default testnet fee should remain unchanged");
        assertEq(bfxSea.feeRecipient(), newFeeRecipient, "Custom fee recipient not set correctly");
    }
}