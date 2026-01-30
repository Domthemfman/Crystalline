// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Crystalline Truth Network - FIXED for OpenZeppelin 5.0
 * @dev Decentralized truth platform for survivors
 */

// ============================================================================
// SIMPLE VERSION - Easy to Deploy
// ============================================================================

contract CrystallineTruth {
    
    struct Post {
        uint256 id;
        address author;
        string encryptedContent;
        string ipfsHash;
        string community;
        uint256 timestamp;
        uint256 verifications;
        bool exists;
    }
    
    // State
    mapping(uint256 => Post) public posts;
    mapping(uint256 => mapping(address => bool)) public hasVerified;
    uint256 public postCount;
    address public owner;
    
    // Gas Fee Pool
    uint256 public totalDeposited;
    uint256 public totalSpent;
    
    // Events
    event PostCreated(uint256 indexed postId, address indexed author, string community);
    event PostVerified(uint256 indexed postId, address indexed verifier);
    event GasSponsored(address indexed user, uint256 amount);
    
    constructor() {
        owner = msg.sender;
        postCount = 0;
    }
    
    // Create Post
    function createPost(
        string memory encryptedContent,
        string memory ipfsHash,
        string memory community
    ) external returns (uint256) {
        postCount++;
        
        posts[postCount] = Post({
            id: postCount,
            author: msg.sender,
            encryptedContent: encryptedContent,
            ipfsHash: ipfsHash,
            community: community,
            timestamp: block.timestamp,
            verifications: 0,
            exists: true
        });
        
        emit PostCreated(postCount, msg.sender, community);
        return postCount;
    }
    
    // Verify Post
    function verifyPost(uint256 postId) external {
        require(posts[postId].exists, "Post does not exist");
        require(!hasVerified[postId][msg.sender], "Already verified");
        
        posts[postId].verifications++;
        hasVerified[postId][msg.sender] = true;
        
        emit PostVerified(postId, msg.sender);
    }
    
    // Get Post
    function getPost(uint256 postId) external view returns (
        address author,
        string memory encryptedContent,
        string memory ipfsHash,
        string memory community,
        uint256 timestamp,
        uint256 verifications
    ) {
        require(posts[postId].exists, "Post does not exist");
        Post memory post = posts[postId];
        return (
            post.author,
            post.encryptedContent,
            post.ipfsHash,
            post.community,
            post.timestamp,
            post.verifications
        );
    }
    
    // Gas Fee Pool - Receive deposits
    receive() external payable {
        totalDeposited += msg.value;
    }
    
    // Sponsor user gas fee
    function sponsorGas(address user, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(address(this).balance >= amount, "Insufficient balance");
        
        totalSpent += amount;
        payable(user).call{value: amount}("");
        
        emit GasSponsored(user, amount);
    }
    
    // Withdraw platform fee (2%)
    function withdrawPlatformFee() external {
        require(msg.sender == owner, "Only owner");
        
        uint256 platformFee = (totalDeposited * 2) / 100;
        uint256 available = address(this).balance;
        uint256 amount = platformFee < available ? platformFee : available;
        
        require(amount > 0, "Nothing to withdraw");
        payable(owner).call{value: amount}("");
    }
    
    // Get stats
    function getStats() external view returns (
        uint256 balance,
        uint256 deposited,
        uint256 spent,
        uint256 totalPosts
    ) {
        return (
            address(this).balance,
            totalDeposited,
            totalSpent,
            postCount
        );
    }
}
