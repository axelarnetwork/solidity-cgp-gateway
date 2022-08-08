// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IAxelarAuthWeighted } from '../interfaces/IAxelarAuthWeighted.sol';
import { ECDSA } from '../ECDSA.sol';
import { Ownable } from '../Ownable.sol';

contract AxelarAuthWeighted is Ownable, IAxelarAuthWeighted {
    uint256 public currentEpoch;
    mapping(uint256 => bytes32) public hashForEpoch;
    mapping(bytes32 => uint256) public epochForHash;

    // solhint-disable-next-line var-name-mixedcase
    uint256 internal immutable OLD_KEY_RETENTION = 16;

    constructor(bytes[] memory recentOperators) {
        uint256 length = recentOperators.length;

        for (uint256 i; i != length; ) {
            _transferOperatorship(recentOperators[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**************************\
    |* External Functionality *|
    \**************************/

    function validateProof(bytes32 messageHash, bytes calldata proof) external view returns (bool) {
        (address[] memory operators, uint256[] memory weights, uint256 threshold, bytes[] memory signatures) = abi.decode(
            proof,
            (address[], uint256[], uint256, bytes[])
        );

        bytes32 operatorsHash = keccak256(abi.encode(operators, weights, threshold));
        uint256 operatorsEpoch = epochForHash[operatorsHash];
        uint256 epoch = currentEpoch;

        if (operatorsEpoch == 0 || epoch - operatorsEpoch >= OLD_KEY_RETENTION) revert InvalidOperators();

        _validateSignatures(messageHash, operators, weights, threshold, signatures);

        // Returns true for the current operators
        return operatorsEpoch == epoch;
    }

    /***********************\
    |* Owner Functionality *|
    \***********************/

    function transferOperatorship(bytes calldata params) external onlyOwner {
        _transferOperatorship(params);
    }

    /**************************\
    |* Internal Functionality *|
    \**************************/

    function _transferOperatorship(bytes memory params) internal {
        (address[] memory newOperators, uint256[] memory newWeights, uint256 newThreshold) = abi.decode(
            params,
            (address[], uint256[], uint256)
        );
        uint256 operatorsLength = newOperators.length;
        uint256 weightsLength = newWeights.length;

        // operators must be sorted binary or alphabetically in lower case
        if (operatorsLength == 0 || !_isSortedAscAndContainsNoDuplicate(newOperators)) revert InvalidOperators();

        if (weightsLength != operatorsLength) revert InvalidWeights();

        uint256 totalWeight;
        for (uint256 i; i != weightsLength; ) {
            totalWeight = totalWeight + newWeights[i];
            unchecked {
                ++i;
            }
        }
        if (newThreshold == 0 || totalWeight < newThreshold) revert InvalidThreshold();

        bytes32 newOperatorsHash = keccak256(params);

        if (epochForHash[newOperatorsHash] != 0) revert SameOperators();

        uint256 epoch = currentEpoch + 1;
        currentEpoch = epoch;
        hashForEpoch[epoch] = newOperatorsHash;
        epochForHash[newOperatorsHash] = epoch;

        emit OperatorshipTransferred(newOperators, newWeights, newThreshold);
    }

    function _validateSignatures(
        bytes32 messageHash,
        address[] memory operators,
        uint256[] memory weights,
        uint256 threshold,
        bytes[] memory signatures
    ) internal pure {
        uint256 operatorsLength = operators.length;
        uint256 signaturesLength = signatures.length;
        uint256 operatorIndex;
        uint256 weight;
        // looking for signers within operators
        // assuming that both operators and signatures are sorted
        for (uint256 i; i != signaturesLength; ) {
            address signer = ECDSA.recover(messageHash, signatures[i]);
            // looping through remaining operators to find a match
            for (; operatorIndex != operatorsLength && signer != operators[operatorIndex]; ) {
                unchecked {
                    ++operatorIndex;
                }
            }
            // checking if we are out of operators
            if (operatorIndex == operatorsLength) revert MalformedSigners();
            // accumulating signatures weight
            weight = weight + weights[operatorIndex];
            // weight needs to reach or surpass threshold
            if (weight >= threshold) return;
            // increasing operators index if match was found
            unchecked {
                ++operatorIndex;
                ++i;
            }
        }
        // if weight sum below threshold
        revert LowSignaturesWeight();
    }

    function _isSortedAscAndContainsNoDuplicate(address[] memory accounts) internal pure returns (bool) {
        address prevAccount;
        address account = accounts[0];

        if (account == address(0)) return false;

        for (uint256 i = 1; i != accounts.length; ) {
            prevAccount = account;
            account = accounts[i];

            if (prevAccount >= account) {
                return false;
            }

            unchecked {
                ++i;
            }
        }

        return true;
    }
}
