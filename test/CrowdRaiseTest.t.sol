// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CrowdRaise} from "../src/CrowdRaise.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployCrowdRaise} from "../script/DeployCrowdRaise.s.sol";

contract CrowdRaiseTest is Test {
    CrowdRaise crowdRaise;

    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 public constant ETH_TO_MEET_GOAL = 0.4 ether;
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant USD_GOAL = 1000e18;
    uint256 public constant DAYS = 7;

    address public USER = makeAddr("user");
    address public OWNER = makeAddr("owner");

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

    function testFundFailsfterDeadline() public {
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
        uint256 numberOfFunders = 3;

        // Fund contract with dummy address
        for (uint160 i = 0; i < numberOfFunders; i++) {
            vm.deal(address(i + 1), STARTING_BALANCE);
            vm.prank(address(i + 1));
            crowdRaise.fund{value: ETH_TO_MEET_GOAL}();
        }

        vm.warp(crowdRaise.getDeadline() + 1);
        uint256 balanceBefore = owner.balance;
        vm.prank(owner);
        crowdRaise.withdraw();
        uint256 balanceAfter = owner.balance;

        assertEq(balanceAfter - balanceBefore, ETH_TO_MEET_GOAL * numberOfFunders);
        assertEq(address(crowdRaise).balance, 0);
        assertEq(crowdRaise.getFunderCount(), 0);
    }

    /* ==================================================================================
     *     REFUND TEST
     * ================================================================================== */

    function testRefundFailsBeforeDeadline() public funded {
        vm.prank(USER);
        vm.expectRevert();
        crowdRaise.refund();
    }

    function testRefundFailsGoalMet() public {
        vm.prank(USER);
        crowdRaise.fund{value: ETH_TO_MEET_GOAL}();
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(USER);
        vm.expectRevert();
        crowdRaise.refund();
    }

    function testRefundUpdatesUserBalance() public funded {
        vm.warp(crowdRaise.getDeadline() + 1);

        uint256 balanceBefore = USER.balance;
        vm.prank(USER);
        crowdRaise.refund();
        uint256 balanceAfter = USER.balance;

        assertEq(balanceAfter - balanceBefore, SEND_VALUE);
        assertEq(crowdRaise.getAddressToAmountFunded(USER), 0);
    }

    function testRefundFailsNeverFund() public {
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(USER);
        vm.expectRevert();
        crowdRaise.refund();
    }

    function testMultipleFundersRefund() public {
        uint256 numberOfFunders = 3;
        address[] memory funders = new address[](numberOfFunders);

        for (uint160 i = 0; i < numberOfFunders; i++) {
            funders[i] = address(i + 1);
            vm.deal(funders[i], STARTING_BALANCE);
        }

        for (uint160 i = 0; i < numberOfFunders; i++) {
            vm.deal(funders[i], STARTING_BALANCE);
            vm.prank(funders[i]);
            crowdRaise.fund{value: SEND_VALUE}();
        }

        vm.warp(crowdRaise.getDeadline() + 1);
        for (uint160 i = 0; i < numberOfFunders; i++) {
            uint256 balanceBefore = funders[i].balance;
            vm.prank(funders[i]);
            crowdRaise.refund();
            uint256 balanceAfter = address(i + 1).balance;

            assertEq(balanceAfter - balanceBefore, SEND_VALUE);
            assertEq(crowdRaise.getAddressToAmountFunded(funders[i]), 0);
        }
    }

    function testFundersCantRefundTwice() public funded {
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(USER);
        crowdRaise.refund();
        vm.prank(USER);
        vm.expectRevert();
        crowdRaise.refund();
    }

    function testContractBalanceReducedAfterRefund() public funded {
        uint256 balanceBefore = address(crowdRaise).balance;
        vm.warp(crowdRaise.getDeadline() + 1);
        vm.prank(USER);
        crowdRaise.refund();
        uint256 balanceAfter = address(crowdRaise).balance;
        assertEq(balanceBefore, SEND_VALUE);
        assertEq(balanceAfter, 0);
    }
}
