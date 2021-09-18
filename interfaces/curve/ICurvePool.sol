// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

interface ICurvePool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount)
        external;
}
