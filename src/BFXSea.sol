// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BFXSea is ERC721Enumerable, Ownable {
    error BFXSea__InsufficientCreationFee();
    error BFXSea__TokenUriNotFound();
    error BFXSea__InsufficientPayment();
    error BFXSea__NotForSale();
    error BFXSea__NotOwner();
    error BFXSea__SupplyExceeded();
    error BFXSea__NotOwnerOfNFT();
    error BFXSea__InvalidCollectionIndex();

    uint256 private s_tokenCounter;

    uint256 public constant CREATION_FEE_MAINNET = 0.001 ether;
    uint256 public constant CREATION_FEE_TESTNET = 0.05 ether;
    address payable public feeRecipient;
    bool public isMainnet;

    enum Category { Art, Gaming, Memberships, PFPs, Photography, Music, Movie }

    struct NFT {
        bytes32 name;
        bytes32 description;
        bytes32 tokenUri;
        uint256 price;
        address payable creator;
        address payable owner;
        uint256 createdAt;
        Category category;
        bool isForSale;
        uint256 supply;
        uint256 minted;
    }

    struct Collection {
        bytes32 name;
        bytes32 description;
        address creator;
        uint256[] tokenIds;
    }

    mapping(uint256 => NFT) private s_tokenIdToNFT;
    mapping(address => uint256[]) private s_creatorToTokenIds;
    mapping(address => uint256[]) private s_ownerToTokenIds;
    mapping(address => Collection[]) private s_creatorToCollections;

    event NFTCreated(uint256 indexed tokenId, address creator, bytes32 name, uint256 price, uint256 supply);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address seller, address buyer, uint256 price);
    event CollectionCreated(address indexed creator, bytes32 name);

    constructor(bool _isMainnet) ERC721("BFXSea", "BFXS") Ownable(msg.sender) {
        feeRecipient = payable(0xB8622ea337FE15296Cb62b984E41dC6cda7E91b5);
        isMainnet = _isMainnet;
    }

    function setFeeRecipient(address payable newRecipient) public onlyOwner {
        feeRecipient = newRecipient;
    }

function createNFT(
    bytes32 name,
    bytes32 description,
    bytes32 tokenUri,
    uint256 price,
    Category category,
    uint256 supply
) public payable {
    uint256 creationFee = isMainnet ? CREATION_FEE_MAINNET : CREATION_FEE_TESTNET;
    uint256 totalFee = creationFee * supply;
    if (msg.value < totalFee) {
        revert BFXSea__InsufficientCreationFee();
    }

    uint256 newTokenId = s_tokenCounter;
    s_tokenCounter++;

    NFT memory newNFT = NFT({
        name: name,
        description: description,
        tokenUri: tokenUri,
        price: price,
        creator: payable(msg.sender),
        owner: payable(msg.sender),
        createdAt: block.timestamp,
        category: category,
        isForSale: true,
        supply: supply,
        minted: 1
    });

    s_tokenIdToNFT[newTokenId] = newNFT;
    s_creatorToTokenIds[msg.sender].push(newTokenId);
    s_ownerToTokenIds[msg.sender].push(newTokenId);

    _safeMint(msg.sender, newTokenId);

    emit NFTCreated(newTokenId, msg.sender, name, price, supply);

    feeRecipient.transfer(totalFee);
}
    function mintNFT(uint256 tokenId) public {
        NFT storage nft = s_tokenIdToNFT[tokenId];
        if (nft.minted >= nft.supply) {
            revert BFXSea__SupplyExceeded();
        }
        
        uint256 newTokenId = s_tokenCounter;
        s_tokenCounter++;

        nft.minted++;
        s_tokenIdToNFT[newTokenId] = nft;
        s_ownerToTokenIds[msg.sender].push(newTokenId);

        _safeMint(msg.sender, newTokenId);
    }

    function buyNFT(uint256 tokenId) public payable {
        NFT storage nft = s_tokenIdToNFT[tokenId];
        if (!nft.isForSale) {
            revert BFXSea__NotForSale();
        }
        if (msg.value < nft.price) {
            revert BFXSea__InsufficientPayment();
        }

        address payable seller = nft.owner;
        nft.owner = payable(msg.sender);
        nft.isForSale = false;

        _transfer(seller, msg.sender, tokenId);
        seller.transfer(msg.value);

        removeFromArray(s_ownerToTokenIds[seller], tokenId);
        s_ownerToTokenIds[msg.sender].push(tokenId);

        emit NFTSold(tokenId, seller, msg.sender, msg.value);
    }

    function listNFTForSale(uint256 tokenId, uint256 newPrice) public {
        if (_ownerOf(tokenId) != msg.sender) {
            revert BFXSea__NotOwner();
        }
        NFT storage nft = s_tokenIdToNFT[tokenId];
        nft.price = newPrice;
        nft.isForSale = true;

        emit NFTListed(tokenId, newPrice);
    }

    function createCollection(bytes32 name, bytes32 description) public {
        Collection memory newCollection = Collection({
            name: name,
            description: description,
            creator: msg.sender,
            tokenIds: new uint256[](0)
        });

        s_creatorToCollections[msg.sender].push(newCollection);

        emit CollectionCreated(msg.sender, name);
    }

    function addNFTToCollection(uint256 tokenId, uint256 collectionIndex) public {
        if (_ownerOf(tokenId) != msg.sender) {
            revert BFXSea__NotOwnerOfNFT();
        }
        if (collectionIndex >= s_creatorToCollections[msg.sender].length) {
            revert BFXSea__InvalidCollectionIndex();
        }

        s_creatorToCollections[msg.sender][collectionIndex].tokenIds.push(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) {
            revert BFXSea__TokenUriNotFound();
        }
        return bytes32ToString(s_tokenIdToNFT[tokenId].tokenUri);
    }

    function getNFTDetails(uint256 tokenId) public view returns (NFT memory) {
        return s_tokenIdToNFT[tokenId];
    }

    function getCreatorNFTs(address creator) public view returns (uint256[] memory) {
        return s_creatorToTokenIds[creator];
    }

    function getOwnerNFTs(address owner) public view returns (uint256[] memory) {
        return s_ownerToTokenIds[owner];
    }

    function getCreatorCollections(address creator) public view returns (Collection[] memory) {
        return s_creatorToCollections[creator];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function removeFromArray(uint256[] storage array, uint256 value) internal {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
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