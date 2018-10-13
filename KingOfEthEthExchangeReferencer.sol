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

/// @title King of Eth: Resource-to-ETH Exchange Referencer
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Provides functionality to interface with the
///  ETH exchange contract
contract KingOfEthEthExchangeReferencer is GodMode {
    /// @dev Address of the ETH exchange contract
    address public ethExchangeContract;

    /// @dev Only the ETH exchange contract may run this function
    modifier onlyEthExchangeContract()
    {
        require(ethExchangeContract == msg.sender);
        _;
    }

    /// @dev God may set the ETH exchange contract's address
    /// @dev _ethExchangeContract The new address
    function godSetEthExchangeContract(address _ethExchangeContract)
        public
        onlyGod
    {
        ethExchangeContract = _ethExchangeContract;
    }
}
