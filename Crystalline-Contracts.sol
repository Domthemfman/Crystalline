// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Crystalline Truth Network - Smart Contracts
 * @dev Decentralized truth platform for survivors
 * @notice Posts are permanent, immutable, and uncensorable
 */

// ============================================================================
// TRUTH TOKEN (ERC-20) - Verification Rewards
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TruthToken is ERC20, Ownable {
    constructor() ERC20("Truth Token", "TRUTH") {
        // Mint initial supply to contract for rewards
        _mint(address(this), 1000000 * 10**decimals());
    }
    
    function reward(address recipient, uint256 amount) external onlyOwner {
        _transfer(address(this), recipient, amount);
    }
}

// ============================================================================
// CRYSTALLINE POST STORAGE - Main Contract
// ============================================================================

contract CrystallineNetwork {
    
    struct Post {
        uint256 id;
        address author;
        string encryptedContent;  // AES-256 encrypted post data
        string ipfsHash;          // IPFS hash for media files
        string community;         // gate, trafficking, ritual, etc.
        uint256 timestamp;
        uint256 verifications;
        bool exists;
    }
    
    struct Verification {
        address verifier;
        uint256 timestamp;
    }
    
    // State variables
    mapping(uint256 => Post) public posts;
    mapping(uint256 => mapping(address => bool)) public hasVerified;
    mapping(uint256 => Verification[]) public postVerifications;
    uint256 public postCount;
    
    TruthToken public truthToken;
    address public gasFeePool;
    
    // Events
    event PostCreated(
        uint256 indexed postId,
        address indexed author,
        string community,
        uint256 timestamp
    );
    
    event PostVerified(
        uint256 indexed postId,
        address indexed verifier,
        uint256 timestamp
    );
    
    event TokensRewarded(
        address indexed recipient,
        uint256 amount,
        string reason
    );
    
    // Modifiers
    modifier postExists(uint256 postId) {
        require(posts[postId].exists, "Post does not exist");
        _;
    }
    
    modifier hasNotVerified(uint256 postId) {
        require(!hasVerified[postId][msg.sender], "Already verified this post");
        _;
    }
    
    constructor(address _truthToken, address _gasFeePool) {
        truthToken = TruthToken(_truthToken);
        gasFeePool = _gasFeePool;
        postCount = 0;
    }
    
    /**
     * @dev Create a new post on the blockchain
     * @param encryptedContent AES-256 encrypted post data
     * @param ipfsHash IPFS hash for any media files
     * @param community Community identifier (gate, trafficking, etc.)
     * @return postId The ID of the newly created post
     */
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
        
        emit PostCreated(postCount, msg.sender, community, block.timestamp);
        
        // Reward poster with TRUTH tokens
        truthToken.reward(msg.sender, 10 * 10**18); // 10 TRUTH tokens
        emit TokensRewarded(msg.sender, 10 * 10**18, "Post created");
        
        return postCount;
    }
    
    /**
     * @dev Verify a post (community verification "I experienced this too")
     * @param postId The ID of the post to verify
     */
    function verifyPost(uint256 postId) 
        external 
        postExists(postId) 
        hasNotVerified(postId) 
    {
        posts[postId].verifications++;
        hasVerified[postId][msg.sender] = true;
        
        postVerifications[postId].push(Verification({
            verifier: msg.sender,
            timestamp: block.timestamp
        }));
        
        emit PostVerified(postId, msg.sender, block.timestamp);
        
        // Reward verifier with TRUTH tokens
        truthToken.reward(msg.sender, 5 * 10**18); // 5 TRUTH tokens
        emit TokensRewarded(msg.sender, 5 * 10**18, "Post verified");
        
        // Reward original poster for verified post
        truthToken.reward(posts[postId].author, 5 * 10**18);
        emit TokensRewarded(posts[postId].author, 5 * 10**18, "Post was verified");
    }
    
    /**
     * @dev Get post details
     * @param postId The ID of the post
     */
    function getPost(uint256 postId) 
        external 
        view 
        postExists(postId) 
        returns (
            address author,
            string memory encryptedContent,
            string memory ipfsHash,
            string memory community,
            uint256 timestamp,
            uint256 verifications
        ) 
    {
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
    
    /**
     * @dev Get verification count for a post
     * @param postId The ID of the post
     */
    function getVerificationCount(uint256 postId) 
        external 
        view 
        postExists(postId) 
        returns (uint256) 
    {
        return posts[postId].verifications;
    }
    
    /**
     * @dev Get all verifiers for a post
     * @param postId The ID of the post
     */
    function getVerifiers(uint256 postId) 
        external 
        view 
        postExists(postId) 
        returns (Verification[] memory) 
    {
        return postVerifications[postId];
    }
}

