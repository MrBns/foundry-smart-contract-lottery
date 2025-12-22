// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    // contract required vars
    uint256 entraceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public immutable I_PLAYER1 = makeAddr("player-1");
    address public immutable I_PLAYER2 = makeAddr("player-2");
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
        vm.deal(I_PLAYER1, PLAYERS_STARTING_BALANCE);
        vm.deal(I_PLAYER2, PLAYERS_STARTING_BALANCE);
    }

    function testRaffleInitializeInOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                                 ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertWhenYouDontPayEnough() public {
        // arrange
        vm.prank(I_PLAYER1);
        // act /  assets
        vm.expectRevert(Raffle.Raffle_SendMoreToEnterRffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(I_PLAYER1);

        raffle.enterRaffle{value: entraceFee}();

        address playerRecoreded = raffle.getPlayer(0);
        assert(playerRecoreded == I_PLAYER1);
    }

    function testEnteringraffleEmitsEvent() public {
        // arrange
        vm.prank(I_PLAYER1);

        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(I_PLAYER1);

        // assets
        raffle.enterRaffle{value: entraceFee}();
    }

    function test_DontAllowPlayersToEnterWhileRaflleIsCalculating() external {
        // arrage
        vm.prank(I_PLAYER1);
        raffle.enterRaffle{value: entraceFee}();

        // Set timestamp and block once - applies to performUpKeep and its internal calls
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpKeep("");

        vm.prank(I_PLAYER1);
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
        vm.prank(I_PLAYER1);
        raffle.enterRaffle{value: entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpKeep(""); // will pick winner and make the raffle Calculating;

        // act
        (bool upKeepNeeded,) = raffle.checkUpKeep("");

        // assert
        assert(!upKeepNeeded);
    }
}

