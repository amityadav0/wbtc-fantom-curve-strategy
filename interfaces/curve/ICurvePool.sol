// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface ICurvePool {
    function add_liquidity(
        uint256[2] calldata _amounts,
        uint256 _min_mint_amount
    ) external;
}
