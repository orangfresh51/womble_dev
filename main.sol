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
