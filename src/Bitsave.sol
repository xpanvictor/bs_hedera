// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ChildContract.sol";
import "./libraries/bitsaveHelperLib.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Bitsave
 * @notice Implements a user-focused savings system where each user gets a child contract
 *         to manage savings entries. Supports native and ERC-20 savings, incremental
 *         deposits, and admin-controlled parameters.
 * @dev The contract deploys a per-user ChildBitsave contract on `joinBitsave()` and
 *      forwards savings operations to that child. Several functions use modifiers to
 *      restrict access (e.g., `inhouseOnly`, `registeredOnly`, `fromABitsaveChildOnly`).
 */
contract Bitsave is ReentrancyGuard {
    // *** Contract parameters ***
    IERC20 public stableCoin;
    IERC20 public csToken;
    address payable public masterAddress;
    uint256 public rewardPool;
    // *** Fountain ***
    uint256 public fountain;

    // *** Storage ***
    mapping(address => address) addressToUserBS;
    uint256 public userCount;
    // *** Storage requiring house modifiers ***
    uint256 public currentVaultState;
    uint256 public currentTotalValueLocked;

    // *** savings values ***
    // editing value from 0.0001 to 0wei
    uint256 public JoinLimitFee = 0;
    uint256 public SavingFee = 0.0001 ether;
    uint256 public ChildCutPerFee = 50;
    uint256 public ChildContractGasFee = SavingFee / ChildCutPerFee;

    /**
     * @notice Construct a new Bitsave instance
     * @param _stableCoin Address of the stablecoin ERC-20 used internally
     * @param _csToken Address of the csToken ERC-20 used for rewards/utility
     * @dev `msg.sender` becomes the `masterAddress`. The contract is payable so a
     *      starting `fountain` value may be provided.
     */
    constructor(address _stableCoin, address _csToken) payable {
        stableCoin = IERC20(_stableCoin);
        csToken = IERC20(_csToken);
        masterAddress = payable(msg.sender);
        rewardPool = 0;
        userCount = 0;
        // initial values
        currentVaultState = 14_000_000;
        currentTotalValueLocked = 100_000;
        fountain = msg.value;
    }

    modifier inhouseOnly() {
        if (msg.sender != masterAddress) {
            revert BitsaveHelperLib.MasterCallRequired();
        }
        _;
    }

    modifier registeredOnly(address sender) {
        if (addressToUserBS[sender] == address(0)) {
            revert BitsaveHelperLib.UserNotRegistered();
        }
        _;
    }

    modifier fromABitsaveChildOnly(address childOwnerAddress) {
        address fetchedChildAddress = addressToUserBS[childOwnerAddress];
        if (
            fetchedChildAddress == address(0) || // checks that the child contract exists
            // could be merged into one check but for readability
            fetchedChildAddress != msg.sender // and that the child contract sent the request
        ) {
            revert BitsaveHelperLib.CallNotFromBitsave();
        }
        _;
    }

    /**
     * @notice Register the caller with Bitsave and deploy a per-user ChildBitsave contract
     * @dev If the caller is already registered the existing child contract address is returned.
     *      The function is payable to allow a join fee (`JoinLimitFee`) to be sent if configured.
     * @return address The address of the caller's ChildBitsave contract
     */
    function joinBitsave() public payable returns (address) {
        address ownerAddress = msg.sender;
        address currAddr = addressToUserBS[ownerAddress];
        if (currAddr != address(0)) {
            return currAddr;
        }
        if (msg.value < JoinLimitFee) {
            revert BitsaveHelperLib.AmountNotEnough();
        }
        // deploy child contract for user
        address userBSAddress = address(
            new ChildBitsave(msg.sender, address(stableCoin))
        );
        addressToUserBS[ownerAddress] = userBSAddress;
        userCount += 1;
        emit BitsaveHelperLib.JoinedBitsave(ownerAddress);
        return userBSAddress;
    }

    /**
     * @notice Returns the caller's child contract address
     * @return address The child contract address associated with msg.sender, or address(0)
     *         if the caller is not registered
     */
    function getUserChildContractAddress() public view returns (address) {
        return addressToUserBS[msg.sender];
    }

    /**
     * @notice Retrieve stablecoin held by the child contract and return success
     * @dev This function is intended to be called only by a registered child contract
     *      via the `fromABitsaveChildOnly` modifier. It attempts to retrieve `amount`
     *      of `stableCoin` from the child and returns the result of the helper call.
     * @param originalToken Address of the token the owner expects (not used in current impl.)
     * @param amount Amount to retrieve (in stablecoin decimals)
     * @param ownerAddress Owner address whose child contract is calling
     * @return bool True on success
     */
    function sendAsOriginalToken(
        address originalToken,
        uint256 amount,
        address ownerAddress
    )
        public
        payable
        fromABitsaveChildOnly(ownerAddress)
        nonReentrant
        returns (bool)
    {
        // check amount sent
        // if (amount < poolFee) revert BitsaveHelperLib.AmountNotEnough();
        // retrieve stable coin used from owner address
        return
            BitsaveHelperLib.retrieveToken(
                msg.sender,
                address(stableCoin),
                amount
            );
        // convert to original token using crossChainSwap()
        // crossChainSwap(
        //     stableCoin,
        //     originalToken,
        //     amount,
        //     ownerAddress // send to owner address directly
        // );
    }

    /// Edit internal vault data
    /**
     * @notice Update internal vault parameters (admin only)
     * @dev Callable only by `masterAddress` via the `inhouseOnly` modifier.
     * @param _newCurrentVaultState New vault state numerical value used in calculations
     * @param _newTotalValueLocked New total value locked used by the protocol
     * @param _newCsToken Optional new address for the `csToken` (use address(0) to skip)
     */
    function editInternalData(
        uint256 _newCurrentVaultState,
        uint256 _newTotalValueLocked,
        address _newCsToken
    ) public inhouseOnly {
        currentVaultState = _newCurrentVaultState;
        currentTotalValueLocked = _newTotalValueLocked;
        if (_newCsToken != address(0)) {
            csToken = IERC20(_newCsToken);
        }
    }

    /// Edit internal stablecoin data
    /**
     * @notice Update the stablecoin used by the protocol (admin only)
     * @dev Callable only by `masterAddress`. Passing `address(0)` is ignored.
     * @param _newStableCoin Address of the new stablecoin ERC-20 contract
     */
    function editStableCoin(address _newStableCoin) public inhouseOnly {
        if (_newStableCoin != address(0)) {
            stableCoin = IERC20(_newStableCoin);
        }
    }

    /// Edit internal vault data
    /**
     * @notice Update protocol fees and related derived values (admin only)
     * @dev Updates `JoinLimitFee`, `SavingFee`, and `ChildCutPerFee`. Recomputes
     *      `ChildContractGasFee` unless `_childCutPerFee` is zero.
     * @param _joinFee Minimum join fee in wei (or token smallest unit)
     * @param _savingFee Fee required when creating a saving (in native wei)
     * @param _childCutPerFee Divider used to compute child gas fee share
     */
    function editFees(
        uint256 _joinFee,
        uint256 _savingFee,
        uint256 _childCutPerFee
    ) public inhouseOnly {
        JoinLimitFee = _joinFee;
        SavingFee = _savingFee;
        ChildCutPerFee = _childCutPerFee;
        // if childCutPerFee == 0, ChildContractGasFee == 0
        ChildContractGasFee = (_childCutPerFee == 0)
            ? 0
            : _savingFee / _childCutPerFee;
    }

    /**
     * @notice Drain any excess funds or tokens above the configured `fountain` reserve
     * @dev Admin-only. If `token` is address(0) native currency is drained; otherwise
     *      the token balance is transferred to `masterAddress`.
     * @param token Address of token to drip, or address(0) for native
     */
    function dripFountain(address token) public inhouseOnly nonReentrant {
        if (token == address(0)) {
            uint256 balance = address(this).balance;
            // send balance - fountain to masterAddress
            uint256 drip = 0;
            if (balance > fountain) {
                drip = balance - fountain;
                (bool ok, ) = masterAddress.call{value: drip}("");
                require(ok, "transfer failed");
            }
            emit BitsaveHelperLib.SystemFaucetDrip(token, drip);
            return;
        }
        uint256 tokenBalance = BitsaveHelperLib.tokenBalance(token);
        BitsaveHelperLib.transferToken(token, masterAddress, tokenBalance);
        emit BitsaveHelperLib.SystemFaucetDrip(token, tokenBalance);
    }

    /**
     * @dev Internal helper to handle native vs ERC-20 saving flows. If `tokenToSave`
     *      is an ERC-20 address it will attempt to retrieve tokens via the helper
     *      library and approve the child contract; otherwise it computes value from
     *      `msg.value` minus the provided `nativeFee`.
     * @param amount Amount intended to save (ignored for native flow)
     * @param tokenToSave Token address to save, or address(0) for native
     * @param userChildContractAddress Address of the user's child contract to approve
     * @param nativeFee Fee to deduct from native flows
     * @return uint256 The actual amount retrieved or computed for saving
     */
    function handleNativeSaving(
        uint256 amount,
        address tokenToSave,
        address userChildContractAddress,
        uint256 nativeFee
    ) private returns (uint256) {
        // check if native currency saving
        if (tokenToSave != address(0)) {
            // savingToken = tokenToSave;
            // amountToSave = amount;
            // perform withdrawal respective
            bool tokenHasBeenWithdrawn = BitsaveHelperLib.retrieveToken(
                msg.sender,
                tokenToSave,
                amount
            );
            if (!tokenHasBeenWithdrawn) {
                revert BitsaveHelperLib.CanNotWithdrawToken(tokenToSave);
            }
            // let us know you've removed the savings
            emit BitsaveHelperLib.TokenWithdrawal(
                msg.sender,
                address(this),
                amount
            );
            // approve child contract withdrawing token
            require(
                BitsaveHelperLib.approveAmount(
                    userChildContractAddress,
                    amount,
                    tokenToSave
                ),
                "Savings invalid"
            );
        } else {
            amount = msg.value - nativeFee;
        }
        return amount;
    }

    /**
     * @notice Create a new saving entry for the caller by forwarding to their child contract
     * @dev Caller must be registered (have a child contract). For native savings the
     *      call must include at least `SavingFee` in `msg.value` and the saved amount
     *      is taken from `msg.value - SavingFee`. For ERC-20 savings the caller must
     *      have previously authorized retrieval via the helper library (e.g., `approve`).
     * @param nameOfSaving Human-readable name for the saving slot
     * @param maturityTime UNIX timestamp when maturity occurs
     * @param penaltyPercentage Penalty percentage applied on early withdrawal
     * @param safeMode If true, attempt a safe conversion flow (not supported currently)
     * @param tokenToSave Token address to save, or address(0) for native coin
     * @param amount Amount to save (for ERC-20 flows). Ignored for native flows.
     */
    function createSaving(
        string memory nameOfSaving,
        uint256 maturityTime,
        uint8 penaltyPercentage,
        bool safeMode,
        address tokenToSave, // address 0 for native coin
        uint256 amount // discarded for native token; takes msg.value - SavingFee instead
    ) public payable registeredOnly(msg.sender) {
        if (msg.value < SavingFee) {
            revert BitsaveHelperLib.NotEnoughToPayGasFee();
        }

        if (block.timestamp > maturityTime) {
            revert BitsaveHelperLib.InvalidTime();
        }

        // NOTE: For now, no safeMode since no swap contract
        if (safeMode) {
            revert BitsaveHelperLib.NotSupported("No safe mode yet!");
        }

        // user's child contract address
        address payable userChildContractAddress = getUserChildContractAddress(
            msg.sender
        );

        // Handle token sent
        uint256 amountRetrieved = handleNativeSaving(
            amount,
            tokenToSave,
            userChildContractAddress,
            SavingFee
        );

        // TODO:  perform conversion for stableCoin
        // functionality for safe mode
        // if (safeMode) {
        //     amountToSave = crossChainSwap(
        //         savingToken,
        //         stableCoin,
        //         amount,
        //         address(this)
        //     );
        //     savingToken = stableCoin;
        // }

        /// send savings request to child contract with a little gas
        // Initialize user's child contract
        ChildBitsave userChildContract = ChildBitsave(userChildContractAddress);

        userChildContract.createSaving{
            value: tokenToSave == address(0) ? amountRetrieved : 0
        }(
            nameOfSaving,
            maturityTime,
            block.timestamp, // current time
            penaltyPercentage,
            tokenToSave,
            amountRetrieved,
            safeMode,
            currentVaultState,
            currentTotalValueLocked
        );

        // emit saving created
        emit BitsaveHelperLib.SavingCreated(
            nameOfSaving,
            amountRetrieved,
            tokenToSave
        );
    }

    ///
    /// INCREMENT SAVING
    ///    the amount to add to saving
    ///
    ///    string nameOfSaving
    ///
    /**
     * @notice Add funds to an existing saving slot
     * @dev Caller must be registered. For native savings, send value as `msg.value`.
     *      For ERC-20 flows, the child contract must be approved to withdraw the tokens
     *      (the helper library is used to do approvals/withdrawals).
     * @param nameOfSavings Name of the saving slot to increment
     * @param tokenToRetrieve Token address used to fund this increment (may be stablecoin)
     * @param amount Amount to add (ignored for native where `msg.value` is used)
     */
    function incrementSaving(
        string memory nameOfSavings,
        address tokenToRetrieve,
        uint256 amount
    ) public payable registeredOnly(msg.sender) {
        // initialize userChildContract
        address payable userChildContractAddress = payable(
            addressToUserBS[msg.sender]
        );
        ChildBitsave userChildContract = ChildBitsave(userChildContractAddress);

        address savingToken = userChildContract.getSavingTokenId(nameOfSavings);
        bool isNativeToken = savingToken == address(0);
        // todo: perform amount conversion and everything
        uint256 savingPlusAmount = amount;
        // todo: check savings detail by reading the storage of userChildContract
        bool isSafeMode = userChildContract.getSavingMode(nameOfSavings);
        if (isSafeMode) {
            // savingPlusAmount = crossChainSwap(
            //     userChildContract.getSavingTokenId(nameOfSavings),
            //     stableCoin,
            //     savingPlusAmount,
            //     address(this)
            // );
            tokenToRetrieve = address(stableCoin);
        }
        if (!isNativeToken) {
            // approve child contract withdrawing token
            require(
                BitsaveHelperLib.approveAmount(
                    userChildContractAddress,
                    savingPlusAmount,
                    tokenToRetrieve
                ),
                "Savings invalid"
            );
        } else {
            savingPlusAmount = msg.value;
        }

        uint256 amountRetrieved = handleNativeSaving(
            amount,
            savingToken,
            userChildContractAddress,
            0 // inc has no fee
        );

        userChildContract.incrementSaving{
            value: isNativeToken ? amountRetrieved : 0
        }(
            nameOfSavings,
            amountRetrieved,
            currentVaultState,
            currentTotalValueLocked
        );

        uint256 savingBalance = userChildContract.getSavingBalance(
            nameOfSavings
        );

        // emit saving updated
        emit BitsaveHelperLib.SavingIncremented(
            nameOfSavings,
            amount,
            savingBalance,
            tokenToRetrieve
        );
    }

    /// WITHDRAW savings
    ///
    ///    string nameOfSaving
    ///
    /**
     * @notice Withdraw a saving slot (for the caller)
     * @dev Forwards the withdraw request to the caller's child contract. Caller must
     *      be registered. Emits `SavingWithdrawn` via helper library events.
     * @param nameOfSavings Name of the saving slot to withdraw
     * @return bool True on success
     */
    function withdrawSaving(
        string memory nameOfSavings
    ) public registeredOnly(msg.sender) returns (bool) {
        // initialize user's child userChildContract
        ChildBitsave userChildContract = ChildBitsave(
            payable(addressToUserBS[msg.sender])
        );
        // call withdraw savings fn
        userChildContract.withdrawSaving(nameOfSavings);
        emit BitsaveHelperLib.SavingWithdrawn(nameOfSavings);
        return true;
    }

    receive() external payable {}

    // ---------- Private functions ---------------
    /**
     * @dev Internal helper overload: returns the child contract address for `myAddress`.
     * @param myAddress The account whose child contract we want
     * @return address payable Child contract address (or address(0) if not registered)
     */
    function getUserChildContractAddress(
        address myAddress
    ) internal view returns (address payable) {
        return payable(addressToUserBS[myAddress]);
    }
}
