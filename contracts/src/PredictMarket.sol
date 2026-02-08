// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PredictMarket — Binary Prediction Market for Polygon
/// @notice Create markets, place bets on YES/NO outcomes, resolve with oracle, claim winnings
contract PredictMarket {
    // ─── Types ───────────────────────────────────────────────────────────

    enum Outcome { Unresolved, Yes, No, Invalid }

    struct Market {
        string question;
        address creator;
        uint256 createdAt;
        uint256 deadline;        // betting closes
        uint256 resolutionTime;  // resolved at
        Outcome outcome;
        uint256 yesPool;         // total ETH on YES
        uint256 noPool;          // total ETH on NO
        uint256 totalPool;
        bool resolved;
        address resolver;        // who can resolve (oracle / creator)
        uint256 protocolFee;     // basis points (e.g., 200 = 2%)
        uint256 feeCollected;
    }

    struct Position {
        uint256 yesAmount;
        uint256 noAmount;
        bool claimed;
    }

    // ─── State ───────────────────────────────────────────────────────────

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Position)) public positions;
    mapping(address => uint256[]) public userMarkets;    // markets user bet on
    mapping(address => uint256[]) public createdMarkets; // markets user created

    uint256 public nextMarketId;
    address public owner;
    uint256 public defaultFee = 200; // 2% protocol fee
    uint256 public totalFeeCollected;

    // ─── Events ──────────────────────────────────────────────────────────

    event MarketCreated(uint256 indexed marketId, string question, uint256 deadline, address creator);
    event BetPlaced(uint256 indexed marketId, address indexed bettor, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, Outcome outcome);
    event WinningsClaimed(uint256 indexed marketId, address indexed claimer, uint256 amount);
    event FeeWithdrawn(address indexed to, uint256 amount);

    // ─── Modifiers ───────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    // ─── Constructor ─────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─── Market Creation ─────────────────────────────────────────────────

    /// @notice Create a new prediction market
    /// @param question The question to predict on
    /// @param deadline When betting closes (unix timestamp)
    /// @param resolver Address authorized to resolve (0x0 = creator)
    function createMarket(
        string calldata question,
        uint256 deadline,
        address resolver
    ) external returns (uint256 marketId) {
        require(deadline > block.timestamp, "deadline must be future");
        require(bytes(question).length > 0, "empty question");

        marketId = nextMarketId++;
        markets[marketId] = Market({
            question: question,
            creator: msg.sender,
            createdAt: block.timestamp,
            deadline: deadline,
            resolutionTime: 0,
            outcome: Outcome.Unresolved,
            yesPool: 0,
            noPool: 0,
            totalPool: 0,
            resolved: false,
            resolver: resolver == address(0) ? msg.sender : resolver,
            protocolFee: defaultFee,
            feeCollected: 0
        });

        createdMarkets[msg.sender].push(marketId);
        emit MarketCreated(marketId, question, deadline, msg.sender);
    }

    // ─── Betting ─────────────────────────────────────────────────────────

    /// @notice Place a bet on YES or NO
    function placeBet(uint256 marketId, bool isYes) external payable {
        Market storage m = markets[marketId];
        require(!m.resolved, "market resolved");
        require(block.timestamp < m.deadline, "betting closed");
        require(msg.value > 0, "must send ETH");

        if (isYes) {
            m.yesPool += msg.value;
            positions[marketId][msg.sender].yesAmount += msg.value;
        } else {
            m.noPool += msg.value;
            positions[marketId][msg.sender].noAmount += msg.value;
        }
        m.totalPool += msg.value;

        // Track user participation
        Position storage pos = positions[marketId][msg.sender];
        if (pos.yesAmount + pos.noAmount == msg.value) {
            // First bet in this market
            userMarkets[msg.sender].push(marketId);
        }

        emit BetPlaced(marketId, msg.sender, isYes, msg.value);
    }

    // ─── Resolution ──────────────────────────────────────────────────────

    /// @notice Resolve the market with YES, NO, or Invalid
    function resolveMarket(uint256 marketId, Outcome outcome) external {
        Market storage m = markets[marketId];
        require(msg.sender == m.resolver, "not resolver");
        require(!m.resolved, "already resolved");
        require(block.timestamp >= m.deadline, "deadline not passed");
        require(outcome != Outcome.Unresolved, "invalid outcome");

        m.outcome = outcome;
        m.resolved = true;
        m.resolutionTime = block.timestamp;

        // Calculate fee
        if (outcome != Outcome.Invalid && m.totalPool > 0) {
            m.feeCollected = (m.totalPool * m.protocolFee) / 10000;
            totalFeeCollected += m.feeCollected;
        }

        emit MarketResolved(marketId, outcome);
    }

    // ─── Claims ──────────────────────────────────────────────────────────

    /// @notice Claim winnings after market resolution
    function claimWinnings(uint256 marketId) external {
        Market storage m = markets[marketId];
        require(m.resolved, "not resolved");

        Position storage pos = positions[marketId][msg.sender];
        require(!pos.claimed, "already claimed");
        pos.claimed = true;

        uint256 payout;

        if (m.outcome == Outcome.Invalid) {
            // Refund everyone
            payout = pos.yesAmount + pos.noAmount;
        } else if (m.outcome == Outcome.Yes) {
            if (m.yesPool > 0 && pos.yesAmount > 0) {
                uint256 pool = m.totalPool - m.feeCollected;
                payout = (pos.yesAmount * pool) / m.yesPool;
            }
        } else if (m.outcome == Outcome.No) {
            if (m.noPool > 0 && pos.noAmount > 0) {
                uint256 pool = m.totalPool - m.feeCollected;
                payout = (pos.noAmount * pool) / m.noPool;
            }
        }

        require(payout > 0, "nothing to claim");
        (bool ok,) = msg.sender.call{value: payout}("");
        require(ok, "transfer failed");

        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    // ─── Admin ───────────────────────────────────────────────────────────

    function withdrawFees(address to) external onlyOwner {
        uint256 amount = totalFeeCollected;
        require(amount > 0, "no fees");
        totalFeeCollected = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "transfer failed");
        emit FeeWithdrawn(to, amount);
    }

    function setDefaultFee(uint256 feeBps) external onlyOwner {
        require(feeBps <= 1000, "max 10%");
        defaultFee = feeBps;
    }

    // ─── View Functions ──────────────────────────────────────────────────

    /// @notice Get market pools and status
    function getMarketPools(uint256 marketId) external view returns (
        uint256 yesPool,
        uint256 noPool,
        uint256 totalPool,
        Outcome outcome,
        bool resolved,
        uint256 deadline
    ) {
        Market storage m = markets[marketId];
        return (m.yesPool, m.noPool, m.totalPool, m.outcome, m.resolved, m.deadline);
    }

    /// @notice Get market metadata
    function getMarketMeta(uint256 marketId) external view returns (
        string memory question,
        address creator,
        address resolver,
        uint256 createdAt
    ) {
        Market storage m = markets[marketId];
        return (m.question, m.creator, m.resolver, m.createdAt);
    }

    /// @notice Get odds as basis points (e.g., 6000 = 60% YES)
    function getOdds(uint256 marketId) external view returns (uint256 yesBps, uint256 noBps) {
        Market storage m = markets[marketId];
        if (m.totalPool == 0) return (5000, 5000); // 50-50 default
        yesBps = (m.yesPool * 10000) / m.totalPool;
        noBps = 10000 - yesBps;
    }

    /// @notice Get user position in a market
    function getUserPosition(uint256 marketId, address user) external view returns (
        uint256 yesAmount,
        uint256 noAmount,
        bool claimed
    ) {
        Position storage p = positions[marketId][user];
        return (p.yesAmount, p.noAmount, p.claimed);
    }

    /// @notice Get user's market list
    function getUserMarkets(address user) external view returns (uint256[] memory) {
        return userMarkets[user];
    }

    function getCreatedMarkets(address user) external view returns (uint256[] memory) {
        return createdMarkets[user];
    }

    /// @notice Calculate potential payout for a bet
    function calculatePayout(uint256 marketId, bool isYes, uint256 betAmount) external view returns (uint256) {
        Market storage m = markets[marketId];
        uint256 newTotal = m.totalPool + betAmount;
        uint256 pool = newTotal - (newTotal * m.protocolFee / 10000);
        if (isYes) {
            uint256 newYes = m.yesPool + betAmount;
            return (betAmount * pool) / newYes;
        } else {
            uint256 newNo = m.noPool + betAmount;
            return (betAmount * pool) / newNo;
        }
    }
}
