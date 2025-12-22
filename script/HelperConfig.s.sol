// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.t.sol";

error Helper_InvalidChainId(uint256 chainId);

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 4e15;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 entraceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert Helper_InvalidChainId(block.chainid);
        }
    }

    function getConfig() external view returns (NetworkConfig memory) {
        return networkConfigs[block.chainid];
    }

    function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entraceFee: 0.01 ether, // 1e16
            interval: 30, // 30 second
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9, // 200 gwei gas lane
            callbackGasLimit: 500000, // 500,000 Gas
            subscriptionId: 44135039354861124983076855627344573027802306496650106722819102975921481776972,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // VRFCoordinatorV2_5Mock vrfCordinator = new VRFCoordinatorV2_5Mock(200, )
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        return NetworkConfig({
            entraceFee: 0.01 ether, // 1e16
            interval: 30 seconds, // 30 second
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9, // 200 gwei gas lane
            callbackGasLimit: 500000, // 500,000 Gas
            subscriptionId: 0,
            link: address(linkToken)
        });
    }
}

