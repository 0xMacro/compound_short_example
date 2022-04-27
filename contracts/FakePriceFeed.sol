// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// A simple mock contract that we'll use to impersonate
// the Compound PriceFeed. We need this so we can simulate
// the price changing 
contract FakePriceFeed {

    mapping(address => uint256) public prices;

    function setUnderlyingPrice(address cToken, uint256 newPrice) external {
        prices[cToken] = newPrice;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint) {
        return prices[cToken];
    }
}