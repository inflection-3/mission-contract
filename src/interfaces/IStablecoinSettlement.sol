// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStablecoinSettlement
 * @dev Interface for StablecoinSettlement contract
 */
interface IStablecoinSettlement {
    struct Settlement {
        uint256 settlementId;
        address initiator;
        address[] recipients;
        uint256[] amounts;
        string settlementType;
        uint256 totalAmount;
        uint256 createdAt;
        uint256 executedAt;
        uint8 status; // 0: Pending, 1: Executed, 2: Cancelled, 3: Failed
        bytes32 metadataHash;
    }

    struct Escrow {
        uint256 escrowId;
        address payer;
        address payee;
        address arbiter;
        uint256 amount;
        uint256 createdAt;
        uint256 releaseDeadline;
        uint8 status; // 0: Active, 1: Released, 2: Refunded, 3: Disputed
        string description;
    }

    function createSettlement(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string memory settlementType,
        bytes32 metadataHash
    ) external returns (uint256 settlementId);
    
    function executeSettlement(uint256 settlementId) external;
    
    function cancelSettlement(uint256 settlementId) external;
    
    function createEscrow(
        address payee,
        address arbiter,
        uint256 amount,
        uint256 releaseDeadline,
        string memory description
    ) external returns (uint256 escrowId);
    
    function releaseEscrow(uint256 escrowId) external;
    
    function refundEscrow(uint256 escrowId) external;
    
    function disputeEscrow(uint256 escrowId) external;
    
    function resolveDispute(uint256 escrowId, bool releaseToPayee) external;
    
    function getSettlement(uint256 settlementId) external view returns (Settlement memory);
    
    function getEscrow(uint256 escrowId) external view returns (Escrow memory);
    
    function getUserSettlements(address user) external view returns (uint256[] memory);
    
    function getUserEscrows(address user) external view returns (uint256[] memory);
}

