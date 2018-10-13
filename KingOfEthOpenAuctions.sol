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
import './KingOfEthAuctionsAbstractInterface.sol';
import './KingOfEthBlindAuctionsReferencer.sol';
import './KingOfEthBoard.sol';
import './KingOfEthBoardReferencer.sol';
import './KingOfEthHousesAbstractInterface.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthReferencer.sol';

/// @title King of Eth: Open Auctions
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for open auctions of houses
contract KingOfEthOpenAuctions is
      GodMode
    , KingOfEthAuctionsAbstractInterface
    , KingOfEthReferencer
    , KingOfEthBlindAuctionsReferencer
    , KingOfEthBoardReferencer
    , KingOfEthHousesReferencer
{
    /// @dev Data for an auction
    struct Auction {
        /// @dev The time the auction started
        uint startTime;

        /// @dev The (current) winning bid
        uint winningBid;

        /// @dev The address of the (current) winner
        address winner;
    }

    /// @dev Mapping from location (x, y) to the auction at that location
    mapping (uint => mapping (uint => Auction)) auctions;

    /// @dev The span of time that players may bid on an auction
    uint public constant bidSpan = 20 minutes;

    /// @param _kingOfEthContract The address for the king contract
    /// @param _blindAuctionsContract The address for the blind auctions contract
    /// @param _boardContract The address for the board contract
    constructor(
          address _kingOfEthContract
        , address _blindAuctionsContract
        , address _boardContract
    )
        public
    {
        kingOfEthContract     = _kingOfEthContract;
        blindAuctionsContract = _blindAuctionsContract;
        boardContract         = _boardContract;

        // Auctions are not allowed before God has begun the game
        isPaused = true;
    }

    /// @dev Fired when a new auction is started
    event OpenAuctionStarted(
          uint x
        , uint y
        , address starter
        , uint startTime
    );

    /// @dev Fired when a new bid is placed
    event OpenBidPlaced(uint x, uint y, address bidder, uint amount);

    /// @dev Fired when an auction is closed
    event OpenAuctionClosed(uint x, uint y, address newOwner, uint amount);

    /// @dev Determines if there is an auction at a particular location
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    /// @return true if there is an existing auction
    function existingAuction(uint _x, uint _y) public view returns(bool)
    {
        return 0 != auctions[_x][_y].startTime;
    }

    /// @dev Create an auction at a particular location
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    function createAuction(uint _x, uint _y) public notPaused
    {
        // Require that there is not an auction already started at
        // the location
        require(0 == auctions[_x][_y].startTime);

        // Require that there is no blind auction at that location
        require(!KingOfEthAuctionsAbstractInterface(blindAuctionsContract).existingAuction(_x, _y));

        KingOfEthBoard _board = KingOfEthBoard(boardContract);

        // Require that there is at least one available auction remaining
        require(0 < _board.auctionsRemaining());

        // Require that the auction is within the current bounds of the board
        require(_board.boundX1() < _x);
        require(_board.boundY1() < _y);
        require(_board.boundX2() > _x);
        require(_board.boundY2() > _y);

        // Require that nobody currently owns the house
        require(0x0 == KingOfEthHousesAbstractInterface(housesContract).ownerOf(_x, _y));

        // Use up an available auction
        _board.auctionsDecrementAuctionsRemaining();

        auctions[_x][_y].startTime = now;

        emit OpenAuctionStarted(_x, _y, msg.sender, now);
    }

    /// @dev Make a bid on an auction. The amount bid is the amount sent
    ///  with the transaction.
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    function placeBid(uint _x, uint _y) public payable notPaused
    {
        // Lookup the auction
        Auction storage _auction = auctions[_x][_y];

        // Require that the auction actually exists
        require(0 != _auction.startTime);

        // Require that it is still during the bid span
        require(_auction.startTime + bidSpan > now);

        // If the new bid is larger than the current winning bid
        if(_auction.winningBid < msg.value)
        {
            // Temporarily save the old winning values
            uint    _oldWinningBid = _auction.winningBid;
            address _oldWinner     = _auction.winner;

            // Store the new winner
            _auction.winningBid = msg.value;
            _auction.winner     = msg.sender;

            // Send the loser back their ETH
            if(0 < _oldWinningBid) {
                _oldWinner.transfer(_oldWinningBid);
            }
        }
        else
        {
            // Return the sender their ETH
            msg.sender.transfer(msg.value);
        }

        emit OpenBidPlaced(_x, _y, msg.sender, msg.value);
    }

    /// @dev Close an auction and distribute the bid amount as taxes
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    function closeAuction(uint _x, uint _y) public notPaused
    {
        // Lookup the auction
        Auction storage _auction = auctions[_x][_y];

        // Require that the auction actually exists
        require(0 != _auction.startTime);

        // If nobody won the auction
        if(0x0 == _auction.winner)
        {
            // Mark that there is no current auction for this location
            _auction.startTime = 0;

            // Allow another auction to be created
            KingOfEthBoard(boardContract).auctionsIncrementAuctionsRemaining();
        }
        // If a player won the auction
        else
        {
            // Set the auction's winner as the owner of the house.
            // Note that this will fail if there is already an owner so we
            // don't need to mark the auction as closed with some extra
            // variable.
            KingOfEthHousesAbstractInterface(housesContract).auctionsSetOwner(
                  _x
                , _y
                , _auction.winner
            );

            // Pay the taxes
            KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(_auction.winningBid)();
        }

        emit OpenAuctionClosed(_x, _y, _auction.winner, _auction.winningBid);
    }
}
