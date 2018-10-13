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

import './GodMode.sol';

/// @title King of Eth: Resource-to-Resource Exchange Referencer
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Provides functionality to interface with the
///  resource-to-resource contract
contract KingOfEthResourceExchangeReferencer is GodMode {
    /// @dev Address of the resource-to-resource contract
    address public resourceExchangeContract;

    /// @dev Only the resource-to-resource contract may run this function
    modifier onlyResourceExchangeContract()
    {
        require(resourceExchangeContract == msg.sender);
        _;
    }

    /// @dev God may set the resource-to-resource contract's address
    /// @dev _resourceExchangeContract The new address
    function godSetResourceExchangeContract(address _resourceExchangeContract)
        public
        onlyGod
    {
        resourceExchangeContract = _resourceExchangeContract;
    }
}
