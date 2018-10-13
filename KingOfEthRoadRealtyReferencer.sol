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

/// @title King of Eth: Road Realty Referencer
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Provides functionality to reference the road realty contract
contract KingOfEthRoadRealtyReferencer is GodMode {
    /// @dev The realty contract's address
    address public roadRealtyContract;

    /// @dev Only the road realty contract can run this function
    modifier onlyRoadRealtyContract()
    {
        require(roadRealtyContract == msg.sender);
        _;
    }

    /// @dev God can set the road realty contract
    /// @param _roadRealtyContract The new address
    function godSetRoadRealtyContract(address _roadRealtyContract)
        public
        onlyGod
    {
        roadRealtyContract = _roadRealtyContract;
    }
}
