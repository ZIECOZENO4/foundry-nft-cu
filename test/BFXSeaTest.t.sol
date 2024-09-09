// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BFXSea} from "../src/BFXSea.sol";

contract BFXSeaTest is Test {
    BFXSea public bfxSea;
    address public owner;
    address public user1;
    address public user2;
    uint256 public constant INITIAL_BALANCE = 100 ether;

    event NFTCreated(uint256 indexed tokenId, address creator, bytes32 name, uint256 price, uint256 supply);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event CollectionCreated(address indexed creator, bytes32 name);

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        vm.deal(owner, INITIAL_BALANCE);
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
        bfxSea = new BFXSea(true); // Deploy with isMainnet = true
        console.log("BFXSea deployed at:", address(bfxSea));
    }

function testDeployment() public view {
    assertTrue(address(bfxSea) != address(0), "BFXSea not deployed");
    assertEq(bfxSea.owner(), owner, "Owner not set correctly");
    assertTrue(bfxSea.isMainnet(), "isMainnet not set correctly");
    console.log("Deployment test passed");
}

    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0x123);
        vm.prank(owner);
        bfxSea.setFeeRecipient(payable(newFeeRecipient));
        assertEq(bfxSea.feeRecipient(), newFeeRecipient, "Fee recipient not updated");
        console.log("Fee recipient updated to:", newFeeRecipient);
    }

    function testSetFeeRecipientNotOwner() public {
        address newFeeRecipient = address(0x123);
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        bfxSea.setFeeRecipient(payable(newFeeRecipient));
        console.log("Non-owner fee recipient update reverted as expected");
    }

    function testCreateNFT() public {
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit NFTCreated(0, user1, bytes32("TestNFT"), 1 ether, 10);
        bfxSea.createNFT{value: 0.001 ether}(
            bytes32("TestNFT"),
            bytes32("Description"),
            bytes32("tokenURI"),
            1 ether,
            BFXSea.Category.Art,
            10
        );
        vm.stopPrank();
        assertEq(bfxSea.getTokenCounter(), 1);
        assertEq(bfxSea.ownerOf(0), user1);
        console.log("NFT created successfully. Token ID:", 0);
    }

    function testCreateNFTInsufficientFee() public {
        vm.startPrank(user1);
        vm.expectRevert(BFXSea.BFXSea__InsufficientCreationFee.selector);
        bfxSea.createNFT{value: 0.0009 ether}(
            bytes32("TestNFT"),
            bytes32("Description"),
            bytes32("tokenURI"),
            1 ether,
            BFXSea.Category.Art,
            10
        );
        vm.stopPrank();
        console.log("Insufficient fee test passed");
    }

    function testMintNFT() public {
        testCreateNFT();
        vm.startPrank(user2);
        bfxSea.mintNFT(0);
        vm.stopPrank();
        assertEq(bfxSea.getTokenCounter(), 2);
        assertEq(bfxSea.ownerOf(1), user2);
        console.log("NFT minted successfully. New Token ID:", 1);
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
        console.log("Supply exceeded test passed");
    }

 function testBuyNFT() public {
    testCreateNFT();
    vm.prank(user1);
    bfxSea.listNFTForSale(0, 1 ether);
    vm.startPrank(user2);
    vm.expectEmit(true, true, true, true);
    emit NFTSold(0, user1, user2, 1 ether);
    bfxSea.buyNFT{value: 1 ether}(0);
    vm.stopPrank();
    assertEq(bfxSea.ownerOf(0), user2);
    console.log("NFT bought successfully. New owner:", user2);
}

    function testBuyNFTInsufficientPayment() public {
        testCreateNFT();
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__InsufficientPayment.selector);
        bfxSea.buyNFT{value: 0.9 ether}(0);
        vm.stopPrank();
        console.log("Insufficient payment test passed");
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
        console.log("NFT listed for sale. New price:", nft.price);
    }

    function testListNFTForSaleNotOwner() public {
        testCreateNFT();
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__NotOwner.selector);
        bfxSea.listNFTForSale(0, 2 ether);
        vm.stopPrank();
        console.log("List for sale by non-owner test passed");
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
        console.log("Collection created successfully");
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
        console.log("NFT added to collection successfully");
    }

    function testAddNFTToCollectionNotOwner() public {
        testCreateNFT();
        testCreateCollection();
        vm.startPrank(user2);
        vm.expectRevert(BFXSea.BFXSea__NotOwnerOfNFT.selector);
        bfxSea.addNFTToCollection(0, 0);
        vm.stopPrank();
        console.log("Add to collection by non-owner test passed");
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
        vm.startPrank(user1);
        bfxSea.createNFT{value: 0.001 ether}(
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
        console.log("Fuzz test: NFT created with name:", bytes32ToString(name));
    }

    function testFuzzBuyNFT(uint256 paymentAmount) public {
        testCreateNFT();
        vm.assume(paymentAmount >= 1 ether && paymentAmount < 100 ether);
        vm.startPrank(user2);
        bfxSea.buyNFT{value: paymentAmount}(0);
        vm.stopPrank();
        assertEq(bfxSea.ownerOf(0), user2);
        console.log("Fuzz test: NFT bought with payment:", paymentAmount);
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
        console.log("Fuzz test: NFT listed for sale at price:", newPrice);
    }

function testMultipleTransactions() public {
    // Create NFT
    vm.startPrank(user1);
    bfxSea.createNFT{value: 0.01 ether}(
        bytes32("TestNFT"),
        bytes32("Description"),
        bytes32("tokenURI"),
        1 ether,
        BFXSea.Category.Art,
        10
    );
    // List for sale
    bfxSea.listNFTForSale(0, 2 ether);
    vm.stopPrank();
    // Buy NFT
    vm.prank(user2);
    bfxSea.buyNFT{value: 2 ether}(0);
    // Create collection
    vm.prank(user2);
    bfxSea.createCollection(bytes32("MyCollection"), bytes32("Description"));
    // Add NFT to collection
    vm.prank(user2);
    bfxSea.addNFTToCollection(0, 0);
    // Assert final state
    assertEq(bfxSea.ownerOf(0), user2);
    BFXSea.Collection[] memory collections = bfxSea.getCreatorCollections(user2);
    assertEq(collections[0].tokenIds.length, 1);
    assertEq(collections[0].tokenIds[0], 0);
    console.log("Multiple transactions test passed");
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
        console.log("Get NFT details test passed");
    }

    function testGetCreatorNFTs() public {
        testCreateNFT();
        uint256[] memory creatorNFTs = bfxSea.getCreatorNFTs(user1);
        assertEq(creatorNFTs.length, 1);
        assertEq(creatorNFTs[0], 0);
        console.log("Get creator NFTs test passed");
    }

    function testGetOwnerNFTs() public {
        testCreateNFT();
        uint256[] memory ownerNFTs = bfxSea.getOwnerNFTs(user1);
        assertEq(ownerNFTs.length, 1);
        assertEq(ownerNFTs[0], 0);
        console.log("Get owner NFTs test passed");
    }

    function testTokenURI() public {
        testCreateNFT();
        string memory uri = bfxSea.tokenURI(0);
        assertEq(uri, "tokenURI");
        console.log("Token URI test passed");
    }

    function testTokenURINotFound() public {
        vm.expectRevert(BFXSea.BFXSea__TokenUriNotFound.selector);
        bfxSea.tokenURI(999);
        console.log("Token URI not found test passed");
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