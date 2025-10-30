// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

library BitsaveHelperLib {
    using PRBMathUD60x18 for uint256;
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant txnCharge = 0.02 ether;
    // For interest calculation
    uint256 public constant maxSupply = 100_000_000;
    uint256 public constant totalSupply = 15_000_000;
    // just a default of 365 days
    uint256 public constant yearInSeconds = 3600 * 24 * 365;
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

    function approveAmount(
        address toApproveUserAddress,
        uint256 amountToApprove,
        address targetToken
    ) internal returns (bool) {
        IERC20 token = IERC20(targetToken);
        token.forceApprove(toApproveUserAddress, amountToApprove);
        return true;
    }

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

    // integrate bitsave interest calculator
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

    function tokenBalance(address tokenAddr) internal view returns (uint256) {
        IERC20 token = IERC20(tokenAddr);
        return token.balanceOf(address(this));
    }

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