// ============================================================================
// GAS FEE POOL - Revenue Management
// ============================================================================

contract GasFeePool {
    address public owner;
    address public crystallineContract;
    
    uint256 public totalDeposited;
    uint256 public totalSpent;
    uint256 public platformFee = 2; // 2% for maintenance
    
    event Deposited(address indexed from, uint256 amount);
    event GasFeeSponsored(address indexed user, uint256 amount);
    event PlatformFeeWithdrawn(address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyCrystalline() {
        require(msg.sender == crystallineContract, "Not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function setCrystallineContract(address _contract) external onlyOwner {
        crystallineContract = _contract;
    }
    
    /**
     * @dev Deposit funds to the gas pool (from ads, donations, etc.)
     */
    function deposit() external payable {
        require(msg.value > 0, "Must send funds");
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Sponsor gas fee for a user posting
     * @param user Address of the user
     * @param amount Amount of gas to sponsor
     */
    function sponsorGasFee(address user, uint256 amount) external onlyCrystalline {
        require(address(this).balance >= amount, "Insufficient pool balance");
        totalSpent += amount;
        payable(user).transfer(amount);
        emit GasFeeSponsored(user, amount);
    }
    
    /**
     * @dev Withdraw platform maintenance fee (2%)
     */
    function withdrawPlatformFee() external onlyOwner {
        uint256 availableFee = (totalDeposited * platformFee) / 100;
        uint256 balance = address(this).balance;
        uint256 withdrawAmount = availableFee < balance ? availableFee : balance;
        
        require(withdrawAmount > 0, "No fees to withdraw");
        
        payable(owner).transfer(withdrawAmount);
        emit PlatformFeeWithdrawn(owner, withdrawAmount);
    }
    
    /**
     * @dev Get pool statistics
     */
    function getPoolStats() external view returns (
        uint256 balance,
        uint256 deposited,
        uint256 spent,
        uint256 availableForGas
    ) {
        uint256 platformAllocation = (totalDeposited * platformFee) / 100;
        uint256 gasAllocation = totalDeposited - platformAllocation;
        uint256 remainingGas = gasAllocation - totalSpent;
        
        return (
            address(this).balance,
            totalDeposited,
            totalSpent,
            remainingGas
        );
    }
    
    receive() external payable {
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}

// ============================================================================
// DEPLOYMENT NOTES
// ============================================================================

/**
 * DEPLOYMENT ORDER:
 * 
 * 1. Deploy TruthToken
 * 2. Deploy GasFeePool
 * 3. Deploy CrystallineNetwork(truthTokenAddress, gasFeePoolAddress)
 * 4. Call GasFeePool.setCrystallineContract(crystallineNetworkAddress)
 * 5. Transfer TruthToken ownership to CrystallineNetwork
 * 
 * NETWORK: Polygon Mainnet (Chain ID: 137)
 * GAS: ~0.01 MATIC per transaction
 * 
 * FUNCTIONS:
 * - createPost(encryptedContent, ipfsHash, community) → Creates permanent post
 * - verifyPost(postId) → Community verification
 * - getPost(postId) → Retrieve post data
 * 
 * REVENUE SPLIT:
 * - 98% stays in pool for gas fees
 * - 2% withdrawable for platform maintenance
 * 
 * SECURITY:
 * - Posts are immutable once created
 * - Only encrypted content stored on-chain
 * - IPFS for media files (decentralized)
 * - No admin deletion functions (truly uncensorable)
 */