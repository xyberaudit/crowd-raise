// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./libraries/PriceConverter.sol";

error CrowdRaise__NoFund();
error CrowdRaise__GoalMet();
error CrowdRaise__NotOwner();
error CrowdRaise__RefundFailed();
error CrowdRaise__GoalNotReached();
error CrowdRaise__WithdrawFailed();
error CrowdRaise__DeadlineNotReached();

contract CrowdRaise {
    using PriceConverter for uint256;

    mapping(address => uint256) private s_addressToAmountFunded;

    address[] private s_funders;
    uint256 private s_totalFunded;
    address private immutable i_owner;
    uint256 private immutable i_usdGoal;
    uint256 private immutable i_deadline;
    AggregatorV3Interface private s_priceFeed;

    uint256 public constant MINIMUM_USD = 5 * 10 ** 18;
    uint256 public constant SECOND_TO_DAY = 24 * 60 * 60;

    event Funded(address indexed funder, uint256 amount);
    event Refunded(address indexed funder, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);

    constructor(address priceFeed, uint256 goalUsdAmount, uint256 durationInDays) {
        require(goalUsdAmount >= 100 * 10 ** 18);
        require(goalUsdAmount <= 1_000_000 * 10 ** 18);
        i_owner = msg.sender;
        i_usdGoal = goalUsdAmount;
        i_deadline = block.timestamp + (durationInDays * SECOND_TO_DAY);
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert CrowdRaise__NotOwner();
        _;
    }

    function fund() public payable {
        require(block.timestamp <= i_deadline, "Deadline passed!");
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "You need more ETH!");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_totalFunded += msg.value;
        s_funders.push(msg.sender);

        emit Funded(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        uint256 funding = PriceConverter.getConversionRate(s_totalFunded, s_priceFeed);
        require(block.timestamp > i_deadline, CrowdRaise__DeadlineNotReached());
        if (funding <= i_usdGoal) {
            revert CrowdRaise__GoalNotReached();
        }

        uint256 numFunders = s_funders.length;
        for (uint256 i = 0; i < numFunders; i++) {
            address funder = s_funders[i];
            s_addressToAmountFunded[funder] = 0;
        }
        delete s_funders;

        uint256 totalFund = address(this).balance;
        (bool success,) = i_owner.call{value: totalFund}("");
        if (!success) revert CrowdRaise__WithdrawFailed();

        emit Withdrawn(i_owner, totalFund);
    }

    function refund() public {
        uint256 funding = PriceConverter.getConversionRate(s_totalFunded, s_priceFeed);
        require(block.timestamp > i_deadline, CrowdRaise__DeadlineNotReached());
        require(funding < i_usdGoal, CrowdRaise__GoalMet());
        if (s_addressToAmountFunded[msg.sender] == 0) revert CrowdRaise__NoFund();

        uint256 fundAmount = s_addressToAmountFunded[msg.sender];
        s_addressToAmountFunded[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: fundAmount}("");
        if (!success) revert CrowdRaise__RefundFailed();

        emit Refunded(msg.sender, fundAmount);
    }

    /* ==================================================================================
     *     GETTER FUNCTION
     * ================================================================================== */

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getDeadline() external view returns (uint256) {
        return i_deadline;
    }

    function getTotalFund() external view returns (uint256) {
        return s_totalFunded;
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunderCount() external view returns (uint256) {
        return s_funders.length;
    }
}
