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

/// @title King of Eth: House Realty Referencer
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Provides functionality to reference the house realty contract
contract KingOfEthHouseRealtyReferencer is GodMode {
    /// @dev The realty contract's address
    address public houseRealtyContract;

    /// @dev Only the house realty contract can run this function
    modifier onlyHouseRealtyContract()
    {
        require(houseRealtyContract == msg.sender);
        _;
    }

    /// @dev God can set the house realty contract
    /// @param _houseRealtyContract The new address
    function godSetHouseRealtyContract(address _houseRealtyContract)
        public
        onlyGod
    {
        houseRealtyContract = _houseRealtyContract;
    }
}
