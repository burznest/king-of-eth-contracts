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
import './KingOfEthAbstractInterface.sol';
import './KingOfEthHousesAbstractInterface.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthReferencer.sol';

/// @title King of Eth: House Realty
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for controlling sales of houses
contract KingOfEthHouseRealty is
      GodMode
    , KingOfEthHousesReferencer
    , KingOfEthReferencer
{
    /// @dev The number that divides the amount payed for any sale to produce
    ///  the amount payed in taxes
    uint public constant taxDivisor = 25;

    /// @dev Mapping from the x, y coordinates of a house to the current sale
    ///  price (0 if there is no sale)
    mapping (uint => mapping (uint => uint)) housePrices;

    /// @dev Fired when there is a new house for sale
    event HouseForSale(
          uint x
        , uint y
        , address owner
        , uint amount
    );

    /// @dev Fired when the owner changes the price of a house
    event HousePriceChanged(uint x, uint y, uint amount);

    /// @dev Fired when a house is sold
    event HouseSold(
          uint x
        , uint y
        , address from
        , address to
        , uint amount
        , uint8 level
    );

    /// @dev Fired when the sale for a house is cancelled by the owner
    event HouseSaleCancelled(
          uint x
        , uint y
        , address owner
    );

    /// @dev Only the owner of the house at a location can run this
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    modifier onlyHouseOwner(uint _x, uint _y)
    {
        require(KingOfEthHousesAbstractInterface(housesContract).ownerOf(_x, _y) == msg.sender);
        _;
    }

    /// @dev This can only be run if there is *not* an existing sale for a house
    ///  at a location
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    modifier noExistingHouseSale(uint _x, uint _y)
    {
        require(0 == housePrices[_x][_y]);
        _;
    }

    /// @dev This can only be run if there is an existing sale for a house
    ///  at a location
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    modifier existingHouseSale(uint _x, uint _y)
    {
        require(0 != housePrices[_x][_y]);
        _;
    }

    /// @param _kingOfEthContract The address of the king contract
    constructor(address _kingOfEthContract) public
    {
        kingOfEthContract = _kingOfEthContract;
    }

    /// @dev The houses contract can cancel a sale when a house is transfered
    ///  to another player
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    function housesCancelHouseSale(uint _x, uint _y)
        public
        onlyHousesContract
    {
        // If there is indeed a sale
        if(0 != housePrices[_x][_y])
        {
            // Cancel the sale
            housePrices[_x][_y] = 0;

            emit HouseSaleCancelled(_x, _y, msg.sender);
        }
    }

    /// @dev The owner of a house can start a sale
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _askingPrice The price that must be payed by another player
    ///  to purchase the house
    function startHouseSale(uint _x, uint _y, uint _askingPrice)
        public
        notPaused
        onlyHouseOwner(_x, _y)
        noExistingHouseSale(_x, _y)
    {
        // Require that the price is at least 0
        require(0 != _askingPrice);

        // Record the price
        housePrices[_x][_y] = _askingPrice;

        emit HouseForSale(_x, _y, msg.sender, _askingPrice);
    }

    /// @dev The owner of a house can change the price of a sale
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _askingPrice The new price that must be payed by another
    ///  player to purchase the house
    function changeHousePrice(uint _x, uint _y, uint _askingPrice)
        public
        notPaused
        onlyHouseOwner(_x, _y)
        existingHouseSale(_x, _y)
    {
        // Require that the price is at least 0
        require(0 != _askingPrice);

        // Record the price
        housePrices[_x][_y] = _askingPrice;

        emit HousePriceChanged(_x, _y, _askingPrice);
    }

    /// @dev Anyone can purchase a house as long as the sale exists
    /// @param _x The y coordinate of the house
    /// @param _y The y coordinate of the house
    function purchaseHouse(uint _x, uint _y)
        public
        payable
        notPaused
        existingHouseSale(_x, _y)
    {
        // Require that the exact price was paid
        require(housePrices[_x][_y] == msg.value);

        // End the sale
        housePrices[_x][_y] = 0;

        // Calculate the taxes to be paid
        uint taxCut = msg.value / taxDivisor;

        // Pay the taxes
        KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(taxCut)();

        KingOfEthHousesAbstractInterface _housesContract = KingOfEthHousesAbstractInterface(housesContract);

        // Determine the previous owner
        address _oldOwner = _housesContract.ownerOf(_x, _y);

        // Send the buyer the house
        _housesContract.houseRealtyTransferOwnership(
              _x
            , _y
            , _oldOwner
            , msg.sender
        );

        // Send the previous owner his share
        _oldOwner.transfer(msg.value - taxCut);

        emit HouseSold(
              _x
            , _y
            , _oldOwner
            , msg.sender
            , msg.value
            , _housesContract.level(_x, _y)
        );
    }

    /// @dev The owner of a house can cancel a sale
    /// @param _x The y coordinate of the house
    /// @param _y The y coordinate of the house
    function cancelHouseSale(uint _x, uint _y)
        public
        notPaused
        onlyHouseOwner(_x, _y)
        existingHouseSale(_x, _y)
    {
        // Cancel the sale
        housePrices[_x][_y] = 0;

        emit HouseSaleCancelled(_x, _y, msg.sender);
    }
}
