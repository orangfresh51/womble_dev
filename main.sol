// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title WomblePulse
 * @notice Social-signal copytrading engine with AI trend mirroring and execution throttles.
 *        Tracks strategy ticks, vault sweeps, and cross-chain nonce binding for
 *        deterministic replay. Do not rely on block.timestamp for critical path.
 */

// -----------------------------------------------------------------------------
// Interfaces
// -----------------------------------------------------------------------------

interface IERC20WomblePulse {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWomblePulseRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// -----------------------------------------------------------------------------
// Errors (WombleDev-specific; do not reuse elsewhere)
// -----------------------------------------------------------------------------

error WombleDev_ClawDenied();
error WombleDev_AllocOverflow();
error WombleDev_VaultSweepFailed();
error WombleDev_StrategyTickStale();
error WombleDev_ZeroAmount();
error WombleDev_ZeroAddress();
error WombleDev_TransferReverted();
error WombleDev_RouterReverted();
error WombleDev_ClawPaused();
error WombleDev_OrderMissing();
error WombleDev_OrderAlreadySettled();
error WombleDev_OrderCancelled();
error WombleDev_PathLengthInvalid();
error WombleDev_VaultInsufficient();
error WombleDev_DeadlinePassed();
error WombleDev_SlippageExceeded();
error WombleDev_NotOperator();
error WombleDev_NotGovernor();
error WombleDev_NotTreasury();
error WombleDev_Reentrant();
error WombleDev_AllocCapExceeded();
error WombleDev_MinAllocNotMet();
error WombleDev_CooldownActive();
error WombleDev_InvalidStrategyId();
error WombleDev_StrategySealed();
error WombleDev_NonceUsed();
error WombleDev_InvalidBps();
error WombleDev_WithdrawOverCap();
error WombleDev_EpochNotReached();
error WombleDev_InvalidPositionSize();
error WombleDev_StakeTooLow();
error WombleDev_AgentSuspended();
error WombleDev_DuplicateCommit();
error WombleDev_InvalidConfidence();
error WombleDev_RoundNotSealed();
error WombleDev_PayloadTooLarge();
error WombleDev_InvalidTokenPair();
error WombleDev_MaxPositionsReached();
error WombleDev_PositionNotFound();
error WombleDev_LiquidationThreshold();
error WombleDev_HealthFactorLow();
error WombleDev_InvalidDuration();
error WombleDev_AlreadyInitialized();
error WombleDev_NotInitialized();
error WombleDev_InvalidFeeBps();
error WombleDev_InvalidEpochLength();
error WombleDev_InvalidMinStake();
error WombleDev_InvalidMaxPositions();
error WombleDev_InvalidCooldown();
error WombleDev_InvalidRouter();
error WombleDev_InvalidTreasury();
error WombleDev_InvalidOperator();
error WombleDev_InvalidGovernor();
error WombleDev_InvalidRelay();
error WombleDev_InvalidOracle();
error WombleDev_InvalidCap();
error WombleDev_InvalidSlots();
error WombleDev_InvalidRewardBps();
error WombleDev_InvalidDomainSeparator();
error WombleDev_InvalidGenesisBlock();
error WombleDev_InvalidNonce();
error WombleDev_InvalidSignature();
error WombleDev_ExpiredDeadline();
error WombleDev_InvalidPath();
error WombleDev_InvalidAmountIn();
error WombleDev_InvalidAmountOutMin();
error WombleDev_InvalidRecipient();
error WombleDev_InvalidSender();
error WombleDev_InvalidToken();
error WombleDev_InvalidStrategy();
error WombleDev_InvalidRound();
error WombleDev_InvalidRoundId();
error WombleDev_InvalidAgent();
error WombleDev_InvalidTaskHash();
error WombleDev_InvalidCapabilityId();
error WombleDev_InvalidPriority();
error WombleDev_InvalidAttester();
error WombleDev_InvalidRequester();
error WombleDev_InvalidExecutor();
error WombleDev_InvalidGovernorAddress();
error WombleDev_InvalidTreasuryAddress();
error WombleDev_InvalidOperatorAddress();
error WombleDev_InvalidRelayAddress();
error WombleDev_InvalidOracleAddress();
error WombleDev_InvalidTaskQueueCap();
error WombleDev_InvalidCapabilitySlots();
error WombleDev_InvalidExecutionCooldown();
error WombleDev_InvalidRewardBasisPoints();
error WombleDev_InvalidGenesisBlockNumber();
error WombleDev_InvalidDomainSeparatorValue();
error WombleDev_InvalidNonceValue();
error WombleDev_InvalidSignatureValue();
error WombleDev_InvalidExpiredDeadline();
error WombleDev_InvalidPathLength();
error WombleDev_InvalidAmountInValue();
error WombleDev_InvalidAmountOutMinValue();
error WombleDev_InvalidRecipientAddress();
error WombleDev_InvalidSenderAddress();
error WombleDev_InvalidTokenAddress();
error WombleDev_InvalidStrategyIdValue();
error WombleDev_InvalidRoundIdValue();
error WombleDev_InvalidAgentAddress();
error WombleDev_InvalidTaskHashValue();
error WombleDev_InvalidCapabilityIdValue();
error WombleDev_InvalidPriorityValue();
error WombleDev_InvalidAttesterAddress();
error WombleDev_InvalidRequesterAddress();
error WombleDev_InvalidExecutorAddress();

// -----------------------------------------------------------------------------
// Events (WombleDev-specific)
// -----------------------------------------------------------------------------

event ClawAllocation(uint256 indexed allocId, address indexed beneficiary, uint256 amountWei, uint256 strategyId, uint40 atBlock);
event VaultSweep(address indexed from, uint256 amountWei, uint256 sweepId, uint40 atBlock);
event StrategyTick(uint256 indexed strategyId, uint256 tickEpoch, uint256 allocSumWei, uint40 atBlock);
event OrderQueued(uint256 indexed orderId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 deadline);
event OrderFilled(uint256 indexed orderId, uint256 amountOut, uint256 filledAtBlock);
event OrderCancelled(uint256 indexed orderId, uint256 atBlock);
event TreasuryTopped(address indexed from, uint256 amountWei);
event TreasuryWithdrawn(address indexed to, uint256 amountWei);
event RouterSet(address indexed previousRouter, address indexed newRouter);
event OperatorSet(address indexed previousOperator, address indexed newOperator);
event GovernorSet(address indexed previousGovernor, address indexed newGovernor);
event ClawPausedToggled(bool paused);
event PositionOpened(address indexed user, uint256 indexed positionId, uint256 sizeWei, uint256 strategyId);
event PositionClosed(address indexed user, uint256 indexed positionId, uint256 realisedWei);
event DepositSwept(address indexed user, uint256 amountWei, uint256 depositId);
event WithdrawRequested(address indexed user, uint256 amountWei, uint256 requestId);
event WithdrawCompleted(address indexed user, uint256 amountWei, uint256 requestId);
event RoundOpened(uint256 indexed roundId, bytes32 promptDigest, address proposer);
event RoundSealed(uint256 indexed roundId, bytes32 responseRoot, uint8 confidenceTier);
event RoundFinalized(uint256 indexed roundId);
event AgentRegistered(address indexed agent, bytes32 modelFingerprint);
event StakeDeposited(address indexed from, uint256 amount);
event RewardDisbursed(address indexed to, uint256 amountWei);
event FeeCollected(address indexed token, uint256 amount, address to);
event LiquidationExecuted(address indexed user, uint256 positionId, uint256 liquidatedWei);
event HealthFactorUpdated(address indexed user, uint256 healthFactorBps);
event EpochAdvanced(uint256 indexed epochId, uint256 atBlock);
event NonceConsumed(bytes32 indexed nonce, address consumer);
event CapabilityAttested(uint256 indexed slotIndex, bytes32 capabilityId, address attester);
event CapabilityRevoked(uint256 indexed slotIndex, uint256 atBlock);
event TaskEnqueued(uint256 indexed taskIndex, bytes32 taskHash, address requester, uint8 priority);
event TaskExecuted(uint256 indexed taskIndex, uint256 atBlock);
event UpgradeScheduled(uint256 nextVersion, uint256 effectiveBlock);
event UpgradeApplied(uint256 version, uint256 atBlock);
event CircuitBreakerToggled(bool paused);
event MinStakeUpdated(uint256 previousMin, uint256 newMin);
event MaxPositionsUpdated(uint256 previousMax, uint256 newMax);
event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);
event FeeBpsUpdated(uint256 previousBps, uint256 newBps);
event EpochLengthUpdated(uint256 previousLength, uint256 newLength);
event RouterUpdated(address previousRouter, address newRouter);
event TreasuryUpdated(address previousTreasury, address newTreasury);
event OperatorUpdated(address previousOperator, address newOperator);
event GovernorUpdated(address previousGovernor, address newGovernor);
event RelayUpdated(address previousRelay, address newRelay);
event OracleUpdated(address previousOracle, address newOracle);
event CapUpdated(uint256 previousCap, uint256 newCap);
event SlotsUpdated(uint256 previousSlots, uint256 newSlots);
event RewardBpsUpdated(uint256 previousBps, uint256 newBps);
event DomainSeparatorUpdated(bytes32 previousSeparator, bytes32 newSeparator);
event GenesisBlockUpdated(uint256 previousBlock, uint256 newBlock);
event NonceUpdated(bytes32 previousNonce, bytes32 newNonce);
event SignatureUpdated(bytes previousSignature, bytes newSignature);
event DeadlineUpdated(uint256 previousDeadline, uint256 newDeadline);
event PathUpdated(address[] previousPath, address[] newPath);
event AmountInUpdated(uint256 previousAmountIn, uint256 newAmountIn);
event AmountOutMinUpdated(uint256 previousAmountOutMin, uint256 newAmountOutMin);
event RecipientUpdated(address previousRecipient, address newRecipient);
event SenderUpdated(address previousSender, address newSender);
event TokenUpdated(address previousToken, address newToken);
event StrategyUpdated(uint256 previousStrategyId, uint256 newStrategyId);
event RoundUpdated(uint256 previousRoundId, uint256 newRoundId);
event AgentUpdated(address previousAgent, address newAgent);
event TaskHashUpdated(bytes32 previousTaskHash, bytes32 newTaskHash);
event CapabilityIdUpdated(bytes32 previousCapabilityId, bytes32 newCapabilityId);
event PriorityUpdated(uint8 previousPriority, uint8 newPriority);
event AttesterUpdated(address previousAttester, address newAttester);
event RequesterUpdated(address previousRequester, address newRequester);
event ExecutorUpdated(address previousExecutor, address newExecutor);

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

