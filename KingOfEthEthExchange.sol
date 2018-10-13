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
import './KingOfEthReferencer.sol';
import './KingOfEthResourcesInterface.sol';
import './KingOfEthResourcesInterfaceReferencer.sol';
import './KingOfEthResourceType.sol';

/// @title King of Eth: Resource-to-ETH Exchange
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev All the ETH exchange functionality
contract KingOfEthEthExchange is
      GodMode
    , KingOfEthReferencer
    , KingOfEthResourcesInterfaceReferencer
    , KingOfEthResourceType
{
    /// @dev Struct to hold data about a trade
    struct Trade {
        /// @dev The creator of the trade
        address creator;

        /// @dev The resource the trade is providing
        ResourceType resource;

        /// @dev The resource the trade is asking for
        ResourceType tradingFor;

        /// @dev The amount of the resource that is left to trade
        uint amountRemaining;

        /// @dev The amount of what is asked for needed for one
        ///  of the provided resource
        uint price;
    }

    /// @dev The number of decimals that the price of the trade has
    uint public constant priceDecimals = 6;

    /// @dev The number that divides ETH in a trade to pay as taxes
    uint public constant taxDivisor = 25;

    /// @dev The id of the next trade created
    uint public nextTradeId;

    /// @dev Mapping of trade ids to info about the trade
    mapping (uint => Trade) trades;

    /// @dev Fired when a trade is created
    event EthTradeCreated(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amount
        , uint price
        , address creator
    );

    /// @dev Fired when a trade is (partially) filled
    event EthTradeFilled(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amount
        , uint price
        , address creator
        , address filler
    );

    /// @dev Fired when a trade is cancelled
    event EthTradeCancelled(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amount
        , address creator
    );

    /// @param _kingOfEthContract The address of the king contract
    /// @param _interfaceContract The address of the resources
    ///  interface contract
    constructor(
          address _kingOfEthContract
        , address _interfaceContract
    )
        public
    {
        kingOfEthContract = _kingOfEthContract;
        interfaceContract = _interfaceContract;
    }

    /// @dev Create a trade
    /// @param _resource The resource the trade is providing
    /// @param _tradingFor The resource the trade is asking for
    /// @param _amount The amount of the resource that to trade
    /// @param _price The amount of what is asked for needed for one
    ///  of the provided resource
    /// @return The id of the trade
    function createTrade(
          ResourceType _resource
        , ResourceType _tradingFor
        , uint _amount
        , uint _price
    )
        public
        payable
        returns(uint)
    {
        // Require one of the resources to be ETH
        require(
               ResourceType.ETH == _resource
            || ResourceType.ETH == _tradingFor
        );

        // Don't allow trades for the same resource
        require(_resource != _tradingFor);

        // Require that the amount is greater than 0
        require(0 < _amount);

        // Require that the price is greater than 0
        require(0 < _price);

        // If the resource provided is ETH
        if(ResourceType.ETH == _resource)
        {
            // Start calculating size of resources
            uint _size = _amount * _price;

            // Ensure that the result is reversable (there is no overflow)
            require(_amount == _size / _price);

            // Finish the calculation
            _size /= 10 ** priceDecimals;

            // Ensure the size is a whole number
            require(0 == _size % 1 ether);

            // Require that the ETH was sent with the transaction
            require(_amount == msg.value);
        }
        // If it was a normal resource
        else
        {
            // Freeze the amount of tokens for that resource
            KingOfEthResourcesInterface(interfaceContract).exchangeFreezeTokens(
                  _resource
                , msg.sender
                , _amount
            );
        }

        // Set up the info about the trade
        trades[nextTradeId] = Trade(
              msg.sender
            , _resource
            , _tradingFor
            , _amount
            , _price
        );

        emit EthTradeCreated(
              nextTradeId
            , _resource
            , _tradingFor
            , _amount
            , _price
            , msg.sender
        );

        // Return the trade id
        return nextTradeId++;
    }

    /// @dev Fill an amount of some trade
    /// @param _tradeId The id of the trade
    /// @param _amount The amount of the provided resource to fill
    function fillTrade(uint _tradeId, uint _amount) public payable
    {
        // Require a nonzero amount to be filled
        require(0 < _amount);

        // Lookup the trade
        Trade storage _trade = trades[_tradeId];

        // Require that at least the amount filling is available to trade
        require(_trade.amountRemaining >= _amount);

        // Reduce the amount remaining by the amount being filled
        _trade.amountRemaining -= _amount;

        // The size of the trade
        uint _size;

        // The tax cut of this trade
        uint _taxCut;

        // If the resource filling for is ETH
        if(ResourceType.ETH == _trade.resource)
        {
            // Calculate the size of the resources filling with
            _size = _trade.price * _amount;

            // Ensure that the result is reversable (there is no overflow)
            require(_size / _trade.price == _amount);

            // Divide by the price decimals
            _size /= 10 ** priceDecimals;

            // Require that the size is a whole number
            require(0 == _size % 1 ether);

            // Get the size in resources
            _size /= 1 ether;

            // Require no ETH was sent with this transaction
            require(0 == msg.value);

            // Calculate the tax cut
            _taxCut = _amount / taxDivisor;

            // Send the filler the ETH
            msg.sender.transfer(_amount - _taxCut);

            // Pay the taxes
            KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(_taxCut)();

            // Send the creator the filler's resoruces
            KingOfEthResourcesInterface(interfaceContract).exchangeTransfer(
                  _trade.tradingFor
                , msg.sender
                , _trade.creator
                , _size
            );
        }
        // If ETH is being filled
        else
        {
            // Calculate the size of the resources filling with
            _size = _trade.price * _amount;

            // Ensure that the result is reversable (there is no overflow)
            require(_size / _trade.price == _amount);

            // Convert to ETH
            uint _temp = _size * 1 ether;

            // Ensure that the result is reversable (there is no overflow)
            require(_size == _temp / 1 ether);

            // Divide by the price decimals
            _size = _temp / (10 ** priceDecimals);

            // Require that the user has sent the correct amount of ETH
            require(_size == msg.value);

            // Calculate the tax cut
            _taxCut = msg.value / taxDivisor;

            // Send the creator his ETH
            _trade.creator.transfer(msg.value - _taxCut);

            // Pay the taxes
            KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(_taxCut)();

            // Send the filler the creator's frozen resources
            KingOfEthResourcesInterface(interfaceContract).exchangeFrozenTransfer(
                  _trade.resource
                , _trade.creator
                , msg.sender
                , _amount
            );
        }

        emit EthTradeFilled(
              _tradeId
            , _trade.resource
            , _trade.tradingFor
            , _amount
            , _trade.price
            , _trade.creator
            , msg.sender
        );
    }

    /// @dev Cancel a trade
    /// @param _tradeId The trade's id
    function cancelTrade(uint _tradeId) public
    {
        // Lookup the trade's info
        Trade storage _trade = trades[_tradeId];

        // Require that the creator is cancelling the trade
        require(_trade.creator == msg.sender);

        // Save the amount remaining
        uint _amountRemaining = _trade.amountRemaining;

        // Set the amount remaining to trade to 0
        // Note that this effectively cancels the trade
        _trade.amountRemaining = 0;

        // If the trade provided ETH
        if(ResourceType.ETH == _trade.resource)
        {
            // Sent the creator back his ETH
            msg.sender.transfer(_amountRemaining);
        }
        // If the trade provided a resource
        else
        {
            // Thaw the creator's resource
            KingOfEthResourcesInterface(interfaceContract).exchangeThawTokens(
                  _trade.resource
                , msg.sender
                , _amountRemaining
            );
        }

        emit EthTradeCancelled(
              _tradeId
            , _trade.resource
            , _trade.tradingFor
            , _amountRemaining
            , msg.sender
        );
    }
}
