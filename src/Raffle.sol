// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: SEE IN THE LICENSE
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A Sample Raffle Contract
 * @author Mr. Binary Sniper
 * @notice This contract is for creating sample rafle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle_SendMoreToEnterRffle();
    error Raffle_WinnerPaymentFailed();
    error Raffle_RaffleIsNOtOpen();
    error Raffle_NotPassedEnoughTimeToPickWinner(uint256 timeRemains);
    error Raffle_CannotPerformUpKeep(uint256 balance, uint256 playersCount, uint256 raffleState);

    /* Type Decleration */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* storage state */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant RANDOM_NUMBERS = 1;

    uint256 private immutable I_INTERVAL;
    uint256 private immutable I_ENTRANCE_FEE;
    bytes32 private immutable I_GASLANE_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;

    address payable[] private sPlayers;
    uint256 private sLastTimeStamp;
    address sRecentWinner;
    RaffleState sRaffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedPickWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 gasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_GASLANE_HASH = gasLane;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALLBACK_GAS_LIMIT = gasLimit;
        sRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle_SendMoreToEnterRffle();
        }

        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle_RaffleIsNOtOpen();
        }

        sPlayers.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev  this is the function that the chainlink nodes willc all to see
     * if lottery is ready to have a winner picked
     * the following should be true in order to upkeepNeeded To be true
     * 1. The time interval has passed between ralle runs.
     * 2. The Lottery is open
     * 3. Contract has Eth
     * 4. Implicitly,  Check subscription has LINK
     * @param -  checkData - ignored
     * @return upKeepNeeded - true if its the time to restart the lottery
     * @return
     */
    function checkUpKeep(
        bytes memory /* checkdata */
    )
        public
        view
        returns (
            bool upKeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = ((block.timestamp - sLastTimeStamp) > I_INTERVAL);
        bool isOpen = (sRaffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = sPlayers.length > 0;

        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayer;

        return (upKeepNeeded, "");
    }

    /**
     * @dev will pick winnder and called via chainlink automation.
     * @param -  performdata - ignored
     */
    function performUpKeep(
        bytes calldata /* performdata */
    )
        external
    {
        (bool upKeepNeeded,) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle_CannotPerformUpKeep(address(this).balance, sPlayers.length, uint256(sRaffleState));
        }
        _pickWinner();
    }

    // Pick winner internally
    //
    function _pickWinner() internal {
        if ((block.timestamp - sLastTimeStamp) < I_INTERVAL) {
            revert Raffle_NotPassedEnoughTimeToPickWinner(block.timestamp - sLastTimeStamp);
        }

        sRaffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_GASLANE_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: RANDOM_NUMBERS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        /* uint256 requestId = */
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedPickWinner(requestId);
    }

    //CEI: check effect interaction.
    function fulfillRandomWords(uint256, uint256[] calldata randomUints) internal override {
        uint256 indexOfWinner = randomUints[0] % sPlayers.length;

        address payable winner = sPlayers[indexOfWinner];
        sRecentWinner = winner;

        // after picking winner;
        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimeStamp = block.timestamp;

        emit WinnerPicked(winner);

        (bool isPaySuccess,) = winner.call{value: address(this).balance}("");
        if (!isPaySuccess) {
            revert Raffle_WinnerPaymentFailed();
        }
    }

    /* Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return sRaffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return sPlayers[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return sLastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return sRecentWinner;
    }
}