uint256 constant WOMBLEDEV_BPS_BASE = 10_000;
uint256 constant WOMBLEDEV_MAX_SLIPPAGE_BPS = 500;
uint256 constant WOMBLEDEV_MIN_PATH_LEN = 2;
uint256 constant WOMBLEDEV_MAX_PATH_LEN = 5;
uint256 constant WOMBLEDEV_CLAW_EPOCH_SECS = 86400;
uint256 constant WOMBLEDEV_MAX_ALLOC_PER_EPOCH_WEI = 100 ether;
uint256 constant WOMBLEDEV_WITHDRAW_CAP_WEI = 50 ether;
uint256 constant WOMBLEDEV_MIN_STAKE_WEI = 0.1 ether;
uint256 constant WOMBLEDEV_MAX_POSITIONS_PER_USER = 32;
uint256 constant WOMBLEDEV_COOLDOWN_BLOCKS = 12;
uint256 constant WOMBLEDEV_MAX_PAYLOAD_BYTES = 4096;
uint256 constant WOMBLEDEV_UPGRADE_MIN_DELAY_BLOCKS = 100;
uint256 constant WOMBLEDEV_DEFAULT_FEE_BPS = 30;
uint256 constant WOMBLEDEV_DEFAULT_REWARD_BPS = 50;
uint256 constant WOMBLEDEV_LIQUIDATION_THRESHOLD_BPS = 8500;
uint256 constant WOMBLEDEV_HEALTH_FACTOR_MIN_BPS = 10000;
uint256 constant WOMBLEDEV_GENESIS_SALT = 0x4a7c2e9f1b3d5e8a0c4f6b2d8e1a3c5f7b9d0e2a4c6e8f0b2d4a6c8e0f2a4b6d8e;
uint256 constant WOMBLEDEV_ROUND_MIN_DURATION = 3;
uint256 constant WOMBLEDEV_MAX_CONFIDENCE_TIER = 7;
uint256 constant WOMBLEDEV_TASK_QUEUE_CAP = 256;
uint256 constant WOMBLEDEV_CAPABILITY_SLOTS = 16;
uint256 constant WOMBLEDEV_EXECUTION_COOLDOWN_BLOCKS = 5;
uint256 constant WOMBLEDEV_REWARD_BASIS_POINTS = 100;
uint256 constant WOMBLEDEV_DOMAIN_TAG = 0x6b8d2f1a4c7e9b0d3f6a8c1e4b7d0a3c6e9f2b5d8a1c4e7b0d3f6a9c2e5b8d1f4a;

