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

/// @title King of Eth Resource: Corn
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev ERC20 contract for the corn resource
contract KingOfEthResourceCorn is KingOfEthResource {
    /// @dev The ERC20 token name
    string public constant name = "King of Eth Resource: Corn";

    /// @dev The ERC20 token symbol
    string public constant symbol = "KECO";
}
