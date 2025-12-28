// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "forge-std/console.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle raffle;
    HelperConfig helperConfig;

    // contract required vars
    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public immutable PLAYER1 = makeAddr("player-1");
    address public immutable PLAYER2 = makeAddr("player-2");
    uint256 public constant PLAYERS_STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle raffleDeployer = new DeployRaffle();

        (raffle, helperConfig) = raffleDeployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entraceFee = config.entraceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        // dealing.
        vm.deal(PLAYER1, PLAYERS_STARTING_BALANCE);
        vm.deal(PLAYER2, PLAYERS_STARTING_BALANCE);
    }

    function testRaffleInitializeInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                                 ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER1);
        // act /  assets
        vm.expectRevert(Raffle.Raffle_SendMoreToEnterRffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER1);

        raffle.enterRaffle{value: entraceFee}();

        address playerRecoreded = raffle.getPlayer(0);
        assert(playerRecoreded == PLAYER1);
    }

    function testEnteringraffleEmitsEvent() public {
        // arrange
        vm.prank(PLAYER1);

        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(PLAYER1);

        // assets
        raffle.enterRaffle{value: entraceFee}();
    }

    function test_DontAllowPlayersToEnterWhileRaflleIsCalculating() external {
        // arrage
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entraceFee}();

        // Set timestamp and block once - applies to performUpKeep and its internal calls
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpKeep("");

        vm.prank(PLAYER1);
        vm.expectRevert(Raffle.Raffle_RaffleIsNOtOpen.selector);
        raffle.enterRaffle{value: entraceFee}();

        // asserts
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEPS
    //////////////////////////////////////////////////////////////*/

    function test_checkUpKeepRevertIfItHasNoBalance() external {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act  / Assert
        (bool upKeepNeeded,) = raffle.checkUpKeep("");
        assert(upKeepNeeded == false);
    }

    function test_checkUpKeepRevertIfRaffleIsNotOpen() external {
        // arrage
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpKeep(""); // will pick winner and make the raffle Calculating;

        // act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");

        // assert
        assert(!upKeepNeeded);
    }

    function test_checkUpKeepsReturnsTrueIfParametersGood() external {
        // arrage
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entraceFee}();

        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entraceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");

        // assert
        assert(upKeepNeeded == true);
    }

    /*//////////////////////////////////////////////////////////////
                            PERFORM UPKEEPS
    //////////////////////////////////////////////////////////////*/

    function test_PerformUpkeepCanOnlyRunIfCheckUpKeepsIsTrue() external {
        // Arrange
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 2);

        // act / assert
        // assert if any error happened.
        raffle.performUpKeep("");
    }

    function test_peformUpKeepRevertIfCheckUpkeepIsFalse() external {
        // arrange
        uint256 currentBalance = 0;
        uint256 currentPlayer = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // act / assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_CannotPerformUpKeep.selector, currentBalance, currentPlayer, raffleState
            )
        );
        raffle.performUpKeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER1);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function test_performUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        //  arrange
        // arranged via modifier;

        // act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(uint256(requestId) > 0);
    }

    /*//////////////////////////////////////////////////////////////
                         FULLFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    modifier onlyLocal() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function test_fullfillrandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId)
        public
        raffleEntered
        onlyLocal
    {
        // arrange / act / asserts
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function test_fullfilRandomWordsPickAWinnerAndSendMoney() public raffleEntered onlyLocal {
        //arrange
        uint8 additionalEntrance = 3; // 4 players;
        address expectedWinner = address(1);

        // entering 3 player into raffle.
        for (uint160 i = 1; i <= additionalEntrance; i++) {
            address newPlayer = address(i);
            hoax(newPlayer, 10 ether);
            raffle.enterRaffle{value: entraceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 expectedWinnerStartingBalance = expectedWinner.balance;

        // ACT
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        bytes32 requestId = recordedLogs[1].topics[1];
        console.logBytes32(requestId);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prizeAmount = entraceFee * (additionalEntrance + 1); // 1 more enterred with modifier.

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == expectedWinnerStartingBalance + prizeAmount);
        assert(endingTimeStamp >= startingTimeStamp);
    }
}

