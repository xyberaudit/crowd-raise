// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CrowdRaise} from "../src/CrowdRaise.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployCrowdRaise is Script {
    function run(address owner, uint256 usdGoalAmount, uint256 deadlineInDays) external returns (CrowdRaise) {
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        vm.startBroadcast(owner);
        CrowdRaise crowdRaise = new CrowdRaise(ethUsdPriceFeed, usdGoalAmount, deadlineInDays);
        vm.stopBroadcast();
        return crowdRaise;
    }
}
