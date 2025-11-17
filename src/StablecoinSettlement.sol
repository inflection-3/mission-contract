// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUSDC.sol";

/**
 * @title StablecoinSettlement
 * @dev Settlement layer for stablecoin transactions
 * Handles batch settlements, escrow, and multi-party transactions
 */
contract StablecoinSettlement is Ownable, ReentrancyGuard {
    IUSDC public immutable usdcToken;
    
    struct Settlement {
        uint256 settlementId;
        address initiator;
        address[] recipients;
        uint256[] amounts;
        string settlementType; // e.g., "batch", "escrow", "multi-party"
        uint256 totalAmount;
        uint256 createdAt;
        uint256 executedAt;
        SettlementStatus status;
        bytes32 metadataHash; // Hash of settlement metadata
    }
    
    struct Escrow {
        uint256 escrowId;
        address payer;
        address payee;
        address arbiter; // Optional arbiter for disputes
        uint256 amount;
        uint256 createdAt;
        uint256 releaseDeadline;
        EscrowStatus status;
        string description;
    }
    
    enum SettlementStatus {
        Pending,
        Executed,
        Cancelled,
        Failed
    }
    
    enum EscrowStatus {
        Active,
        Released,
        Refunded,
        Disputed
    }
    
    mapping(uint256 => Settlement) public settlements;
    mapping(uint256 => Escrow) public escrows;
    
    // Track settlements by user
    mapping(address => uint256[]) public userSettlements;
    mapping(address => uint256[]) public userEscrows;
    
    uint256 public totalSettlements;
    uint256 public totalEscrows;
    uint256 public totalSettledAmount;
    
    // Configuration
    uint256 public minSettlementAmount;
    uint256 public maxRecipientsPerSettlement;
    uint256 public settlementFee; // Fee in basis points (10000 = 100%)
    
    event SettlementCreated(
        uint256 indexed settlementId,
        address indexed initiator,
        uint256 totalAmount,
        string settlementType
    );
    event SettlementExecuted(
        uint256 indexed settlementId,
        address indexed initiator,
        uint256 totalAmount
    );
    event SettlementCancelled(uint256 indexed settlementId);
    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed payer,
        address indexed payee,
        uint256 amount
    );
    event EscrowReleased(
        uint256 indexed escrowId,
        address indexed payee,
        uint256 amount
    );
    event EscrowRefunded(
        uint256 indexed escrowId,
        address indexed payer,
        uint256 amount
    );
    event EscrowDisputed(uint256 indexed escrowId);
    event BatchSettlementExecuted(
        uint256 indexed settlementId,
        address[] recipients,
        uint256[] amounts
    );
    
    modifier validSettlement(uint256 settlementId) {
        require(settlements[settlementId].settlementId != 0, "Invalid settlement");
        _;
    }
    
    modifier onlySettlementInitiator(uint256 settlementId) {
        require(
            settlements[settlementId].initiator == msg.sender,
            "Not settlement initiator"
        );
        _;
    }
    
    modifier onlyPendingSettlement(uint256 settlementId) {
        require(
            settlements[settlementId].status == SettlementStatus.Pending,
            "Settlement not pending"
        );
        _;
    }
    
    modifier validEscrow(uint256 escrowId) {
        require(escrows[escrowId].escrowId != 0, "Invalid escrow");
        _;
    }
    
    constructor(address _usdcToken) Ownable(msg.sender) {
        require(_usdcToken != address(0), "Invalid USDC address");
        usdcToken = IUSDC(_usdcToken);
        minSettlementAmount = 1; // Minimum settlement amount
        maxRecipientsPerSettlement = 100; // Maximum recipients per settlement
        settlementFee = 0; // Default no fee
    }
    
    /**
     * @dev Create a new settlement
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts for each recipient
     * @param settlementType Type of settlement
     * @param metadataHash Hash of settlement metadata
     */
    function createSettlement(
        address[] calldata recipients,
        uint256[] calldata amounts,
        string memory settlementType,
        bytes32 metadataHash
    ) external returns (uint256 settlementId) {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length > 0, "No recipients");
        require(recipients.length <= maxRecipientsPerSettlement, "Too many recipients");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] >= minSettlementAmount, "Amount below minimum");
            require(recipients[i] != address(0), "Invalid recipient");
            totalAmount += amounts[i];
        }
        
        totalSettlements++;
        settlementId = totalSettlements;
        
        settlements[settlementId] = Settlement({
            settlementId: settlementId,
            initiator: msg.sender,
            recipients: recipients,
            amounts: amounts,
            settlementType: settlementType,
            totalAmount: totalAmount,
            createdAt: block.timestamp,
            executedAt: 0,
            status: SettlementStatus.Pending,
            metadataHash: metadataHash
        });
        
        userSettlements[msg.sender].push(settlementId);
        
        emit SettlementCreated(settlementId, msg.sender, totalAmount, settlementType);
    }
    
    /**
     * @dev Execute a settlement by transferring USDC to recipients
     * @param settlementId The settlement ID
     */
    function executeSettlement(uint256 settlementId) 
        external 
        validSettlement(settlementId) 
        onlySettlementInitiator(settlementId) 
        onlyPendingSettlement(settlementId) 
        nonReentrant 
    {
        Settlement storage settlement = settlements[settlementId];
        
        uint256 totalAmount = settlement.totalAmount;
        uint256 feeAmount = (totalAmount * settlementFee) / 10000;
        uint256 amountToSettle = totalAmount - feeAmount;
        
        require(
            usdcToken.balanceOf(msg.sender) >= totalAmount,
            "Insufficient balance"
        );
        require(
            usdcToken.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient allowance"
        );
        
        // Transfer USDC from initiator to this contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), totalAmount),
            "Transfer failed"
        );
        
        // Transfer fee to owner if applicable
        if (feeAmount > 0) {
            require(usdcToken.transfer(owner(), feeAmount), "Fee transfer failed");
        }
        
        // Distribute to recipients
        for (uint256 i = 0; i < settlement.recipients.length; i++) {
            require(
                usdcToken.transfer(settlement.recipients[i], settlement.amounts[i]),
                "Recipient transfer failed"
            );
        }
        
        settlement.status = SettlementStatus.Executed;
        settlement.executedAt = block.timestamp;
        totalSettledAmount += amountToSettle;
        
        emit SettlementExecuted(settlementId, msg.sender, amountToSettle);
        emit BatchSettlementExecuted(
            settlementId,
            settlement.recipients,
            settlement.amounts
        );
    }
    
    /**
     * @dev Cancel a pending settlement
     * @param settlementId The settlement ID
     */
    function cancelSettlement(uint256 settlementId) 
        external 
        validSettlement(settlementId) 
        onlySettlementInitiator(settlementId) 
        onlyPendingSettlement(settlementId) 
    {
        settlements[settlementId].status = SettlementStatus.Cancelled;
        
        emit SettlementCancelled(settlementId);
    }
    
    /**
     * @dev Create an escrow
     * @param payee Address of the payee
     * @param arbiter Address of the arbiter (can be address(0) for no arbiter)
     * @param amount Amount to escrow
     * @param releaseDeadline Deadline for automatic release (0 for no deadline)
     * @param description Description of the escrow
     */
    function createEscrow(
        address payee,
        address arbiter,
        uint256 amount,
        uint256 releaseDeadline,
        string memory description
    ) external returns (uint256 escrowId) {
        require(payee != address(0), "Invalid payee");
        require(amount >= minSettlementAmount, "Amount below minimum");
        require(
            usdcToken.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );
        require(
            usdcToken.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
        
        // Transfer USDC to escrow
        require(
            usdcToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        totalEscrows++;
        escrowId = totalEscrows;
        
        escrows[escrowId] = Escrow({
            escrowId: escrowId,
            payer: msg.sender,
            payee: payee,
            arbiter: arbiter,
            amount: amount,
            createdAt: block.timestamp,
            releaseDeadline: releaseDeadline,
            status: EscrowStatus.Active,
            description: description
        });
        
        userEscrows[msg.sender].push(escrowId);
        userEscrows[payee].push(escrowId);
        
        emit EscrowCreated(escrowId, msg.sender, payee, amount);
    }
    
    /**
     * @dev Release escrow funds to payee
     * @param escrowId The escrow ID
     */
    function releaseEscrow(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
        nonReentrant 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Active, "Escrow not active");
        require(
            msg.sender == escrow.payer ||
            msg.sender == escrow.arbiter ||
            (escrow.releaseDeadline > 0 && block.timestamp >= escrow.releaseDeadline),
            "Not authorized to release"
        );
        
        escrow.status = EscrowStatus.Released;
        
        require(
            usdcToken.transfer(escrow.payee, escrow.amount),
            "Transfer failed"
        );
        
        emit EscrowReleased(escrowId, escrow.payee, escrow.amount);
    }
    
    /**
     * @dev Refund escrow funds to payer
     * @param escrowId The escrow ID
     */
    function refundEscrow(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
        nonReentrant 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Active, "Escrow not active");
        require(
            msg.sender == escrow.payee ||
            msg.sender == escrow.arbiter,
            "Not authorized to refund"
        );
        
        escrow.status = EscrowStatus.Refunded;
        
        require(
            usdcToken.transfer(escrow.payer, escrow.amount),
            "Transfer failed"
        );
        
        emit EscrowRefunded(escrowId, escrow.payer, escrow.amount);
    }
    
    /**
     * @dev Dispute an escrow (only arbiter can resolve)
     * @param escrowId The escrow ID
     */
    function disputeEscrow(uint256 escrowId) 
        external 
        validEscrow(escrowId) 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Active, "Escrow not active");
        require(
            msg.sender == escrow.payer || msg.sender == escrow.payee,
            "Not authorized to dispute"
        );
        require(escrow.arbiter != address(0), "No arbiter set");
        
        escrow.status = EscrowStatus.Disputed;
        
        emit EscrowDisputed(escrowId);
    }
    
    /**
     * @dev Resolve a disputed escrow (only arbiter)
     * @param escrowId The escrow ID
     * @param releaseToPayee True to release to payee, false to refund to payer
     */
    function resolveDispute(uint256 escrowId, bool releaseToPayee) 
        external 
        validEscrow(escrowId) 
        nonReentrant 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Disputed, "Escrow not disputed");
        require(msg.sender == escrow.arbiter, "Not arbiter");
        
        if (releaseToPayee) {
            escrow.status = EscrowStatus.Released;
            require(
                usdcToken.transfer(escrow.payee, escrow.amount),
                "Transfer failed"
            );
            emit EscrowReleased(escrowId, escrow.payee, escrow.amount);
        } else {
            escrow.status = EscrowStatus.Refunded;
            require(
                usdcToken.transfer(escrow.payer, escrow.amount),
                "Transfer failed"
            );
            emit EscrowRefunded(escrowId, escrow.payer, escrow.amount);
        }
    }
    
    /**
     * @dev Set minimum settlement amount
     * @param newMinAmount New minimum amount
     */
    function setMinSettlementAmount(uint256 newMinAmount) external onlyOwner {
        require(newMinAmount > 0, "Invalid amount");
        minSettlementAmount = newMinAmount;
    }
    
    /**
     * @dev Set maximum recipients per settlement
     * @param newMaxRecipients New maximum recipients
     */
    function setMaxRecipientsPerSettlement(uint256 newMaxRecipients) external onlyOwner {
        require(newMaxRecipients > 0, "Invalid value");
        maxRecipientsPerSettlement = newMaxRecipients;
    }
    
    /**
     * @dev Set settlement fee
     * @param newFee New fee in basis points
     */
    function setSettlementFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high (max 10%)");
        settlementFee = newFee;
    }
    
    // View functions
    
    /**
     * @dev Get settlement information
     * @param settlementId The settlement ID
     * @return Settlement struct
     */
    function getSettlement(uint256 settlementId) external view returns (Settlement memory) {
        require(settlements[settlementId].settlementId != 0, "Settlement does not exist");
        return settlements[settlementId];
    }
    
    /**
     * @dev Get escrow information
     * @param escrowId The escrow ID
     * @return Escrow struct
     */
    function getEscrow(uint256 escrowId) external view returns (Escrow memory) {
        require(escrows[escrowId].escrowId != 0, "Escrow does not exist");
        return escrows[escrowId];
    }
    
    /**
     * @dev Get settlements for a user
     * @param user Address of the user
     * @return Array of settlement IDs
     */
    function getUserSettlements(address user) external view returns (uint256[] memory) {
        return userSettlements[user];
    }
    
    /**
     * @dev Get escrows for a user
     * @param user Address of the user
     * @return Array of escrow IDs
     */
    function getUserEscrows(address user) external view returns (uint256[] memory) {
        return userEscrows[user];
    }
    
    /**
     * @dev Get total number of settlements
     * @return Total settlements count
     */
    function getTotalSettlements() external view returns (uint256) {
        return totalSettlements;
    }
    
    /**
     * @dev Get total number of escrows
     * @return Total escrows count
     */
    function getTotalEscrows() external view returns (uint256) {
        return totalEscrows;
    }
    
    /**
     * @dev Emergency function to recover USDC
     * @param amount Amount to recover
     */
    function emergencyRecoverUSDC(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        require(usdcToken.transfer(owner(), amount), "Transfer failed");
    }
}

