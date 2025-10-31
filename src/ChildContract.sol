// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/bitsaveHelperLib.sol";
import "./Bitsave.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ChildBitsave
 * @notice Per-user child contract deployed by `Bitsave` to manage individual savings
 *         entries. Each saving slot contains metadata and accumulated interest (points).
 * @dev Functions that modify state are restricted to be callable only by the parent
 *      `Bitsave` contract using the `bitsaveOnly` modifier.
 */
contract ChildBitsave is ReentrancyGuard {
    // *** Contract parameters ***
    address payable public bitsaveAddress;
    IERC20 public stableCoin;
    address public ownerAddress;

    // *** Contract Storage ***
    // total interests gathered; v1 shows points
    uint256 public totalPoints;

    // structure of saving data
    /**
     * @dev SavingDataStruct holds all data for a single saving slot
     * @param isValid Whether this saving slot is active
     * @param amount Principal amount stored for the saving (in token smallest unit or wei)
     * @param tokenId Address of token stored (address(0) for native)
     * @param interestAccumulated Interest/points accumulated for this saving
     * @param startTime UNIX timestamp when the saving started
     * @param penaltyPercentage Penalty applied for early withdrawal (0-100)
     * @param maturityTime UNIX timestamp when saving matures
     * @param isSafeMode If true, the saving uses the protocol's safe conversion flow
     */
    struct SavingDataStruct {
        bool isValid;
        uint256 amount;
        address tokenId;
        uint256 interestAccumulated;
        uint256 startTime;
        uint256 penaltyPercentage;
        uint256 maturityTime;
        bool isSafeMode;
    }

    // mapping of name of saving to individual saving
    mapping(string => SavingDataStruct) public savings;

    struct SavingsNamesObj {
        string[] savingsNames;
    }

    /**
     * @dev Update the internal `totalPoints` counter. Private helper.
     * @param newPoint Amount of points to add
     */
    function updatePoints(uint256 newPoint) private {
        totalPoints = totalPoints + newPoint;
    }

    /**
     * @notice Calculate interest (points) for a saving interval and update totals
     * @dev Uses `BitsaveHelperLib.calculateInterestWithBTS` to compute accumulated interest
     * @param savingAmount Principal amount for the calculation
     * @param endTime UNIX timestamp representing the end (maturity) time
     * @param startTime UNIX timestamp representing the start time
     * @param currentVaultState Vault state parameter used in calculation
     * @param currentTotalValueLocked TVL parameter used in calculation
     * @return accumulatedInterest The computed interest/points for this interval
     */
    function calculateAndUpdatePoints(
        uint256 savingAmount,
        uint256 endTime,
        uint256 startTime,
        uint256 currentVaultState,
        uint256 currentTotalValueLocked
    ) internal returns (uint256 accumulatedInterest) {
        accumulatedInterest = BitsaveHelperLib.calculateInterestWithBTS(
            savingAmount,
            endTime - startTime, // time interval
            currentVaultState,
            currentTotalValueLocked
        );

        totalPoints += accumulatedInterest;
    }

    SavingsNamesObj private savingsNamesVar;

    /**
     * @notice Deploy a ChildBitsave for a single user
     * @param _ownerAddress The account that owns this child contract (the user)
     * @param _stableCoin Address of the stablecoin used by the protocol
     * @dev The `msg.sender` is expected to be the parent `Bitsave` contract which
     *      becomes `bitsaveAddress` and is authorized to call `bitsaveOnly` methods.
     */
    constructor(address _ownerAddress, address _stableCoin) payable {
        // save bitsaveAddress first // todo: retrieve correct address
        bitsaveAddress = payable(msg.sender);
        // store owner's address
        ownerAddress = payable(_ownerAddress);
        // store stable coin
        stableCoin = IERC20(payable(_stableCoin));
        // storage
        totalPoints = 0;
    }

    /**
     * @dev Restrict function calls to the parent `Bitsave` contract only
     */
    modifier bitsaveOnly() {
        if (msg.sender != bitsaveAddress) {
            revert BitsaveHelperLib.CallNotFromBitsave();
        }
        _;
    }

    /**
     * @dev Private helper to push a saving name into the `savingsNamesVar` list
     * @param _name The name/key of the saving to add
     */
    function addSavingName(string memory _name) private {
        savingsNamesVar.savingsNames.push(_name);
    }

    // Contract Getters
    /**
     * @notice Get whether a saving is in safe mode
     * @param nameOfSaving Name of the saving slot
     * @return bool True if the saving is in safe mode
     */
    function getSavingMode(
        string memory nameOfSaving
    ) external view returns (bool) {
        return savings[nameOfSaving].isSafeMode;
    }

    /**
     * @notice Read accumulated interest/points for a saving
     * @param nameOfSaving Name of the saving slot
     * @return uint256 Accumulated interest/points
     */
    function getSavingInterest(
        string memory nameOfSaving
    ) external view returns (uint256) {
        return savings[nameOfSaving].interestAccumulated;
    }

    /**
     * @notice Get the token id (address) used by a saving slot
     * @param nameOfSaving Name of the saving slot
     * @return address Token contract address, or address(0) for native
     */
    function getSavingTokenId(
        string memory nameOfSaving
    ) external view returns (address) {
        return savings[nameOfSaving].tokenId;
    }

    /**
     * @notice Get the principal balance for a saving slot
     * @param nameOfSaving Name of the saving slot
     * @return uint256 Principal amount stored
     */
    function getSavingBalance(
        string memory nameOfSaving
    ) external view returns (uint256) {
        return savings[nameOfSaving].amount;
    }

    /**
     * @notice Return an object containing the list of saving names for this user
     * @return SavingsNamesObj Struct holding the array of saving slot names
     */
    function getSavingsNames() external view returns (SavingsNamesObj memory) {
        return savingsNamesVar;
    }

    /**
     * @notice Get the full saving data struct for a saving slot
     * @param nameOfSaving Name of the saving slot
     * @return SavingDataStruct Full struct containing saving metadata and amounts
     */
    function getSaving(
        string memory nameOfSaving
    ) public view returns (SavingDataStruct memory) {
        return savings[nameOfSaving];
    }

    // functionality to create savings
    /**
     * @notice Create a new saving slot for the owner via the parent Bitsave contract
     * @dev Callable only by the parent `Bitsave` contract. Performs validations on
     *      maturity time and retrieves tokens/value using the helper library as needed.
     * @param name Human-readable unique name for this saving slot
     * @param maturityTime UNIX timestamp when the saving matures
     * @param startTime UNIX timestamp representing the saving start (passed from parent)
     * @param penaltyPercentage Penalty percentage for early withdrawal (0-100)
     * @param tokenId Token address used for this saving (address(0) for native)
     * @param amountToRetrieve Amount retrieved from the parent for this saving (or 0)
     * @param isSafeMode Whether the saving uses the safe conversion flow
     * @param currentVaultState Vault state parameter used for interest calculation
     * @param currentTotalValueLocked TVL parameter used for interest calculation
     * @return uint256 Returns 1 on success (legacy return)
     */
    function createSaving(
        string memory name,
        uint256 maturityTime,
        uint256 startTime,
        uint8 penaltyPercentage,
        address tokenId,
        uint256 amountToRetrieve,
        bool isSafeMode,
        uint256 currentVaultState,
        uint256 currentTotalValueLocked
    ) public payable bitsaveOnly nonReentrant returns (uint256) {
        // ensure saving does not exist; !
        if (savings[name].isValid) revert BitsaveHelperLib.InvalidSaving();
        // check if end time valid
        if (maturityTime < startTime) revert BitsaveHelperLib.InvalidTime();
        if (maturityTime < block.timestamp)
            revert BitsaveHelperLib.InvalidTime();

        uint256 savingsAmount = amountToRetrieve;

        if (isSafeMode) {
            BitsaveHelperLib.retrieveToken(
                bitsaveAddress,
                address(stableCoin),
                amountToRetrieve
            );
        } else {
            if (tokenId != address(0)) {
                BitsaveHelperLib.retrieveToken(
                    bitsaveAddress,
                    tokenId,
                    amountToRetrieve
                );
            } else {
                // case native token
                savingsAmount = msg.value;
            }
        }

        uint256 accumulatedInterest = calculateAndUpdatePoints(
            savingsAmount,
            maturityTime,
            startTime,
            currentVaultState,
            currentTotalValueLocked
        );

        // store saving to map of savings
        savings[name] = SavingDataStruct({
            amount: savingsAmount,
            maturityTime: maturityTime,
            interestAccumulated: accumulatedInterest,
            startTime: startTime,
            tokenId: tokenId,
            penaltyPercentage: penaltyPercentage,
            isSafeMode: isSafeMode,
            isValid: true
        });

        // addSavingName(name);
        addSavingName(name);

        emit BitsaveHelperLib.SavingCreated(name, amountToRetrieve, tokenId);

        return 1;
    }

    // functionality to add to savings
    /**
     * @notice Increment an existing saving slot by adding funds
     * @dev Callable only by parent `Bitsave`. Handles native and ERC-20 flows and
     *      updates accumulated interest accordingly.
     * @param name Name of the saving slot to increment
     * @param savingPlusAmount Amount to add (for ERC-20 flows). For native flows the
     *        `msg.value` will be used and must be >= expected amount.
     * @param currentVaultState Vault state parameter forwarded for interest calc
     * @param currentTotalValueLocked TVL parameter forwarded for interest calc
     * @return uint256 The updated accumulated interest for the saving
     */
    function incrementSaving(
        string memory name,
        uint256 savingPlusAmount,
        uint256 currentVaultState,
        uint256 currentTotalValueLocked
    ) public payable bitsaveOnly nonReentrant returns (uint256) {
        // fetch savings data
        SavingDataStruct storage toFundSavings = savings[name];
        if (!toFundSavings.isValid) revert BitsaveHelperLib.InvalidSaving();
        if (block.timestamp > toFundSavings.maturityTime)
            revert BitsaveHelperLib.InvalidTime();

        bool isNativeToken = toFundSavings.tokenId == address(0);

        // handle retrieving token from contract
        if (toFundSavings.isSafeMode) {
            BitsaveHelperLib.retrieveToken(
                bitsaveAddress,
                address(stableCoin),
                savingPlusAmount
            );
        } else {
            if (!isNativeToken) {
                BitsaveHelperLib.retrieveToken(
                    bitsaveAddress,
                    toFundSavings.tokenId,
                    savingPlusAmount
                );
            } else {
                require(
                    msg.value >= savingPlusAmount,
                    "Invalid saving increment value sent"
                );
                savingPlusAmount = msg.value;
            }
        }

        uint256 extraInterest = calculateAndUpdatePoints(
            savingPlusAmount,
            toFundSavings.maturityTime,
            block.timestamp,
            currentVaultState,
            currentTotalValueLocked
        );

        // calculate new interest
        toFundSavings.interestAccumulated =
            toFundSavings.interestAccumulated +
            extraInterest;
        toFundSavings.amount = toFundSavings.amount + savingPlusAmount;

        // save new savings data
        savings[name] = toFundSavings;

        emit BitsaveHelperLib.SavingIncremented(
            name,
            savingPlusAmount,
            toFundSavings.amount,
            toFundSavings.tokenId
        );

        return toFundSavings.interestAccumulated;
    }

    /**
     * @notice Withdraw a saving and deliver funds to the owner (handles penalties)
     * @dev Callable only by parent `Bitsave`. Applies penalty if withdrawn early and
     *      transfers the resulting amount to the owner. For safe-mode savings a
     *      conversion call back to the parent is performed.
     * @param name Name of the saving slot to withdraw
     * @return string Human-readable success message on successful delivery
     */
    function withdrawSaving(
        string memory name
    ) public payable bitsaveOnly nonReentrant returns (string memory) {
        SavingDataStruct storage toWithdrawSavings = savings[name];
        // check if saving exit
        if (!toWithdrawSavings.isValid) revert BitsaveHelperLib.InvalidSaving();
        uint256 amountToWithdraw = toWithdrawSavings.amount;
        Bitsave bitsave = Bitsave(bitsaveAddress);
        // check if saving is mature
        if (block.timestamp < toWithdrawSavings.maturityTime) {
            // remove penalty from savings
            amountToWithdraw =
                (toWithdrawSavings.amount *
                    (100 - toWithdrawSavings.penaltyPercentage)) /
                100;
            // transfer remnant to main contract
            BitsaveHelperLib.transferToken(
                toWithdrawSavings.tokenId,
                bitsaveAddress,
                toWithdrawSavings.amount - amountToWithdraw
            );
        } else {
            // TODO: handle interest point management
            // bitsave.handleUsersInterest(
            //     name,
            //     address(this),
            //     ownerAddress
            // );
        }
        // first gate value
        savings[name].isValid = false;

        // send the savings amount to withdraw
        address tokenId = toWithdrawSavings.tokenId;
        // function can be abstracted for sending token out
        bool isDelivered = false;
        if (toWithdrawSavings.isSafeMode) {
            // approve withdrawal from parent contract
            BitsaveHelperLib.approveAmount(
                bitsaveAddress,
                amountToWithdraw,
                address(stableCoin)
            );
            // call parent for conversion
            isDelivered = bitsave.sendAsOriginalToken(
                tokenId,
                amountToWithdraw,
                ownerAddress
            );
        } else {
            // todo: handle sending penalty to parent contract
            if (tokenId == address(0)) {
                (bool sent, bytes memory data) = ownerAddress.call{
                    value: amountToWithdraw
                }("");
                require(sent, "Couldn't send funds");
                isDelivered = sent;
            } else {
                isDelivered = BitsaveHelperLib.transferToken(
                    toWithdrawSavings.tokenId,
                    ownerAddress,
                    amountToWithdraw
                );
            }
        }
        // Delete savings; ensure saving is deleted/made invalid
        if (isDelivered) {
            savings[name].isValid = false;

            emit BitsaveHelperLib.SavingWithdrawn(name);

            return "savings withdrawn successfully";
        }

        revert();
    }
}
