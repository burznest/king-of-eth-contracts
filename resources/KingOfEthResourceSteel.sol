/****************************************************
 *
 * Copyright 2018 BurzNest LLC. All rights reserved.
 *
 * The contents of this file are provided for review
 * and educational purposes ONLY. You MAY NOT use,
 * copy, distribute, or modify this software without
 * explicit written permission from BurzNest LLC.
 *
 ****************************************************/

pragma solidity ^0.4.24;

import '../KingOfEthResource.sol';

/// @title King of Eth Resource: Steel
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev ERC20 contract for the steel resource
contract KingOfEthResourceSteel is KingOfEthResource {
    /// @dev The ERC20 token name
    string public constant name = "King of Eth Resource: Steel";

    /// @dev The ERC20 token symbol
    string public constant symbol = "KEST";
}
