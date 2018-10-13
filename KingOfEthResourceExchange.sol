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
import './KingOfEthResourcesInterface.sol';
import './KingOfEthResourcesInterfaceReferencer.sol';
import './KingOfEthResourceType.sol';

/// @title King of Eth: Resource-to-Resource Exchange
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev All the resource-to-resource exchange functionality
contract KingOfEthResourceExchange is
      GodMode
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

        /// @dev The number to multiply an amount by to get the size
        ///  for that amount
        uint numerator;

        /// @dev The number to divide an amount by to get the size
        ///  for that amount
        uint denominator;
    }

    /// @dev The id of the next trade created
    uint public nextTradeId;

    /// @dev Mapping of trade ids to info about the trade
    mapping (uint => Trade) trades;

    /// @dev Fired when a trade is created
    event ResourceTradeCreated(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amountTrading
        , uint amountRequesting
        , address creator
    );

    /// @dev Fired when a trade is (partially) filled
    event ResourceTradeFilled(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amount
        , uint numerator
        , uint denominator
        , address creator
        , address filler
    );

    /// @dev Fired when a trade is cancelled
    event ResourceTradeCancelled(
          uint tradeId
        , ResourceType resource
        , ResourceType tradingFor
        , uint amount
        , address creator
    );

    /// @param _interfaceContract The address of the resources
    ///  interface contract
    constructor(address _interfaceContract)
        public
    {
        interfaceContract = _interfaceContract;
    }

    /// @dev Create a trade
    /// @param _resource The resource the trade is providing
    /// @param _tradingFor The resource the trade is asking for
    /// @param _amountTrading The amount of the resource to trade
    /// @param _amountRequesting The amount of the other resource
    ///   to request
    /// @return The id of the trade
    function createTrade(
          ResourceType _resource
        , ResourceType _tradingFor
        , uint _amountTrading
        , uint _amountRequesting
    )
        public
        returns(uint)
    {
        // Don't allow ETH trades
        require(
               ResourceType.ETH != _resource
            && ResourceType.ETH != _tradingFor
        );

        // Don't allow trades for the same resource
        require(_resource != _tradingFor);

        // Require that the amount for trade is greater than 0
        require(0 < _amountTrading);

        // Require that the amount requested is greater than 0
        require(0 < _amountRequesting);

        // Freeze the amount of tokens for that resource
        KingOfEthResourcesInterface(interfaceContract).exchangeFreezeTokens(
              _resource
            , msg.sender
            , _amountTrading
        );

        // Set up the info about the trade
        trades[nextTradeId] = Trade(
              msg.sender
            , _resource
            , _tradingFor
            , _amountTrading // Amount remaining to trade
            , _amountRequesting
            , _amountTrading
        );

        emit ResourceTradeCreated(
              nextTradeId
            , _resource
            , _tradingFor
            , _amountTrading
            , _amountRequesting
            , msg.sender
        );

        // Return the trade id
        return nextTradeId++;
    }

    /// @dev Fill an amount of some trade
    /// @param _tradeId The id of the trade
    /// @param _amount The amount of the provided resource to fill
    function fillTrade(uint _tradeId, uint _amount) public
    {
        // Require a nonzero amount to be filled
        require(0 < _amount);

        // Lookup the trade
        Trade storage _trade = trades[_tradeId];

        // Require that at least the amount filling is available to trade
        require(_trade.amountRemaining >= _amount);

        // Start calculating the size of the resources filling with
        uint _size = _amount * _trade.numerator;

        // Ensure that the result is reversable (there is no overflow)
        require(_amount == _size / _trade.numerator);

        // Require that the resulting amount is a whole number
        require(0 == _size % _trade.denominator);

        // Finish the size calculation
        _size /= _trade.denominator;

        // Reduce the amount remaining by the amount being filled
        _trade.amountRemaining -= _amount;

        // Send the filler the creator's frozen resources
        KingOfEthResourcesInterface(interfaceContract).exchangeFrozenTransfer(
              _trade.resource
            , _trade.creator
            , msg.sender
            , _amount
        );

        // Send the creator the filler's resources
        KingOfEthResourcesInterface(interfaceContract).exchangeTransfer(
              _trade.tradingFor
            , msg.sender
            , _trade.creator
            , _size
        );

        emit ResourceTradeFilled(
              _tradeId
            , _trade.resource
            , _trade.tradingFor
            , _amount
            , _trade.numerator
            , _trade.denominator
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

        // Set the amount remaining to trade to 0.
        // Note that this effectively cancels the trade
        _trade.amountRemaining = 0;

        // Thaw the creator's resource
        KingOfEthResourcesInterface(interfaceContract).exchangeThawTokens(
              _trade.resource
            , msg.sender
            , _amountRemaining
        );

        emit ResourceTradeCancelled(
              _tradeId
            , _trade.resource
            , _trade.tradingFor
            , _amountRemaining
            , msg.sender
        );
    }
}
