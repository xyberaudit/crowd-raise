// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployCrowdRaise} from "../../script/DeployCrowdRaise.s.sol";
import {CrowdRaise} from "../../src/CrowdRaise.sol";
import {Test, console} from "forge-std/Test.sol";

contract CrowdRaiseTest is Test {
    CrowdRaise crowdRaise;

    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant USD_GOAL = 1000e18;
    uint256 public constant DAYS = 7;

    uint160 public constant USER_NUMBER = 11; // Random user
    uint160 public constant OWNER_NUMBER = 46; // Custom owner
    address public constant USER = address(USER_NUMBER);
    address public constant OWNER = address(OWNER_NUMBER);

    modifier funded() {
        vm.prank(USER);
        crowdRaise.fund{value: SEND_VALUE}();
        _;
    }

    function setUp() external {
        DeployCrowdRaise deployCrowdRaise = new DeployCrowdRaise();
        crowdRaise = deployCrowdRaise.run(OWNER, USD_GOAL, DAYS);
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(OWNER, STARTING_BALANCE);
    }

    /* ==================================================================================
     *     FUND TEST
     * ================================================================================== */

    function testMinimumFundIsFiveUsd() public view {
        assertEq(crowdRaise.MINIMUM_USD(), 5e18);
    }

    function testCantFundLessThanFiveUsd() public {
        vm.expectRevert();
        crowdRaise.fund();
    }

    function testCantFundAfterDeadline() public {
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(USER);
        vm.expectRevert();
        crowdRaise.fund();
    }

    function testFundUpdatesFundAmount() public funded {
        uint256 fundAmount = crowdRaise.getAddressToAmountFunded(USER);
        assertEq(fundAmount, SEND_VALUE);
    }

    function testFundUpdatesFunderArray() public funded {
        address funder = crowdRaise.getFunder(0);
        assertEq(funder, USER);
    }

    function testMultipleFundsUpdateTotalFund() public {
        uint160 numberOfFunders = 5;
        uint160 startingFunderIndex = 1;
        uint256 fundAmount = 0;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            console.log(fundAmount, crowdRaise.getTotalFund());
            hoax(address(i), STARTING_BALANCE);
            crowdRaise.fund{value: SEND_VALUE}();
            fundAmount += SEND_VALUE;
        }
        assertEq(fundAmount, crowdRaise.getTotalFund());
    }

    /* ==================================================================================
     *     WITHDRAW TEST
     * ================================================================================== */

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(address(1));
        vm.expectRevert();
        crowdRaise.withdraw();
    }

    function testCantWithdrawBeforeDeadline() public funded {
        vm.warp(crowdRaise.getDeadline() - 1);
        vm.prank(crowdRaise.getOwner());
        vm.expectRevert();
        crowdRaise.withdraw();
    }

    function testWithdrawFailsGoalNotMet() public funded {
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(crowdRaise.getOwner());
        vm.expectRevert();
        crowdRaise.withdraw();
    }

    function testWithdrawSuccessAfterDeadline() public {
        address owner = crowdRaise.getOwner();
        uint256 numberOfFunders = 4;
        console.log(owner.balance);

        // Fund contract with dummy address
        for (uint160 i = 1; i < numberOfFunders + 1; i++) {
            vm.deal(address(i), STARTING_BALANCE);
            vm.prank(address(i));
            crowdRaise.fund{value: 10e18}();
        }

        vm.warp(crowdRaise.getDeadline() + 1);
        assertEq(address(crowdRaise).balance, 40 ether);
        uint256 balanceBefore = owner.balance;
        console.log(balanceBefore);

        vm.prank(owner);
        crowdRaise.withdraw();
        uint256 balanceAfter = owner.balance;
        console.log(owner.balance);
        console.log(balanceAfter);

        assertEq(balanceAfter - balanceBefore, 40 ether);
        assertEq(address(crowdRaise).balance, 0);
        assertEq(crowdRaise.getFunderCount(), 0);
    }

    /* ==================================================================================
     *     REFUND TEST
     * ================================================================================== */
}
