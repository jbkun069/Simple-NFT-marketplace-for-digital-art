// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleNFTMarketplace is ERC721, Ownable, ReentrancyGuard {
    uint256 private _tokenIdCounter;
    uint256 public platformFee = 25; // 2.5% platform fee (25/1000)
    
    struct NFTListing {
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool isActive;
    }
    
    mapping(uint256 => NFTListing) public listings;
    mapping(uint256 => string) private _tokenURIs;
    
    event NFTMinted(uint256 indexed tokenId, address indexed creator, string tokenURI);
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed tokenId, address indexed seller);
    
    constructor() ERC721("SimpleArtNFT", "SANFT") Ownable(msg.sender) {}
    
    // Function 1: Mint NFT
    function mintNFT(string memory _tokenURI) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        emit NFTMinted(tokenId, msg.sender, _tokenURI);
        return tokenId;
    }
    
    // Function 2: List NFT for sale
    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(price > 0, "Price must be greater than 0");
        require(!listings[tokenId].isActive, "NFT is already listed");
        
        listings[tokenId] = NFTListing({
            tokenId: tokenId,
            seller: payable(msg.sender),
            price: price,
            isActive: true
        });
        
        // Transfer NFT to marketplace contract
        _transfer(msg.sender, address(this), tokenId);
        
        emit NFTListed(tokenId, msg.sender, price);
    }
    
    // Function 3: Buy NFT
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        NFTListing memory listing = listings[tokenId];
        require(listing.isActive, "NFT is not for sale");
        require(msg.value >= listing.price, "Insufficient payment");
        
        // Calculate platform fee
        uint256 fee = (listing.price * platformFee) / 1000;
        uint256 sellerAmount = listing.price - fee;
        
        // Mark listing as inactive
        listings[tokenId].isActive = false;
        
        // Transfer NFT to buyer
        _transfer(address(this), msg.sender, tokenId);
        
        // Transfer payment to seller
        listing.seller.transfer(sellerAmount);
        
        // Refund excess payment
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit NFTSold(tokenId, msg.sender, listing.seller, listing.price);
    }
    
    // Function 4: Cancel listing
    function cancelListing(uint256 tokenId) external {
        NFTListing memory listing = listings[tokenId];
        require(listing.seller == msg.sender, "You are not the seller");
        require(listing.isActive, "Listing is not active");
        
        // Mark listing as inactive
        listings[tokenId].isActive = false;
        
        // Return NFT to seller
        _transfer(address(this), msg.sender, tokenId);
        
        emit ListingCancelled(tokenId, msg.sender);
    }
    
    // Function 5: Get NFT details
    function getNFTDetails(uint256 tokenId) external view returns (
        address owner,
        string memory uri,
        bool isListed,
        uint256 price,
        address seller
    ) {
        owner = ownerOf(tokenId);
        uri = _tokenURIs[tokenId];
        
        NFTListing memory listing = listings[tokenId];
        isListed = listing.isActive;
        price = listing.price;
        seller = listing.seller;
    }
    
    // Internal function to set token URI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    // Override tokenURI function
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }
    
    // Withdraw platform fees (only owner)
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Get total supply
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
