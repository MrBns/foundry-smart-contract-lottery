// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.t.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256 subId, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address adminAccount = helperConfig.getConfig().adminAccount;

        (subId,) = createSubscription(vrfCoordinator, adminAccount);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address adminAccount) public returns (uint256 subId, address) {
        console.log("creating subscription for chain id  -> ", block.chainid);

        vm.startBroadcast(adminAccount);
        subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("created subscription id is :", subId);
        console.log("please update the subscription id to your config.");
        return (subId, vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3e18; // 3 LINK ToKEN;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address adminAccount = helperConfig.getConfig().adminAccount;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, adminAccount);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address adminAccount)
        public
    {
        console.log("Funding Subscription: ", subscriptionId);
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(adminAccount);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address adminAccount = helperConfig.getConfig().adminAccount;

        addConsumer(mostRecentDeployed, vrfCoordinator, subId, adminAccount);
    }

    function addConsumer(address contractToAddVrf, address vrfCoordinator, uint256 subId, address adminAccount) public {
        console.log("Adding Consumer : ", contractToAddVrf);
        console.log("To Coordinator : ", vrfCoordinator);
        console.log("On Chain Id : ", block.chainid);

        vm.startBroadcast(adminAccount);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentDeployedRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployedRaffle);
    }
}
