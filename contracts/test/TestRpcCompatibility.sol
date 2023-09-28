// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract RpcCompatibility {
    uint256 private value;

    event ValueUpdated(uint256 indexed value);

    constructor(uint256 initialValue) {
        value = initialValue;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function updateValue(uint256 newValue) external {
        value = newValue;
        emit ValueUpdated(newValue);
    }
}