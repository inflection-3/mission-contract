// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IdentityLayer
 * @dev Decentralized Identity (DID) management contract
 * Manages identity registration, verification, credential management, and reputation tracking
 */
contract IdentityLayer is Ownable, ReentrancyGuard {
    struct Identity {
        address owner;
        bytes32 did; // Decentralized Identifier
        string metadataUri; // IPFS or other URI for identity metadata
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    struct ReputationMetrics {
        uint256 reputationScore; // Overall reputation score (0-10000, where 10000 = perfect)
        uint256 transactionCount; // Total number of transactions
        uint256 totalVolume; // Total transaction volume in USDC (6 decimals)
        uint256 successfulTransactions; // Number of successful transactions
        uint256 failedTransactions; // Number of failed transactions
        uint256 lastActivityTimestamp; // Last activity timestamp
        uint256 accountAge; // Account age in seconds
        uint256 onboardingCount; // Number of people onboarded (for miners)
        uint256 contributionsCount; // Number of contributions made
        uint256 rewardsEarned; // Total rewards earned (in points or USDC)
        uint256 averageTransactionValue; // Average transaction value
        uint256 streakDays; // Consecutive days of activity
        uint256 lastStreakUpdate; // Last streak update timestamp
    }

    struct Credential {
        bytes32 credentialId;
        bytes32 issuerDid;
        bytes32 subjectDid;
        string credentialType;
        bytes32 dataHash; // Hash of credential data
        uint256 issuedAt;
        uint256 expiresAt;
        bool isRevoked;
    }

    // Mapping from address to DID
    mapping(address => bytes32) public addressToDid;
    mapping(bytes32 => Identity) public identities;
    mapping(bytes32 => Credential) public credentials;
    
    // Reputation tracking by DID and address
    mapping(bytes32 => ReputationMetrics) public didReputation;
    mapping(address => ReputationMetrics) public addressReputation;
    
    // Track credentials by DID
    mapping(bytes32 => bytes32[]) public didCredentials;
    
    // Authorized contracts that can update reputation
    mapping(address => bool) public authorizedUpdaters;
    
    uint256 public totalIdentities;
    uint256 public totalCredentials;
    
    // Reputation calculation weights (basis points)
    uint256 public transactionWeight = 1000; // 10%
    uint256 public volumeWeight = 2000; // 20%
    uint256 public successRateWeight = 3000; // 30%
    uint256 public activityWeight = 1500; // 15%
    uint256 public onboardingWeight = 1500; // 15%
    uint256 public streakWeight = 1000; // 10%
    
    event IdentityRegistered(address indexed owner, bytes32 indexed did, string metadataUri);
    event IdentityUpdated(bytes32 indexed did, string newMetadataUri);
    event IdentityDeactivated(bytes32 indexed did);
    event CredentialIssued(
        bytes32 indexed credentialId,
        bytes32 indexed issuerDid,
        bytes32 indexed subjectDid,
        string credentialType
    );
    event CredentialRevoked(bytes32 indexed credentialId);
    event DidLinked(address indexed account, bytes32 indexed did);
    event ReputationUpdated(
        bytes32 indexed did,
        address indexed account,
        uint256 newReputationScore
    );
    event TransactionRecorded(
        bytes32 indexed did,
        address indexed account,
        uint256 amount,
        bool success
    );
    event VolumeUpdated(
        bytes32 indexed did,
        address indexed account,
        uint256 newTotalVolume
    );
    event AuthorizedUpdaterSet(address indexed updater, bool authorized);
    
    modifier onlyIdentityOwner(bytes32 did) {
        require(identities[did].owner == msg.sender, "Not identity owner");
        require(identities[did].isActive, "Identity not active");
        _;
    }
    
    modifier validDid(bytes32 did) {
        require(identities[did].did != bytes32(0), "Invalid DID");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Owner is authorized by default
        authorizedUpdaters[msg.sender] = true;
    }
    
    /**
     * @dev Set authorized updater for reputation metrics
     * @param updater Address of the contract/account that can update reputation
     * @param authorized Whether the updater is authorized
     */
    function setAuthorizedUpdater(address updater, bool authorized) external onlyOwner {
        authorizedUpdaters[updater] = authorized;
        emit AuthorizedUpdaterSet(updater, authorized);
    }
    
    modifier onlyAuthorizedUpdater() {
        require(authorizedUpdaters[msg.sender], "Not authorized to update reputation");
        _;
    }
    
    /**
     * @dev Register a new identity (DID)
     * @param did The decentralized identifier
     * @param metadataUri URI pointing to identity metadata
     */
    function registerIdentity(bytes32 did, string memory metadataUri) external nonReentrant {
        require(did != bytes32(0), "Invalid DID");
        require(identities[did].did == bytes32(0), "DID already exists");
        require(addressToDid[msg.sender] == bytes32(0), "Address already has DID");
        
        identities[did] = Identity({
            owner: msg.sender,
            did: did,
            metadataUri: metadataUri,
            isActive: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        addressToDid[msg.sender] = did;
        totalIdentities++;
        
        // Initialize reputation metrics
        didReputation[did] = ReputationMetrics({
            reputationScore: 5000, // Start with 50% reputation
            transactionCount: 0,
            totalVolume: 0,
            successfulTransactions: 0,
            failedTransactions: 0,
            lastActivityTimestamp: block.timestamp,
            accountAge: 0,
            onboardingCount: 0,
            contributionsCount: 0,
            rewardsEarned: 0,
            averageTransactionValue: 0,
            streakDays: 0,
            lastStreakUpdate: block.timestamp
        });
        
        addressReputation[msg.sender] = didReputation[did];
        
        emit IdentityRegistered(msg.sender, did, metadataUri);
        emit DidLinked(msg.sender, did);
    }
    
    /**
     * @dev Link an existing address to a DID
     * @param did The decentralized identifier
     */
    function linkAddressToDid(bytes32 did) external validDid(did) {
        require(addressToDid[msg.sender] == bytes32(0), "Address already linked");
        require(identities[did].isActive, "Identity not active");
        
        // Only allow linking if the identity owner approves or if it's the owner
        // For now, allow any address to link (can be restricted later)
        addressToDid[msg.sender] = did;
        
        emit DidLinked(msg.sender, did);
    }
    
    /**
     * @dev Update identity metadata
     * @param did The decentralized identifier
     * @param newMetadataUri New metadata URI
     */
    function updateIdentity(bytes32 did, string memory newMetadataUri) 
        external 
        onlyIdentityOwner(did) 
    {
        require(bytes(newMetadataUri).length > 0, "Invalid metadata URI");
        
        identities[did].metadataUri = newMetadataUri;
        identities[did].updatedAt = block.timestamp;
        
        emit IdentityUpdated(did, newMetadataUri);
    }
    
    /**
     * @dev Deactivate an identity
     * @param did The decentralized identifier
     */
    function deactivateIdentity(bytes32 did) external onlyIdentityOwner(did) {
        identities[did].isActive = false;
        identities[did].updatedAt = block.timestamp;
        
        emit IdentityDeactivated(did);
    }
    
    /**
     * @dev Issue a credential to a DID
     * @param credentialId Unique identifier for the credential
     * @param issuerDid DID of the credential issuer
     * @param subjectDid DID of the credential subject
     * @param credentialType Type of credential (e.g., "VerifiableCredential")
     * @param dataHash Hash of the credential data
     * @param expiresAt Expiration timestamp (0 for no expiration)
     */
    function issueCredential(
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 subjectDid,
        string memory credentialType,
        bytes32 dataHash,
        uint256 expiresAt
    ) external validDid(issuerDid) validDid(subjectDid) {
        require(identities[issuerDid].owner == msg.sender, "Not issuer");
        require(identities[issuerDid].isActive, "Issuer identity not active");
        require(identities[subjectDid].isActive, "Subject identity not active");
        require(credentials[credentialId].credentialId == bytes32(0), "Credential already exists");
        require(expiresAt == 0 || expiresAt > block.timestamp, "Invalid expiration");
        
        credentials[credentialId] = Credential({
            credentialId: credentialId,
            issuerDid: issuerDid,
            subjectDid: subjectDid,
            credentialType: credentialType,
            dataHash: dataHash,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            isRevoked: false
        });
        
        didCredentials[subjectDid].push(credentialId);
        totalCredentials++;
        
        emit CredentialIssued(credentialId, issuerDid, subjectDid, credentialType);
    }
    
    /**
     * @dev Revoke a credential
     * @param credentialId The credential identifier
     */
    function revokeCredential(bytes32 credentialId) external {
        Credential storage credential = credentials[credentialId];
        require(credential.credentialId != bytes32(0), "Credential does not exist");
        require(identities[credential.issuerDid].owner == msg.sender, "Not credential issuer");
        require(!credential.isRevoked, "Credential already revoked");
        
        credential.isRevoked = true;
        
        emit CredentialRevoked(credentialId);
    }
    
    /**
     * @dev Verify if a credential is valid
     * @param credentialId The credential identifier
     * @return isValid True if credential is valid and not expired/revoked
     */
    function verifyCredential(bytes32 credentialId) external view returns (bool isValid) {
        Credential memory credential = credentials[credentialId];
        
        if (credential.credentialId == bytes32(0)) return false;
        if (credential.isRevoked) return false;
        if (credential.expiresAt != 0 && credential.expiresAt < block.timestamp) return false;
        if (!identities[credential.issuerDid].isActive) return false;
        if (!identities[credential.subjectDid].isActive) return false;
        
        return true;
    }
    
    /**
     * @dev Record a transaction and update reputation metrics
     * @param account Address of the account
     * @param amount Transaction amount in USDC (6 decimals)
     * @param success Whether the transaction was successful
     */
    function recordTransaction(
        address account,
        uint256 amount,
        bool success
    ) external onlyAuthorizedUpdater {
        bytes32 did = addressToDid[account];
        if (did == bytes32(0)) return; // No DID linked, skip
        
        ReputationMetrics storage metrics = didReputation[did];
        ReputationMetrics storage addressMetrics = addressReputation[account];
        
        metrics.transactionCount++;
        addressMetrics.transactionCount++;
        
        if (success) {
            metrics.successfulTransactions++;
            addressMetrics.successfulTransactions++;
            metrics.totalVolume += amount;
            addressMetrics.totalVolume += amount;
            
            // Update average transaction value
            if (metrics.transactionCount > 0) {
                metrics.averageTransactionValue = metrics.totalVolume / metrics.transactionCount;
            }
            if (addressMetrics.transactionCount > 0) {
                addressMetrics.averageTransactionValue = addressMetrics.totalVolume / addressMetrics.transactionCount;
            }
            
            emit VolumeUpdated(did, account, metrics.totalVolume);
        } else {
            metrics.failedTransactions++;
            addressMetrics.failedTransactions++;
        }
        
        // Update activity timestamp and streak
        _updateActivityStreak(did, account, metrics, addressMetrics);
        
        // Recalculate reputation score
        _updateReputationScore(did, account, metrics, addressMetrics);
        
        emit TransactionRecorded(did, account, amount, success);
    }
    
    /**
     * @dev Update onboarding count (for miners)
     * @param account Address of the miner
     * @param count Number of people onboarded
     */
    function updateOnboardingCount(address account, uint256 count) external onlyAuthorizedUpdater {
        bytes32 did = addressToDid[account];
        if (did == bytes32(0)) return;
        
        ReputationMetrics storage metrics = didReputation[did];
        ReputationMetrics storage addressMetrics = addressReputation[account];
        
        metrics.onboardingCount += count;
        addressMetrics.onboardingCount += count;
        
        _updateActivityStreak(did, account, metrics, addressMetrics);
        _updateReputationScore(did, account, metrics, addressMetrics);
    }
    
    /**
     * @dev Update contributions count
     * @param account Address of the contributor
     * @param count Number of contributions
     */
    function updateContributionsCount(address account, uint256 count) external onlyAuthorizedUpdater {
        bytes32 did = addressToDid[account];
        if (did == bytes32(0)) return;
        
        ReputationMetrics storage metrics = didReputation[did];
        ReputationMetrics storage addressMetrics = addressReputation[account];
        
        metrics.contributionsCount += count;
        addressMetrics.contributionsCount += count;
        
        _updateActivityStreak(did, account, metrics, addressMetrics);
        _updateReputationScore(did, account, metrics, addressMetrics);
    }
    
    /**
     * @dev Update rewards earned
     * @param account Address of the account
     * @param amount Reward amount (in points or USDC)
     */
    function updateRewardsEarned(address account, uint256 amount) external onlyAuthorizedUpdater {
        bytes32 did = addressToDid[account];
        if (did == bytes32(0)) return;
        
        ReputationMetrics storage metrics = didReputation[did];
        ReputationMetrics storage addressMetrics = addressReputation[account];
        
        metrics.rewardsEarned += amount;
        addressMetrics.rewardsEarned += amount;
        
        _updateActivityStreak(did, account, metrics, addressMetrics);
        _updateReputationScore(did, account, metrics, addressMetrics);
    }
    
    /**
     * @dev Internal function to update activity streak
     */
    function _updateActivityStreak(
        bytes32 did,
        address account,
        ReputationMetrics storage metrics,
        ReputationMetrics storage addressMetrics
    ) internal {
        uint256 daysSinceLastUpdate = (block.timestamp - metrics.lastStreakUpdate) / 1 days;
        
        if (daysSinceLastUpdate == 0) {
            // Same day, increment streak
            metrics.streakDays++;
            addressMetrics.streakDays++;
        } else if (daysSinceLastUpdate == 1) {
            // Consecutive day, increment streak
            metrics.streakDays++;
            addressMetrics.streakDays++;
        } else {
            // Streak broken, reset to 1
            metrics.streakDays = 1;
            addressMetrics.streakDays = 1;
        }
        
        metrics.lastStreakUpdate = block.timestamp;
        addressMetrics.lastStreakUpdate = block.timestamp;
        metrics.lastActivityTimestamp = block.timestamp;
        addressMetrics.lastActivityTimestamp = block.timestamp;
        
        // Update account age
        Identity memory identity = identities[did];
        if (identity.createdAt > 0) {
            metrics.accountAge = block.timestamp - identity.createdAt;
            addressMetrics.accountAge = metrics.accountAge;
        }
    }
    
    /**
     * @dev Internal function to recalculate reputation score
     */
    function _updateReputationScore(
        bytes32 did,
        address account,
        ReputationMetrics storage metrics,
        ReputationMetrics storage addressMetrics
    ) internal {
        uint256 score = 0;
        
        // Transaction count component (capped at 1000 points)
        uint256 txScore = metrics.transactionCount > 100 ? 1000 : (metrics.transactionCount * 10);
        score += (txScore * transactionWeight) / 10000;
        
        // Volume component (normalized, capped at 2000 points)
        uint256 volumeScore = metrics.totalVolume > 1000000 * 1e6 ? 2000 : (metrics.totalVolume / 500000);
        if (volumeScore > 2000) volumeScore = 2000;
        score += (volumeScore * volumeWeight) / 10000;
        
        // Success rate component (0-3000 points)
        uint256 successRate = 0;
        if (metrics.transactionCount > 0) {
            successRate = (metrics.successfulTransactions * 3000) / metrics.transactionCount;
        }
        score += (successRate * successRateWeight) / 10000;
        
        // Activity component (based on recent activity and streak)
        uint256 activityScore = 0;
        uint256 daysSinceActivity = (block.timestamp - metrics.lastActivityTimestamp) / 1 days;
        if (daysSinceActivity <= 7) {
            activityScore = 1500 - (daysSinceActivity * 200); // Decay over 7 days
        }
        score += (activityScore * activityWeight) / 10000;
        
        // Onboarding component (capped at 1500 points)
        uint256 onboardingScore = metrics.onboardingCount > 50 ? 1500 : (metrics.onboardingCount * 30);
        score += (onboardingScore * onboardingWeight) / 10000;
        
        // Streak component (capped at 1000 points)
        uint256 streakScore = metrics.streakDays > 30 ? 1000 : (metrics.streakDays * 33);
        score += (streakScore * streakWeight) / 10000;
        
        // Cap score at 10000
        if (score > 10000) score = 10000;
        
        metrics.reputationScore = score;
        addressMetrics.reputationScore = score;
        
        emit ReputationUpdated(did, account, score);
    }
    
    /**
     * @dev Get identity information
     * @param did The decentralized identifier
     * @return Identity struct
     */
    function getIdentity(bytes32 did) external view returns (Identity memory) {
        require(identities[did].did != bytes32(0), "Identity does not exist");
        return identities[did];
    }
    
    /**
     * @dev Get reputation metrics for a DID
     * @param did The decentralized identifier
     * @return ReputationMetrics struct
     */
    function getReputationMetrics(bytes32 did) external view returns (ReputationMetrics memory) {
        require(identities[did].did != bytes32(0), "Identity does not exist");
        return didReputation[did];
    }
    
    /**
     * @dev Get reputation metrics for an address
     * @param account The address
     * @return ReputationMetrics struct
     */
    function getReputationMetricsByAddress(address account) external view returns (ReputationMetrics memory) {
        return addressReputation[account];
    }
    
    /**
     * @dev Get credential information
     * @param credentialId The credential identifier
     * @return Credential struct
     */
    function getCredential(bytes32 credentialId) external view returns (Credential memory) {
        require(credentials[credentialId].credentialId != bytes32(0), "Credential does not exist");
        return credentials[credentialId];
    }
    
    /**
     * @dev Get DID for an address
     * @param account The address
     * @return The DID associated with the address
     */
    function getDidForAddress(address account) external view returns (bytes32) {
        return addressToDid[account];
    }
    
    /**
     * @dev Get all credentials for a DID
     * @param did The decentralized identifier
     * @return Array of credential IDs
     */
    function getCredentialsForDid(bytes32 did) external view returns (bytes32[] memory) {
        return didCredentials[did];
    }
    
    /**
     * @dev Get total number of identities
     * @return Total identities count
     */
    function getTotalIdentities() external view returns (uint256) {
        return totalIdentities;
    }
    
    /**
     * @dev Get total number of credentials
     * @return Total credentials count
     */
    function getTotalCredentials() external view returns (uint256) {
        return totalCredentials;
    }
}

