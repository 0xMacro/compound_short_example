// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface WETH {
    function deposit() external payable;

    function approve(address spencer, uint256 amount) external;
}
