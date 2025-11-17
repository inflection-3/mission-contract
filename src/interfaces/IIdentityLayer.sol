// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IIdentityLayer
 * @dev Interface for IdentityLayer contract
 */
interface IIdentityLayer {
    struct Identity {
        address owner;
        bytes32 did;
        string metadataUri;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct Credential {
        bytes32 credentialId;
        bytes32 issuerDid;
        bytes32 subjectDid;
        string credentialType;
        bytes32 dataHash;
        uint256 issuedAt;
        uint256 expiresAt;
        bool isRevoked;
    }

    function registerIdentity(bytes32 did, string memory metadataUri) external;
    
    function linkAddressToDid(bytes32 did) external;
    
    function updateIdentity(bytes32 did, string memory newMetadataUri) external;
    
    function deactivateIdentity(bytes32 did) external;
    
    function issueCredential(
        bytes32 credentialId,
        bytes32 issuerDid,
        bytes32 subjectDid,
        string memory credentialType,
        bytes32 dataHash,
        uint256 expiresAt
    ) external;
    
    function revokeCredential(bytes32 credentialId) external;
    
    function verifyCredential(bytes32 credentialId) external view returns (bool);
    
    function getIdentity(bytes32 did) external view returns (Identity memory);
    
    function getCredential(bytes32 credentialId) external view returns (Credential memory);
    
    function getDidForAddress(address account) external view returns (bytes32);
    
    function getCredentialsForDid(bytes32 did) external view returns (bytes32[] memory);
}

