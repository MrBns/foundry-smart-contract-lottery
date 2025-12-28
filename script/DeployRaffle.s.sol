// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployRaffle is Script {
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription subscriptionCreator = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                subscriptionCreator.createSubscription(config.vrfCoordinator, config.adminAccount);

            // Fund it
            FundSubscription fundSubscription = new FundSubscription();

            fundSubscription.fundSubscription(
                config.vrfCoordinator, config.subscriptionId, config.link, config.adminAccount
            );
        }

        vm.startBroadcast(config.adminAccount);
        Raffle raffle = new Raffle(
            config.entraceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            uint32(config.callbackGasLimit)
        );

        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // add consumer use broadcast.
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.adminAccount);

        // after all updating network=>config  map
        helperConfig.setConfig(block.chainid, config);

        return (raffle, helperConfig);
    }

    function run() external {
        deployContract();
    }
}
