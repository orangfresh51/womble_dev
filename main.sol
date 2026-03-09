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
