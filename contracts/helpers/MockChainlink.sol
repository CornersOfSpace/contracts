// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

contract MockChainlink {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        answer = 30000000000;
    }
}
