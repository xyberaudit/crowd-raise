// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrowdRaise} from "../src/CrowdRaise.sol";
import {DeployCrowdRaise} from "../script/DeployCrowdRaise.s.sol";
import {CrowdRaiseInteraction} from "../script/CrowdRaiseInteraction.s.sol";

contract CrowdRaiseIntegrationTest is Test {
    CrowdRaise crowdRaise;

    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant ETH_TO_MEET_GOAL = 0.4 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant USD_GOAL = 1000e18;
    uint256 public constant DAYS = 7;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");

    function setUp() external {
        DeployCrowdRaise deployCrowdRaise = new DeployCrowdRaise();
        crowdRaise = deployCrowdRaise.run(OWNER, USD_GOAL, DAYS);
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(OWNER, STARTING_BALANCE);
    }

    function intitialTest() public {}
}
