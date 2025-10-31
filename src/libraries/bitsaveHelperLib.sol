// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

/**
 * @title BitsaveHelperLib
 * @notice Small utility library used by Bitsave and ChildBitsave for token handling,
 *         approvals and the Bitsave interest calculation helpers.
 * @dev Uses PRBMath for fixed-point math and OpenZeppelin's SafeERC20 for safe transfers.
 */
library BitsaveHelperLib {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    // Constants
    /// @notice Transaction charge used as a default constant (in wei)
    uint256 public constant txnCharge = 0.02 ether;
    /// @notice Maximum supply used by the bitsave interest algorithm
    uint256 public constant maxSupply = 100_000_000;
    /// @notice Internal totalSupply constant used by the interest algorithm
    uint256 public constant totalSupply = 15_000_000;
    /// @notice Seconds in a year (approximation) used to convert intervals to years
    uint256 public constant yearInSeconds = 3600 * 24 * 365;
    /// @notice Divisor applied in interest math to scale values into fixed point
    uint256 public constant divisor = 1_000 ether;

    // Errors
    error WrongGasContract();
    error NotEnoughToPayGasFee();
    error AmountNotEnough();
    error InvalidTime();
    error UserNotRegistered();
    error InvalidSaving();
    error CanNotWithdrawToken(address);
    error NotSupported(string);
    error MasterCallRequired();
    // child contract specific
    error CallNotFromBitsave();

    // Events
    event JoinedBitsave(address indexed userAddress);
    event SavingCreated(
        string indexed nameOfSaving,
        uint256 amount,
        address token
    );
    event SavingIncremented(
        string indexed nameOfSaving,
        uint256 amountAdded,
        uint256 totalAmountNow,
        address token
    );
    event SavingWithdrawn(string indexed nameOfSaving);
    event TokenWithdrawal(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Received(address indexed, uint256);
    event SystemFaucetDrip(address indexed token, uint256 value);

    /**
     * @notice Force-approve `toApproveUserAddress` for `amountToApprove` on `targetToken`
     * @dev Uses OpenZeppelin's SafeERC20 `forceApprove` (non-standard helper) to set allowance
     * @param toApproveUserAddress The address to approve (spender)
     * @param amountToApprove Amount of tokens to allow
     * @param targetToken ERC-20 token contract address
     * @return bool Always returns true on success
     */
    function approveAmount(
        address toApproveUserAddress,
        uint256 amountToApprove,
        address targetToken
    ) internal returns (bool) {
        IERC20 token = IERC20(targetToken);
        token.forceApprove(toApproveUserAddress, amountToApprove);
        return true;
    }

    /**
     * @notice Retrieve `amountToWithdraw` tokens from `toApproveUserAddress` into this contract
     * @dev Requires the user to have previously approved this contract to pull `amountToWithdraw`.
     * @param toApproveUserAddress The user address from which tokens are pulled
     * @param targetToken ERC-20 token contract address
     * @param amountToWithdraw Amount to transfer (token smallest unit)
     * @return bool True on success
     */
    function retrieveToken(
        address toApproveUserAddress,
        address targetToken,
        uint256 amountToWithdraw
    ) internal returns (bool) {
        // first request approval
        require(
            // approveAmount(toApproveUserAddress, amountToWithdraw, targetToken),
            IERC20(targetToken).allowance(
                toApproveUserAddress,
                address(this)
            ) >= amountToWithdraw,
            CanNotWithdrawToken(targetToken)
        );
        IERC20(targetToken).safeTransferFrom(
            toApproveUserAddress,
            address(this),
            amountToWithdraw
        );
        return true;
    }

    /**
     * @notice Simple fallback interest calculator (1% of amount)
     * @param amount Principal amount
     * @return accumulatedInterest Computed interest (amount / 100)
     */
    function calculateInterest(
        uint256 amount
    )
        internal
        pure
        returns (
            // uint256 currBitsPointValue
            uint256 accumulatedInterest
        )
    {
        accumulatedInterest = amount / 100;
    }

    /**
     * @notice Calculate interest/points using the Bitsave formula
     * @dev Uses PRBMath fixed-point helpers for part of the calculation. The formula
     *      uses protocol-wide constants and provided vault/T LV parameters.
     * @param principal Principal amount to calculate interest on
     * @param timeInterval Time duration in seconds; converted to years for the formula
     * @param vaultState Current vault state parameter (internal)
     * @param totalValueLocked Current total value locked parameter (internal)
     * @return accumulatedInterest Computed accumulated interest / points
     */
    function calculateInterestWithBTS(
        // External data
        uint256 principal,
        uint256 timeInterval, // will be converted to years
        // Internal data
        uint256 vaultState,
        uint256 totalValueLocked
    ) internal pure returns (uint256 accumulatedInterest) {
        uint256 crp = ((totalSupply - vaultState).div(vaultState)).mul(100);
        uint256 bsRate = maxSupply.div(crp * totalValueLocked);
        uint256 yearsTaken = timeInterval.div(yearInSeconds);
        accumulatedInterest = (
            (principal * bsRate * yearsTaken).div(100 * divisor)
        ).toUint();
    }

    /**
     * @notice Get the ERC-20 balance of `tokenAddr` for this contract
     * @param tokenAddr Token contract address
     * @return uint256 Token balance of this contract
     */
    function tokenBalance(address tokenAddr) internal view returns (uint256) {
        IERC20 token = IERC20(tokenAddr);
        return token.balanceOf(address(this));
    }

    /**
     * @notice Transfer `amount` of `token` to `recipient` and emit TokenWithdrawal
     * @param token Token contract address
     * @param recipient Address receiving tokens
     * @param amount Amount to transfer
     * @return bool isDelivered True on successful transfer
     */
    function transferToken(
        address token,
        address recipient,
        uint256 amount
    ) internal returns (bool isDelivered) {
        IERC20 Token = IERC20(token);
        Token.safeTransfer(recipient, amount);
        isDelivered = true;
        emit TokenWithdrawal(address(this), recipient, amount);
    }
}
