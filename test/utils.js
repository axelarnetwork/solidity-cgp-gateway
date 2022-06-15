'use strict';

const {
    utils: { defaultAbiCoder, id, arrayify, keccak256 },
} = require('ethers');
const { sortBy } = require('lodash');

const getRandomInt = (max) => {
    return Math.floor(Math.random() * max);
};

const getAddresses = (wallets) => wallets.map(({ address }) => address);

const getSignaturesProof = async (data, operators, signers) => {
    const hash = arrayify(keccak256(data));
    const signatures = await Promise.all(
        sortBy(signers, (wallet) => wallet.address.toLowerCase()).map((wallet) => wallet.signMessage(hash)),
    );
    return defaultAbiCoder.encode(['address[]', 'bytes[]'], [getAddresses(operators), signatures]);
};

module.exports = {
    bigNumberToNumber: (bigNumber) => bigNumber.toNumber(),

    getSignaturesProof,

    getSignedMultisigExecuteInput: async (data, operators, signers) =>
        defaultAbiCoder.encode(['bytes', 'bytes'], [data, await getSignaturesProof(data, operators, signers)]),

    getRandomInt,

    getRandomID: () => id(getRandomInt(1e10).toString()),

    tickBlockTime: (provider, seconds) => provider.send('evm_increaseTime', [seconds]),

    getAuthDeployParam: (operatorsSets, operatorThresholds) =>
        arrayify(
            defaultAbiCoder.encode(
                ['bytes[]'],
                [operatorsSets.map((operators, i) => defaultAbiCoder.encode(['address[]', 'uint256'], [operators, operatorThresholds[i]]))],
            ),
        ),

    getMultisigProxyDeployParams: (admins, adminThreshold, operators, operatorThreshold) =>
        arrayify(
            defaultAbiCoder.encode(
                ['address[]', 'uint8', 'bytes'],
                [
                    admins,
                    adminThreshold,
                    operators.length ? defaultAbiCoder.encode(['address[]', 'uint256'], [operators, operatorThreshold]) : '0x',
                ],
            ),
        ),

    getDeployCommand: (name, symbol, decimals, cap, tokenAddress, dailyMintLimit) =>
        defaultAbiCoder.encode(
            ['string', 'string', 'uint8', 'uint256', 'address', 'uint256'],
            [name, symbol, decimals, cap, tokenAddress, dailyMintLimit],
        ),

    getMintCommand: (symbol, address, amount) => defaultAbiCoder.encode(['string', 'address', 'uint256'], [symbol, address, amount]),

    getBurnCommand: (symbol, salt) => defaultAbiCoder.encode(['string', 'bytes32'], [symbol, salt]),

    getTransferMultiOperatorshipCommand: (newOperators, threshold) =>
        defaultAbiCoder.encode(['address[]', 'uint256'], [sortBy(newOperators, (address) => address.toLowerCase()), threshold]),

    getApproveContractCall: (sourceChain, source, destination, payloadHash, sourceTxHash, sourceEventIndex) =>
        defaultAbiCoder.encode(
            ['string', 'string', 'address', 'bytes32', 'bytes32', 'uint256'],
            [sourceChain, source, destination, payloadHash, sourceTxHash, sourceEventIndex],
        ),

    getApproveContractCallWithMint: (sourceChain, source, destination, payloadHash, symbol, amount, sourceTxHash, sourceEventIndex) =>
        defaultAbiCoder.encode(
            ['string', 'string', 'address', 'bytes32', 'string', 'uint256', 'bytes32', 'uint256'],
            [sourceChain, source, destination, payloadHash, symbol, amount, sourceTxHash, sourceEventIndex],
        ),

    buildCommandBatch: (chianId, commandIDs, commandNames, commands) =>
        arrayify(defaultAbiCoder.encode(['uint256', 'bytes32[]', 'string[]', 'bytes[]'], [chianId, commandIDs, commandNames, commands])),

    buildCommandBatchWithRole: (chianId, role, commandIDs, commandNames, commands) =>
        arrayify(
            defaultAbiCoder.encode(
                ['uint256', 'uint256', 'bytes32[]', 'string[]', 'bytes[]'],
                [chianId, role, commandIDs, commandNames, commands],
            ),
        ),

    getAddresses,
};
