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
