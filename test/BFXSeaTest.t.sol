// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BFXSea} from "../src/BFXSea.sol";
import {DeployBFXSea} from "../script/DeployBFXSea.s.sol";

contract BFXSeaTest is Test {
    BFXSea public bfxSea;
    DeployBFXSea public deployer;
    address public owner;
    address public user1;
    address public user2;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    event NFTCreated(uint256 indexed tokenId, address creator, bytes32 name, uint256 price, uint256 supply);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event CollectionCreated(address indexed creator, bytes32 name);

    function setUp() public {
        deployer = new DeployBFXSea();
        bfxSea = deployer.run();
        owner = bfxSea.owner();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        vm.deal(owner, INITIAL_BALANCE);
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
    }

function testDeployment() public view {
    assertTrue(address(bfxSea) != address(0), "BFXSea not deployed");
    assertEq(bfxSea.name(), "BFXSea", "Contract name mismatch");
    assertEq(bfxSea.symbol(), "BFXS", "Contract symbol mismatch");
    assertEq(bfxSea.owner(), owner, "Owner not set correctly");
    assertFalse(bfxSea.isMainnet(), "isMainnet should be false for local testnet");
}

function testOwnership() public view {
    assertEq(bfxSea.owner(), owner, "Owner should be the deployer");
}

function testFeeRecipient() public view {
    assertEq(bfxSea.feeRecipient(), 0xB8622ea337FE15296Cb62b984E41dC6cda7E91b5, "Incorrect fee recipient");
}

    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0x123);
        vm.prank(owner);
        bfxSea.setFeeRecipient(payable(newFeeRecipient));
        assertEq(bfxSea.feeRecipient(), newFeeRecipient, "Fee recipient not updated");
    }

    function testCreateNFT() public {
        vm.startPrank(user1);
        uint256 supply = 10;
        uint256 creationFee = 0.05 ether; // Using testnet fee
        uint256 totalFee = creationFee * supply;

        vm.expectEmit(true, true, false, true);
        emit NFTCreated(0, user1, bytes32("TestNFT"), 1 ether, supply);

        bfxSea.createNFT{value: totalFee}(
            bytes32("TestNFT"),
            bytes32("Description"),
            bytes32("tokenURI"),
            1 ether,
            BFXSea.Category.Art,
            supply
        );
        vm.stopPrank();

        assertEq(bfxSea.getTokenCounter(), 1);
        assertEq(bfxSea.ownerOf(0), user1);
    }

    function testCreateNFTInsufficientFee() public {
        vm.startPrank(user1);
        uint256 supply = 10;
        uint256 creationFee = 0.05 ether; // Using testnet fee
        uint256 totalFee = creationFee * supply;

        vm.expectRevert(BFXSea.BFXSea__InsufficientCreationFee.selector);
        bfxSea.createNFT{value: totalFee - 1}(
            bytes32("TestNFT"),
            bytes32("Description"),
            bytes32("tokenURI"),
            1 ether,
            BFXSea.Category.Art,
            supply
        );
        vm.stopPrank();
    }

    function testFuzzCreateNFT(
        bytes32 name,
        bytes32 description,
        bytes32 tokenUri,
        uint256 price,
        uint8 category,
        uint256 supply
    ) public {
        vm.assume(price > 0 && price < 1000 ether);
        vm.assume(supply > 0 && supply < 1000);
        vm.assume(category < 7);
        uint256 creationFee = 0.05 ether; // Using testnet fee
        uint256 totalFee = creationFee * supply;

        vm.startPrank(user1);
        vm.deal(user1, totalFee);
        bfxSea.createNFT{value: totalFee}(
            name,
            description,
            tokenUri,
            price,
            BFXSea.Category(category),
            supply
        );
        vm.stopPrank();

        assertEq(bfxSea.getTokenCounter(), 1);
        assertEq(bfxSea.ownerOf(0), user1);
    }

    function testMintNFT() public {
        testCreateNFT();
        vm.startPrank(user2);
        bfxSea.mintNFT(0);
        vm.stopPrank();
        assertEq(bfxSea.getTokenCounter(), 2);
        assertEq(bfxSea.ownerOf(1), user2);
    }

    function testMintNFTExceedSupply() public {
        testCreateNFT();
        for (uint i = 0; i < 9; i++) {
            vm.prank(address(uint160(i + 3)));
            bfxSea.mintNFT(0);
        }
        vm.expectRevert(BFXSea.BFXSea__SupplyExceeded.selector);
        vm.prank(user2);
        bfxSea.mintNFT(0);
    }

    function testBuyNFTInsufficientPayment() public {
        testCreateNFT();
        vm.prank(user1);
        bfxSea.listNFTForSale(0, 1 ether);
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__InsufficientPayment.selector);
        bfxSea.buyNFT{value: 0.9 ether}(0);
        vm.stopPrank();
    }

    function testListNFTForSale() public {
        testCreateNFT();
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit NFTListed(0, 2 ether);
        bfxSea.listNFTForSale(0, 2 ether);
        vm.stopPrank();
        BFXSea.NFT memory nft = bfxSea.getNFTDetails(0);
        assertEq(nft.price, 2 ether);
        assertTrue(nft.isForSale);
    }

    function testListNFTForSaleNotOwner() public {
        testCreateNFT();
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__NotOwner.selector);
        bfxSea.listNFTForSale(0, 2 ether);
        vm.stopPrank();
    }

    function testCreateCollection() public {
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit CollectionCreated(user1, bytes32("MyCollection"));
        bfxSea.createCollection(bytes32("MyCollection"), bytes32("Description"));
        vm.stopPrank();
        BFXSea.Collection[] memory collections = bfxSea.getCreatorCollections(user1);
        assertEq(collections.length, 1);
        assertEq(collections[0].name, bytes32("MyCollection"));
    }

    function testAddNFTToCollection() public {
        testCreateNFT();
        testCreateCollection();
        vm.startPrank(user1);
        bfxSea.addNFTToCollection(0, 0);
        vm.stopPrank();
        BFXSea.Collection[] memory collections = bfxSea.getCreatorCollections(user1);
        assertEq(collections[0].tokenIds.length, 1);
        assertEq(collections[0].tokenIds[0], 0);
    }

    function testAddNFTToCollectionNotOwner() public {
        testCreateNFT();
        testCreateCollection();
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__NotOwnerOfNFT.selector);
        bfxSea.addNFTToCollection(0, 0);
        vm.stopPrank();
    }

    function testFuzzListNFTForSale(uint256 newPrice) public {
        testCreateNFT();
        vm.assume(newPrice > 0 && newPrice < 1000 ether);
        vm.startPrank(user1);
        bfxSea.listNFTForSale(0, newPrice);
        vm.stopPrank();
        BFXSea.NFT memory nft = bfxSea.getNFTDetails(0);
        assertEq(nft.price, newPrice);
        assertTrue(nft.isForSale);
    }

    function testGetNFTDetails() public {
        testCreateNFT();
        BFXSea.NFT memory nft = bfxSea.getNFTDetails(0);
        assertEq(nft.name, bytes32("TestNFT"));
        assertEq(nft.price, 1 ether);
        assertEq(nft.creator, user1);
        assertEq(nft.owner, user1);
        assertEq(uint(nft.category), uint(BFXSea.Category.Art));
        assertEq(nft.supply, 10);
        assertEq(nft.minted, 1);
        assertTrue(nft.isForSale);
    }

    function testGetCreatorNFTs() public {
        testCreateNFT();
        uint256[] memory creatorNFTs = bfxSea.getCreatorNFTs(user1);
        assertEq(creatorNFTs.length, 1);
        assertEq(creatorNFTs[0], 0);
    }

    function testGetOwnerNFTs() public {
        testCreateNFT();
        uint256[] memory ownerNFTs = bfxSea.getOwnerNFTs(user1);
        assertEq(ownerNFTs.length, 1);
        assertEq(ownerNFTs[0], 0);
    }

    function testTokenURI() public {
        testCreateNFT();
        string memory uri = bfxSea.tokenURI(0);
        assertEq(uri, "tokenURI");
    }

    function testTokenURINotFound() public {
        vm.expectRevert(BFXSea.BFXSea__TokenUriNotFound.selector);
        bfxSea.tokenURI(999);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}