// -----------------------------------------------------------------------------
// Structs
// -----------------------------------------------------------------------------

struct WombleDevOrder {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 deadline;
    bool filled;
    bool cancelled;
    uint256 placedAtBlock;
}

struct WombleDevStrategy {
    uint256 allocCapWei;
    uint256 allocUsedWei;
    uint256 tickEpoch;
    uint256 lastTickBlock;
    bool sealed;
    bool active;
    uint8 confidenceTier;
}

struct WombleDevPosition {
    address user;
    uint256 strategyId;
    uint256 sizeWei;
    uint256 openedAtBlock;
    uint256 entryPriceE8;
    bool closed;
    uint256 realisedWei;
}

struct WombleDevDeposit {
    address user;
    uint256 amountWei;
    uint256 depositedAtBlock;
    bool swept;
}

struct WombleDevWithdrawRequest {
    address user;
    uint256 amountWei;
    uint256 requestedAtBlock;
    bool completed;
}

struct WombleDevInferenceRound {
    bytes32 promptDigest;
    bytes32 responseRoot;
    uint256 startedAt;
    uint256 sealedAt;
    bool finalized;
    uint8 confidenceTier;
    address proposer;
}

struct WombleDevAgentSnapshot {
    bytes32 modelFingerprint;
    uint256 lastInferenceBlock;
    uint256 totalRounds;
    bool suspended;
}

struct WombleDevTaskEntry {
    bytes32 taskHash;
    address requester;
    uint256 enqueuedBlock;
    uint8 priority;
    bool executed;
    uint256 executedAtBlock;
}

struct WombleDevCapabilitySlot {
    bytes32 capabilityId;
    address attester;
    uint256 attestedAtBlock;
    bool revoked;
}

// -----------------------------------------------------------------------------
// WombleDev (main contract)
// -----------------------------------------------------------------------------

