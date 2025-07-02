// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CrowdRaise} from "../src/CrowdRaise.sol";

contract CrowdRaiseInteraction is Script {
    function fundCrowdRaise(address crowdRaiseAddress, address funder, uint256 amount) public {
        CrowdRaise crowdRaise = CrowdRaise(crowdRaiseAddress);
        vm.startBroadcast(funder);
        crowdRaise.fund{value: amount}();
        vm.stopBroadcast();
    }
}

contract WithdrawCrowdRaise is Script {
    function withdrawCrowdRaise(address crowdRaiseAddress, address owner) public {
        CrowdRaise crowdRaise = CrowdRaise(crowdRaiseAddress);
        vm.startBroadcast(owner);
        crowdRaise.withdraw();
        vm.stopBroadcast();
    }
}

contract RefundCrowdRaise is Script {
    function refundCrowdRaise(address crowdRaiseAddress, address funder) public {
        CrowdRaise crowdRaise = CrowdRaise(crowdRaiseAddress);
        vm.startBroadcast(funder);
        crowdRaise.refund();
        vm.stopBroadcast();
    }
}