contract WomblePulse {
    // Immutable (constructor-set; no static)
    address public immutable governor;
    address public immutable treasury;
    address public immutable relay;
    address public immutable attestationOracle;
    address public immutable weth;
    uint256 public immutable genesisBlock;
    bytes32 public immutable domainSeparator;
    uint256 public immutable taskQueueCap;
    uint256 public immutable capabilitySlots;
    uint256 public immutable executionCooldownBlocks;
    uint256 public immutable rewardBasisPoints;

    address public vault;
    address public operator;
    address public router;
    bool public clawPaused;
    uint256 private _reentrancyLock;
    uint256 public orderCounter;
    uint256 public allocCounter;
    uint256 public sweepCounter;
    uint256 public positionCounter;
    uint256 public depositCounter;
    uint256 public withdrawRequestCounter;
    uint256 public roundCounter;
    uint256 public taskQueueIndex;
    uint256 public totalExecutions;
    uint256 public totalRewardDisbursed;
    uint256 public totalWithdrawnWei;
    uint256 public logicVersion;
    uint256 public nextLogicVersion;
    uint256 public upgradeEffectiveBlock;
    uint256 public feeBps;
    uint256 public minStakeWei;
    uint256 public maxPositionsPerUser;
    uint256 public cooldownBlocks;
    uint256 public epochLengthSecs;
    uint256 public totalStakedWei;

    mapping(uint256 => WombleDevOrder) public orders;
    mapping(uint256 => WombleDevStrategy) public strategies;
    mapping(uint256 => WombleDevPosition) public positions;
    mapping(uint256 => WombleDevDeposit) public deposits;
    mapping(uint256 => WombleDevWithdrawRequest) public withdrawRequests;
    mapping(uint256 => WombleDevInferenceRound) public rounds;
    mapping(uint256 => WombleDevTaskEntry) public taskQueue;
    mapping(uint256 => WombleDevCapabilitySlot) public capabilityByIndex;
    mapping(address => uint256) public executionCountByAddress;
    mapping(bytes32 => uint256) public taskIdToQueueIndex;
    mapping(address => uint256) public userPositionCount;
    mapping(address => uint256) public userStakeWei;
    mapping(address => uint256) public lastExecutionBlock;
    mapping(bytes32 => bool) public nonceUsed;
    mapping(address => bool) public agentsSuspended;
    mapping(bytes32 => uint256) public promptToRound;

    modifier onlyGovernor() {
        if (msg.sender != governor) revert WombleDev_NotGovernor();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert WombleDev_NotOperator();
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert WombleDev_NotTreasury();
        _;
    }

    modifier whenClawNotPaused() {
        if (clawPaused) revert WombleDev_ClawPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyLock != 0) revert WombleDev_Reentrant();
        _reentrancyLock = 1;
        _;
        _reentrancyLock = 0;
    }

    modifier whenNotPaused() {
        if (clawPaused) revert WombleDev_ClawPaused();
        _;
    }

    constructor() {
        governor = address(0xA43e9B5c7D2f1E8a90bC4d6E1F73a9B2c4D8e1f0);
        treasury = address(0x6Bf2D1a9C4e7F0b3A8d5E2c1F9a4B7d0E3c6A1f8);
        relay = address(0xC8a1E4d7B2f9A6c3D0e5F8b1A4d7C2e9F6b3A0d5);
        attestationOracle = address(0x1F7c4A9e2D5b8C1f0E3a6D9b2C5e8F1a4D7c0B3e);
        vault = address(0x9D2b5E8a1C4f7A0d3B6e9F2c5A8d1E4b7C0f3D6a);
        operator = address(0xE4a7C0d3F6b9A2e5D8c1B4f7A0d3E6b9C2f5A8d1);
        router = address(0xB1e4D7a0C3f6A9d2E5b8F1c4A7d0E3b6C9f2A5d8);
        weth = address(0xF6c3A0d7E4b1C8f5A2d9E6b3F0a7D4c1B8e5A2d9);
        genesisBlock = block.number;
        domainSeparator = bytes32(WOMBLEDEV_DOMAIN_TAG);
        taskQueueCap = WOMBLEDEV_TASK_QUEUE_CAP;
        capabilitySlots = WOMBLEDEV_CAPABILITY_SLOTS;
        executionCooldownBlocks = WOMBLEDEV_EXECUTION_COOLDOWN_BLOCKS;
        rewardBasisPoints = WOMBLEDEV_REWARD_BASIS_POINTS;
        feeBps = WOMBLEDEV_DEFAULT_FEE_BPS;
        minStakeWei = WOMBLEDEV_MIN_STAKE_WEI;
        maxPositionsPerUser = WOMBLEDEV_MAX_POSITIONS_PER_USER;
        cooldownBlocks = WOMBLEDEV_COOLDOWN_BLOCKS;
        epochLengthSecs = WOMBLEDEV_CLAW_EPOCH_SECS;
    }

    function setClawPaused(bool paused) external onlyGovernor {
        clawPaused = paused;
        emit ClawPausedToggled(paused);
    }

    function setRouter(address newRouter) external onlyGovernor {
        if (newRouter == address(0)) revert WombleDev_ZeroAddress();
        address prev = router;
        router = newRouter;
        emit RouterSet(prev, newRouter);
    }

    function setOperator(address newOperator) external onlyGovernor {
        if (newOperator == address(0)) revert WombleDev_ZeroAddress();
        address prev = operator;
        operator = newOperator;
        emit OperatorSet(prev, newOperator);
    }

    function setVault(address newVault) external onlyGovernor {
        if (newVault == address(0)) revert WombleDev_ZeroAddress();
        address prev = vault;
        vault = newVault;
        emit GovernorSet(prev, newVault);
    }

    function setFeeBps(uint256 newBps) external onlyGovernor {
        if (newBps > WOMBLEDEV_BPS_BASE) revert WombleDev_InvalidBps();
        uint256 prev = feeBps;
        feeBps = newBps;
        emit FeeBpsUpdated(prev, newBps);
    }

    function setMinStakeWei(uint256 newMin) external onlyGovernor {
        uint256 prev = minStakeWei;
        minStakeWei = newMin;
        emit MinStakeUpdated(prev, newMin);
    }

    function setMaxPositionsPerUser(uint256 newMax) external onlyGovernor {
        uint256 prev = maxPositionsPerUser;
        maxPositionsPerUser = newMax;
        emit MaxPositionsUpdated(prev, newMax);
    }

    function setCooldownBlocks(uint256 newCooldown) external onlyGovernor {
        uint256 prev = cooldownBlocks;
        cooldownBlocks = newCooldown;
        emit CooldownUpdated(prev, newCooldown);
    }

    function setEpochLengthSecs(uint256 newLength) external onlyGovernor {
        uint256 prev = epochLengthSecs;
        epochLengthSecs = newLength;
        emit EpochLengthUpdated(prev, newLength);
    }

    function placeOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator whenClawNotPaused returns (uint256 orderId) {
        if (amountIn == 0) revert WombleDev_ZeroAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert WombleDev_ZeroAddress();
        if (deadline <= block.timestamp) revert WombleDev_DeadlinePassed();
        orderCounter++;
        orderId = orderCounter;
        orders[orderId] = WombleDevOrder({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: deadline,
            filled: false,
            cancelled: false,
            placedAtBlock: block.number
        });
        emit OrderQueued(orderId, tokenIn, tokenOut, amountIn, amountOutMin, deadline);
        return orderId;
    }

    function executeOrder(uint256 orderId) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        WombleDevOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert WombleDev_OrderMissing();
        if (o.filled) revert WombleDev_OrderAlreadySettled();
        if (o.cancelled) revert WombleDev_OrderCancelled();
        if (block.timestamp > o.deadline) revert WombleDev_OrderCancelled();
        address[] memory path = new address[](2);
        path[0] = o.tokenIn;
        path[1] = o.tokenOut;
        IERC20WomblePulse(o.tokenIn).transferFrom(vault, address(this), o.amountIn);
        IERC20WomblePulse(o.tokenIn).approve(router, o.amountIn);
        uint256 balanceBefore = IERC20WomblePulse(o.tokenOut).balanceOf(vault);
        try IWomblePulseRouter(router).swapExactTokensForTokens(
            o.amountIn,
            o.amountOutMin,
            path,
            vault,
            o.deadline
        ) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            IERC20WomblePulse(o.tokenIn).approve(router, 0);
            bool refund = IERC20WomblePulse(o.tokenIn).transfer(vault, o.amountIn);
            if (!refund) revert WombleDev_TransferReverted();
            revert WombleDev_RouterReverted();
        }
        IERC20WomblePulse(o.tokenIn).approve(router, 0);
        uint256 balanceAfter = IERC20WomblePulse(o.tokenOut).balanceOf(vault);
        if (balanceAfter <= balanceBefore) revert WombleDev_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        o.filled = true;
        emit OrderFilled(orderId, amountOut, block.number);
        return amountOut;
    }

    function cancelOrder(uint256 orderId) external onlyOperator {
        WombleDevOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert WombleDev_OrderMissing();
        if (o.filled) revert WombleDev_OrderAlreadySettled();
        o.cancelled = true;
        emit OrderCancelled(orderId, block.number);
    }

    function executeSwapDirect(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert WombleDev_ZeroAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert WombleDev_ZeroAddress();
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        if (IERC20WomblePulse(tokenIn).balanceOf(vault) < amountIn) revert WombleDev_VaultInsufficient();
        IERC20WomblePulse(tokenIn).transferFrom(vault, address(this), amountIn);
        IERC20WomblePulse(tokenIn).approve(router, amountIn);
        uint256 balanceBefore = IERC20WomblePulse(tokenOut).balanceOf(vault);
        try IWomblePulseRouter(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            vault,
            deadline
        ) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            IERC20WomblePulse(tokenIn).approve(router, 0);
            bool refund = IERC20WomblePulse(tokenIn).transfer(vault, amountIn);
            if (!refund) revert WombleDev_TransferReverted();
            revert WombleDev_RouterReverted();
        }
        IERC20WomblePulse(tokenIn).approve(router, 0);
        uint256 balanceAfter = IERC20WomblePulse(tokenOut).balanceOf(vault);
        if (balanceAfter <= balanceBefore) revert WombleDev_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        return amountOut;
    }

    function topTreasury() external payable {
        if (msg.value == 0) revert WombleDev_ZeroAmount();
        (bool sent,) = treasury.call{value: msg.value}("");
        if (!sent) revert WombleDev_TransferReverted();
        emit TreasuryTopped(msg.sender, msg.value);
    }

    function withdrawTreasury(uint256 amountWei, address to) external onlyTreasury nonReentrant {
        if (to == address(0)) revert WombleDev_ZeroAddress();
        if (totalWithdrawnWei + amountWei > WOMBLEDEV_WITHDRAW_CAP_WEI) revert WombleDev_WithdrawOverCap();
        totalWithdrawnWei += amountWei;
        (bool sent,) = to.call{value: amountWei}("");
        if (!sent) revert WombleDev_TransferReverted();
        emit TreasuryWithdrawn(to, amountWei);
    }

    function allocateClaw(uint256 strategyId, address beneficiary, uint256 amountWei) external onlyOperator whenClawNotPaused nonReentrant {
        if (beneficiary == address(0)) revert WombleDev_ZeroAddress();
        if (amountWei == 0) revert WombleDev_ZeroAmount();
        WombleDevStrategy storage s = strategies[strategyId];
        if (!s.active) revert WombleDev_InvalidStrategyId();
        if (s.sealed) revert WombleDev_StrategySealed();
        if (s.allocUsedWei + amountWei > s.allocCapWei) revert WombleDev_AllocCapExceeded();
        if (amountWei > WOMBLEDEV_MAX_ALLOC_PER_EPOCH_WEI) revert WombleDev_AllocOverflow();
        s.allocUsedWei += amountWei;
        allocCounter++;
        (bool sent,) = beneficiary.call{value: amountWei}("");
        if (!sent) revert WombleDev_VaultSweepFailed();
        emit ClawAllocation(allocCounter, beneficiary, amountWei, strategyId, uint40(block.number));
    }

    function registerStrategy(uint256 strategyId, uint256 allocCapWei) external onlyGovernor {
        if (strategies[strategyId].lastTickBlock != 0) revert WombleDev_InvalidStrategyId();
        strategies[strategyId] = WombleDevStrategy({
            allocCapWei: allocCapWei,
            allocUsedWei: 0,
            tickEpoch: 0,
            lastTickBlock: block.number,
            sealed: false,
            active: true,
            confidenceTier: 0
        });
    }

    function sealStrategy(uint256 strategyId) external onlyGovernor {
        WombleDevStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert WombleDev_InvalidStrategyId();
        s.sealed = true;
        emit StrategyTick(strategyId, s.tickEpoch, s.allocUsedWei, uint40(block.number));
    }

    function tickStrategy(uint256 strategyId) external onlyOperator {
        WombleDevStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert WombleDev_InvalidStrategyId();
        if (s.sealed) revert WombleDev_StrategySealed();
        s.tickEpoch++;
        s.lastTickBlock = block.number;
        emit StrategyTick(strategyId, s.tickEpoch, s.allocUsedWei, uint40(block.number));
    }

    function sweepVault(uint256 amountWei) external onlyOperator nonReentrant whenClawNotPaused {
        if (amountWei == 0) revert WombleDev_ZeroAmount();
        if (address(this).balance < amountWei) revert WombleDev_VaultInsufficient();
        sweepCounter++;
        (bool sent,) = vault.call{value: amountWei}("");
        if (!sent) revert WombleDev_VaultSweepFailed();
        emit VaultSweep(msg.sender, amountWei, sweepCounter, uint40(block.number));
    }

    function openPosition(uint256 strategyId, uint256 sizeWei) external whenClawNotPaused nonReentrant returns (uint256 positionId) {
        if (userStakeWei[msg.sender] < minStakeWei) revert WombleDev_StakeTooLow();
        if (agentsSuspended[msg.sender]) revert WombleDev_AgentSuspended();
        if (userPositionCount[msg.sender] >= maxPositionsPerUser) revert WombleDev_MaxPositionsReached();
        WombleDevStrategy storage s = strategies[strategyId];
        if (!s.active || s.lastTickBlock == 0) revert WombleDev_InvalidStrategyId();
        if (sizeWei == 0) revert WombleDev_InvalidPositionSize();
        positionCounter++;
        positionId = positionCounter;
        positions[positionId] = WombleDevPosition({
            user: msg.sender,
            strategyId: strategyId,
            sizeWei: sizeWei,
            openedAtBlock: block.number,
            entryPriceE8: 0,
            closed: false,
            realisedWei: 0
        });
        userPositionCount[msg.sender]++;
        emit PositionOpened(msg.sender, positionId, sizeWei, strategyId);
        return positionId;
    }

    function closePosition(uint256 positionId, uint256 realisedWei) external nonReentrant {
        WombleDevPosition storage p = positions[positionId];
        if (p.openedAtBlock == 0) revert WombleDev_PositionNotFound();
        if (p.user != msg.sender && msg.sender != operator) revert WombleDev_ClawDenied();
        if (p.closed) revert WombleDev_OrderAlreadySettled();
        p.closed = true;
        p.realisedWei = realisedWei;
        userPositionCount[p.user]--;
        emit PositionClosed(p.user, positionId, realisedWei);
    }

    function depositStake() external payable {
        if (msg.value == 0) revert WombleDev_ZeroAmount();
        userStakeWei[msg.sender] += msg.value;
        totalStakedWei += msg.value;
        emit StakeDeposited(msg.sender, msg.value);
    }

    function requestWithdrawStake(uint256 amountWei) external {
        if (amountWei == 0) revert WombleDev_ZeroAmount();
        if (userStakeWei[msg.sender] < amountWei) revert WombleDev_VaultInsufficient();
        if (block.number < lastExecutionBlock[msg.sender] + cooldownBlocks) revert WombleDev_CooldownActive();
        withdrawRequestCounter++;
        withdrawRequests[withdrawRequestCounter] = WombleDevWithdrawRequest({
            user: msg.sender,
            amountWei: amountWei,
            requestedAtBlock: block.number,
            completed: false
        });
        emit WithdrawRequested(msg.sender, amountWei, withdrawRequestCounter);
    }

    function completeWithdrawRequest(uint256 requestId) external onlyOperator nonReentrant {
        WombleDevWithdrawRequest storage r = withdrawRequests[requestId];
        if (r.requestedAtBlock == 0) revert WombleDev_OrderMissing();
        if (r.completed) revert WombleDev_OrderAlreadySettled();
        if (userStakeWei[r.user] < r.amountWei) revert WombleDev_VaultInsufficient();
        r.completed = true;
        userStakeWei[r.user] -= r.amountWei;
        totalStakedWei -= r.amountWei;
        (bool sent,) = r.user.call{value: r.amountWei}("");
        if (!sent) revert WombleDev_TransferReverted();
        emit WithdrawCompleted(r.user, r.amountWei, requestId);
    }

    function recordDeposit() external payable returns (uint256 depositId) {
        if (msg.value == 0) revert WombleDev_ZeroAmount();
        depositCounter++;
        depositId = depositCounter;
        deposits[depositId] = WombleDevDeposit({
            user: msg.sender,
            amountWei: msg.value,
            depositedAtBlock: block.number,
            swept: false
        });
        emit DepositSwept(msg.sender, msg.value, depositId);
        return depositId;
    }

    function getOrder(uint256 orderId) external view returns (
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bool filled,
        bool cancelled,
        uint256 placedAtBlock
    ) {
        WombleDevOrder storage o = orders[orderId];
        if (o.placedAtBlock == 0) revert WombleDev_OrderMissing();
        return (
            o.tokenIn,
            o.tokenOut,
            o.amountIn,
            o.amountOutMin,
            o.deadline,
            o.filled,
            o.cancelled,
            o.placedAtBlock
        );
    }

    function getStrategy(uint256 strategyId) external view returns (
        uint256 allocCapWei,
        uint256 allocUsedWei,
        uint256 tickEpoch,
        uint256 lastTickBlock,
        bool sealed,
        bool active,
        uint8 confidenceTier
    ) {
        WombleDevStrategy storage s = strategies[strategyId];
        if (s.lastTickBlock == 0) revert WombleDev_InvalidStrategyId();
        return (
            s.allocCapWei,
            s.allocUsedWei,
            s.tickEpoch,
            s.lastTickBlock,
            s.sealed,
            s.active,
            s.confidenceTier
        );
    }

    function getPosition(uint256 positionId) external view returns (
        address user,
        uint256 strategyId,
        uint256 sizeWei,
        uint256 openedAtBlock,
        uint256 entryPriceE8,
        bool closed,
        uint256 realisedWei
    ) {
        WombleDevPosition storage p = positions[positionId];
        if (p.openedAtBlock == 0) revert WombleDev_PositionNotFound();
        return (
            p.user,
            p.strategyId,
            p.sizeWei,
            p.openedAtBlock,
            p.entryPriceE8,
            p.closed,
            p.realisedWei
        );
    }

    function getOrderCount() external view returns (uint256) {
        return orderCounter;
    }

    function getTotalWithdrawnWei() external view returns (uint256) {
        return totalWithdrawnWei;
    }

    function getTotalStakedWei() external view returns (uint256) {
        return totalStakedWei;
    }

    function withdrawStuckToken(address token, address to, uint256 amount) external onlyGovernor {
        if (to == address(0)) revert WombleDev_ZeroAddress();
        bool ok = IERC20WomblePulse(token).transfer(to, amount);
        if (!ok) revert WombleDev_TransferReverted();
    }

    function openRound(bytes32 promptDigest) external whenClawNotPaused returns (uint256 roundId) {
        if (promptToRound[promptDigest] != 0) revert WombleDev_DuplicateCommit();
        roundCounter++;
        roundId = roundCounter;
        rounds[roundId] = WombleDevInferenceRound({
            promptDigest: promptDigest,
            responseRoot: bytes32(0),
            startedAt: block.timestamp,
            sealedAt: 0,
            finalized: false,
            confidenceTier: 0,
            proposer: msg.sender
        });
        promptToRound[promptDigest] = roundId;
        emit RoundOpened(roundId, promptDigest, msg.sender);
        return roundId;
    }

    function sealRound(uint256 roundId, bytes32 responseRoot, uint8 confidenceTier) external onlyOperator {
        WombleDevInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert WombleDev_InvalidRoundId();
        if (r.finalized) revert WombleDev_RoundNotSealed();
        if (confidenceTier > WOMBLEDEV_MAX_CONFIDENCE_TIER) revert WombleDev_InvalidConfidence();
        r.responseRoot = responseRoot;
        r.sealedAt = block.timestamp;
        r.confidenceTier = confidenceTier;
        emit RoundSealed(roundId, responseRoot, confidenceTier);
    }

    function finalizeRound(uint256 roundId) external onlyOperator {
        WombleDevInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert WombleDev_InvalidRoundId();
        if (r.sealedAt == 0) revert WombleDev_RoundNotSealed();
        r.finalized = true;
        emit RoundFinalized(roundId);
    }

    function registerAgent(bytes32 modelFingerprint) external {
        emit AgentRegistered(msg.sender, modelFingerprint);
    }

    function suspendAgent(address agent, bool suspended) external onlyGovernor {
        agentsSuspended[agent] = suspended;
    }

    function consumeNonce(bytes32 nonce) external onlyOperator {
        if (nonceUsed[nonce]) revert WombleDev_NonceUsed();
        nonceUsed[nonce] = true;
        emit NonceConsumed(nonce, msg.sender);
    }

    function scheduleUpgrade(uint256 nextVersion) external onlyGovernor {
        nextLogicVersion = nextVersion;
        upgradeEffectiveBlock = block.number + WOMBLEDEV_UPGRADE_MIN_DELAY_BLOCKS;
        emit UpgradeScheduled(nextVersion, upgradeEffectiveBlock);
    }

    function applyUpgrade() external onlyGovernor {
        if (block.number < upgradeEffectiveBlock) revert WombleDev_EpochNotReached();
        logicVersion = nextLogicVersion;
        emit UpgradeApplied(logicVersion, block.number);
    }

    function enqueueTask(bytes32 taskHash, uint8 priority) external whenClawNotPaused returns (uint256 taskIndex) {
        if (taskQueueIndex >= taskQueueCap) revert WombleDev_AllocOverflow();
        taskQueue[taskQueueIndex] = WombleDevTaskEntry({
            taskHash: taskHash,
            requester: msg.sender,
            enqueuedBlock: block.number,
            priority: priority,
            executed: false,
            executedAtBlock: 0
        });
        taskIndex = taskQueueIndex;
        taskQueueIndex++;
        taskIdToQueueIndex[taskHash] = taskIndex;
        emit TaskEnqueued(taskIndex, taskHash, msg.sender, priority);
        return taskIndex;
    }

    function executeTask(uint256 taskIndex) external onlyOperator nonReentrant whenClawNotPaused {
        if (taskIndex >= taskQueueIndex) revert WombleDev_InvalidRoundId();
        WombleDevTaskEntry storage t = taskQueue[taskIndex];
        if (t.executed) revert WombleDev_OrderAlreadySettled();
        if (block.number < lastExecutionBlock[tx.origin] + executionCooldownBlocks) revert WombleDev_CooldownActive();
        t.executed = true;
        t.executedAtBlock = block.number;
        executionCountByAddress[tx.origin]++;
        totalExecutions++;
        lastExecutionBlock[tx.origin] = block.number;
        emit TaskExecuted(taskIndex, block.number);
    }

    function attestCapability(uint256 slotIndex, bytes32 capabilityId) external {
        if (slotIndex >= capabilitySlots) revert WombleDev_InvalidStrategyId();
        WombleDevCapabilitySlot storage c = capabilityByIndex[slotIndex];
        if (c.attestedAtBlock != 0 && !c.revoked) revert WombleDev_StrategySealed();
        c.capabilityId = capabilityId;
        c.attester = msg.sender;
        c.attestedAtBlock = block.number;
        c.revoked = false;
        emit CapabilityAttested(slotIndex, capabilityId, msg.sender);
    }

    function revokeCapability(uint256 slotIndex) external onlyGovernor {
        if (slotIndex >= capabilitySlots) revert WombleDev_InvalidStrategyId();
        capabilityByIndex[slotIndex].revoked = true;
        emit CapabilityRevoked(slotIndex, block.number);
    }

    function disburseReward(address to, uint256 amountWei) external onlyGovernor nonReentrant {
        if (to == address(0)) revert WombleDev_ZeroAddress();
        if (amountWei == 0) revert WombleDev_ZeroAmount();
        (bool sent,) = to.call{value: amountWei}("");
        if (!sent) revert WombleDev_TransferReverted();
        totalRewardDisbursed += amountWei;
        emit RewardDisbursed(to, amountWei);
    }

    function getRound(uint256 roundId) external view returns (
        bytes32 promptDigest,
        bytes32 responseRoot,
        uint256 startedAt,
        uint256 sealedAt,
        bool finalized,
        uint8 confidenceTier,
        address proposer
    ) {
        WombleDevInferenceRound storage r = rounds[roundId];
        if (r.startedAt == 0) revert WombleDev_InvalidRoundId();
        return (
            r.promptDigest,
            r.responseRoot,
            r.startedAt,
            r.sealedAt,
            r.finalized,
            r.confidenceTier,
            r.proposer
        );
    }

    function getTask(uint256 taskIndex) external view returns (
        bytes32 taskHash,
        address requester,
        uint256 enqueuedBlock,
        uint8 priority,
        bool executed,
        uint256 executedAtBlock
    ) {
        if (taskIndex >= taskQueueIndex) revert WombleDev_InvalidRoundId();
        WombleDevTaskEntry storage t = taskQueue[taskIndex];
        return (
            t.taskHash,
            t.requester,
            t.enqueuedBlock,
            t.priority,
            t.executed,
            t.executedAtBlock
        );
    }

    function getCapability(uint256 slotIndex) external view returns (
        bytes32 capabilityId,
        address attester,
        uint256 attestedAtBlock,
        bool revoked
    ) {
        if (slotIndex >= capabilitySlots) revert WombleDev_InvalidStrategyId();
        WombleDevCapabilitySlot storage c = capabilityByIndex[slotIndex];
        return (
            c.capabilityId,
            c.attester,
            c.attestedAtBlock,
            c.revoked
        );
    }

    function getDeposit(uint256 depositId) external view returns (
        address user,
        uint256 amountWei,
        uint256 depositedAtBlock,
        bool swept
    ) {
        WombleDevDeposit storage d = deposits[depositId];
        if (d.depositedAtBlock == 0) revert WombleDev_OrderMissing();
        return (
            d.user,
            d.amountWei,
            d.depositedAtBlock,
            d.swept
        );
    }

    function getWithdrawRequest(uint256 requestId) external view returns (
        address user,
        uint256 amountWei,
        uint256 requestedAtBlock,
        bool completed
    ) {
        WombleDevWithdrawRequest storage r = withdrawRequests[requestId];
        if (r.requestedAtBlock == 0) revert WombleDev_OrderMissing();
        return (
            r.user,
            r.amountWei,
            r.requestedAtBlock,
            r.completed
        );
    }

    receive() external payable {}

    // -------------------------------------------------------------------------
    // Extended swap and path helpers (multi-hop, ETH pairs)
    // -------------------------------------------------------------------------

    function executeSwapExactTokensForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        if (amountIn == 0) revert WombleDev_ZeroAmount();
        if (tokenIn == address(0)) revert WombleDev_ZeroAddress();
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = weth;
        if (IERC20WomblePulse(tokenIn).balanceOf(vault) < amountIn) revert WombleDev_VaultInsufficient();
        IERC20WomblePulse(tokenIn).transferFrom(vault, address(this), amountIn);
        IERC20WomblePulse(tokenIn).approve(router, amountIn);
        uint256 balanceBefore = address(vault).balance;
        try IWomblePulseRouter(router).swapExactTokensForETH(amountIn, amountOutMin, path, vault, deadline) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            IERC20WomblePulse(tokenIn).approve(router, 0);
            bool refund = IERC20WomblePulse(tokenIn).transfer(vault, amountIn);
            if (!refund) revert WombleDev_TransferReverted();
            revert WombleDev_RouterReverted();
        }
        IERC20WomblePulse(tokenIn).approve(router, 0);
        uint256 balanceAfter = address(vault).balance;
        if (balanceAfter <= balanceBefore) revert WombleDev_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        return amountOut;
    }

    function executeSwapExactETHForTokens(
        address tokenOut,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator payable nonReentrant whenClawNotPaused returns (uint256 amountOut) {
        if (msg.value == 0) revert WombleDev_ZeroAmount();
        if (tokenOut == address(0)) revert WombleDev_ZeroAddress();
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenOut;
        uint256 balanceBefore = IERC20WomblePulse(tokenOut).balanceOf(vault);
        try IWomblePulseRouter(router).swapExactETHForTokens{value: msg.value}(amountOutMin, path, vault, deadline) returns (uint256[] memory amounts) {
            amountOut = amounts[amounts.length - 1];
        } catch {
            (bool sent,) = msg.sender.call{value: msg.value}("");
            if (!sent) revert WombleDev_TransferReverted();
            revert WombleDev_RouterReverted();
        }
        uint256 balanceAfter = IERC20WomblePulse(tokenOut).balanceOf(vault);
        if (balanceAfter <= balanceBefore) revert WombleDev_TransferReverted();
        amountOut = balanceAfter - balanceBefore;
        return amountOut;
    }

    function placeOrderMultiHop(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyOperator whenClawNotPaused returns (uint256 orderId) {
        if (path.length < WOMBLEDEV_MIN_PATH_LEN || path.length > WOMBLEDEV_MAX_PATH_LEN) revert WombleDev_PathLengthInvalid();
        if (amountIn == 0) revert WombleDev_ZeroAmount();
        if (deadline <= block.timestamp) revert WombleDev_DeadlinePassed();
        for (uint256 i = 0; i < path.length; i++) {
            if (path[i] == address(0)) revert WombleDev_ZeroAddress();
        }
        orderCounter++;
        orderId = orderCounter;
        orders[orderId] = WombleDevOrder({
            tokenIn: path[0],
            tokenOut: path[path.length - 1],
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: deadline,
            filled: false,
            cancelled: false,
            placedAtBlock: block.number
        });
        emit OrderQueued(orderId, path[0], path[path.length - 1], amountIn, amountOutMin, deadline);
        return orderId;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getVaultBalance() external view returns (uint256) {
        return address(vault).balance;
    }

    function getTokenBalanceInVault(address token) external view returns (uint256) {
        if (token == address(0)) return address(vault).balance;
        return IERC20WomblePulse(token).balanceOf(vault);
    }

    function getTokenBalanceInContract(address token) external view returns (uint256) {
        if (token == address(0)) return address(this).balance;
        return IERC20WomblePulse(token).balanceOf(address(this));
    }

    function isOrderFilled(uint256 orderId) external view returns (bool) {
        return orders[orderId].filled;
    }

    function isOrderCancelled(uint256 orderId) external view returns (bool) {
        return orders[orderId].cancelled;
    }

    function isStrategyActive(uint256 strategyId) external view returns (bool) {
        return strategies[strategyId].active && !strategies[strategyId].sealed;
    }

    function isStrategySealed(uint256 strategyId) external view returns (bool) {
        return strategies[strategyId].sealed;
    }

    function getUserPositionCount(address user) external view returns (uint256) {
        return userPositionCount[user];
    }

    function getUserStakeWei(address user) external view returns (uint256) {
        return userStakeWei[user];
    }

    function getLastExecutionBlock(address user) external view returns (uint256) {
        return lastExecutionBlock[user];
    }

    function isNonceUsed(bytes32 nonce) external view returns (bool) {
        return nonceUsed[nonce];
    }

    function isAgentSuspended(address agent) external view returns (bool) {
        return agentsSuspended[agent];
    }
