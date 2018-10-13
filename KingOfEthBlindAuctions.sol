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
import './KingOfEthBoard.sol';
import './KingOfEthBoardReferencer.sol';
import './KingOfEthHousesAbstractInterface.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthOpenAuctionsReferencer.sol';
import './KingOfEthReferencer.sol';

/// @title King of Eth: Blind Auctions
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev This contracts provides the functionality for blind
///  for houses auctions
contract KingOfEthBlindAuctions is
      GodMode
    , KingOfEthReferencer
    , KingOfEthBoardReferencer
    , KingOfEthHousesReferencer
    , KingOfEthOpenAuctionsReferencer
{
    /// @dev A blinded bid
    struct Bid {
        /// @dev The hash value of the blinded bid
        bytes32 blindedBid;

        /// @dev The deposit that was made with the bid
        uint deposit;
    }

    /// @dev Information about a particular auction
    struct AuctionInfo {
        /// @dev The auction's x coordinate
        uint x;

        /// @dev The auction's y coordinate
        uint y;

        /// @dev The auctions's starting time
        uint startTime;

        /// @dev The blinded bids that each address made on the auction
        mapping (address => Bid[]) bids;

        /// @dev The total amount of unrevealed deposits for the auction
        uint unrevealedAmount;

        /// @dev The address of placer of the top revealed bid
        address topBidder;

        /// @dev The value of the top revealed bid
        uint topBid;

        /// @dev Has the auction been closed?
        bool closed;
    }

    /// @dev The span of time that players may bid on an auction
    uint public constant bidSpan = 10 minutes;

    /// @dev The span of time that players may reveal bids (after
    ///  the bid span)
    uint public constant revealSpan = 10 minutes;

    /// @dev The id that will be used for the next auction.
    ///  Note this is set to one so that checking a house without
    ///  an auction id does not resolve to an auction.
    ///  The contract will have to be replaced if all the ids are
    ///  used.
    uint public nextAuctionId = 1;

    /// @dev A mapping from an x, y coordinate to the id of a corresponding auction
    mapping (uint => mapping (uint => uint)) auctionIds;

    /// @dev A mapping from the id of an auction to the info about the auction
    mapping (uint => AuctionInfo) auctionInfo;

    /// @param _kingOfEthContract The address for the king contract
    /// @param _boardContract The address for the board contract
    constructor(
          address _kingOfEthContract
        , address _boardContract
    )
        public
    {
        kingOfEthContract = _kingOfEthContract;
        boardContract     = _boardContract;

        // Auctions are not allowed before God has begun the game
        isPaused = true;
    }

    /// @dev Fired when a new auction is started
    event BlindAuctionStarted(
          uint id
        , uint x
        , uint y
        , address starter
        , uint startTime
    );

    /// @dev Fired when a player places a new bid
    event BlindBidPlaced(
          uint id
        , address bidder
        , uint maxAmount
    );

    /// @dev Fired when a player reveals some bids
    event BlindBidsRevealed(
          uint id
        , address revealer
        , uint topBid
    );

    /// @dev Fired when a player closes an auction
    event BlindAuctionClosed(
          uint id
        , uint x
        , uint y
        , address newOwner
        , uint amount
    );

    /// @dev Create the hash of a blinded bid using keccak256
    /// @param _bid The true bid amount
    /// @param _isFake Is the bid fake?
    /// @param _secret The secret seed
    function blindedBid(uint _bid, bool _isFake, bytes32 _secret)
        public
        pure
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(_bid, _isFake, _secret));
    }

    /// @dev Determines if there is an auction at a particular location
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    /// @return true if there is an existing auction
    function existingAuction(uint _x, uint _y) public view returns(bool)
    {
        return 0 != auctionInfo[auctionIds[_x][_y]].startTime;
    }

    /// @dev Create an auction at a particular location
    /// @param _x The x coordinate of the auction
    /// @param _y The y coordinate of the auction
    function createAuction(uint _x, uint _y) public notPaused
    {
        // Require that there is not already a started auction
        // at that location
        require(0 == auctionInfo[auctionIds[_x][_y]].startTime);

        // Require that there is not currently an open auction at
        // the location
        require(!KingOfEthAuctionsAbstractInterface(openAuctionsContract).existingAuction(_x, _y));

        KingOfEthBoard _board = KingOfEthBoard(boardContract);

        // Require that there is at least one available auction remaining
        require(0 < _board.auctionsRemaining());

        // Require that the auction is within the current bounds of the board
        require(_board.boundX1() < _x);
        require(_board.boundY1() < _y);
        require(_board.boundX2() > _x);
        require(_board.boundY2() > _y);

        // Require that nobody current owns the house
        require(0x0 == KingOfEthHousesAbstractInterface(housesContract).ownerOf(_x, _y));

        // Use up an available auction
        _board.auctionsDecrementAuctionsRemaining();

        // Claim the next auction id
        uint _id = nextAuctionId++;

        // Record the id of the auction
        auctionIds[_x][_y] = _id;

        AuctionInfo storage _auctionInfo = auctionInfo[_id];

        // Setup the starting data for the auction
        _auctionInfo.x         = _x;
        _auctionInfo.y         = _y;
        _auctionInfo.startTime = now;

        emit BlindAuctionStarted(
              _id
            , _x
            , _y
            , msg.sender
            , now
        );
    }

    /// @dev Place a bid on an auction. This function accepts the
    ///  deposit as msg.value
    /// @param _id The id of the auction to bid on
    /// @param _blindedBid The hash of the blinded bid
    function placeBid(uint _id, bytes32 _blindedBid)
        public
        payable
        notPaused
    {
        // Retrieve the info about the auction
        AuctionInfo storage _auctionInfo = auctionInfo[_id];

        // Require that an auction exists
        require(0 != _auctionInfo.startTime);

        // Require that it is still during the bid span
        require(_auctionInfo.startTime + bidSpan > now);

        // Add the amount deposited to the unrevealed amount
        // for the auction
        _auctionInfo.unrevealedAmount += msg.value;

        // Add the bid to the auctions bids for that player
        _auctionInfo.bids[msg.sender].push(Bid(
              _blindedBid
            , msg.value
        ));

        emit BlindBidPlaced(_id, msg.sender, msg.value);
    }

    /// @dev Reveal all of a player's bids
    /// @param _id The id of the auction that the bids were placed on
    /// @param _values The true values of the bids of each blinded bid
    /// @param _isFakes Whether each individual blinded bid was fake
    /// @param _secrets The secret seeds of each blinded bid
    function revealBids(
          uint _id
        , uint[] _values
        , bool[] _isFakes
        , bytes32[] _secrets
    )
        public
        notPaused
    {
        // Lookup the information about the auction
        AuctionInfo storage _auctionInfo = auctionInfo[_id];

        uint _biddersBidCount = _auctionInfo.bids[msg.sender].length;

        // Require that the user has submitted reveals for all of his bids
        require(_biddersBidCount == _values.length);
        require(_biddersBidCount == _isFakes.length);
        require(_biddersBidCount == _secrets.length);

        // Require that it's after the bid span
        require(_auctionInfo.startTime + bidSpan < now);

        // Require it's before the end of the reveal span
        require(_auctionInfo.startTime + bidSpan + revealSpan > now);

        // The refund the player will receive
        uint _refund;

        // The maximum bid made by the player
        uint _maxBid;

        // For each of the user's bids...
        for(uint _i = 0; _i < _biddersBidCount; ++_i)
        {
            Bid storage _bid = _auctionInfo.bids[msg.sender][_i];
            uint _value      = _values[_i];

            // If the blinded bid's hash does not equal the one the user
            // submitted then the revealed values are incorrect incorrect
            // and skipped. Note that the  user will not receive a refund
            // for this individual reveal in this case
            if(_bid.blindedBid != keccak256(abi.encodePacked(_value, _isFakes[_i], _secrets[_i])))
            {
                continue;
            }

            // Add the successfully revealed bid deposit to the refund
            _refund += _bid.deposit;

            // If the bid was not fake, and it is greater than the current
            // maximum bid, then it is the player's new maximum bid
            if(!_isFakes[_i] && _bid.deposit >= _value && _maxBid < _value)
            {
                _maxBid = _value;
            }

            // Ensure that the succesfully revealed bid cannot be re-revealed
            _bid.blindedBid = bytes32(0);
        }

        // Reduce the unrevealed amount for the auction by the refund amount
        _auctionInfo.unrevealedAmount -= _refund;

        // If the maximum bid is not 0
        if(0 != _maxBid)
        {
            // If the top bid is currently 0, i.e. this is the first
            // player to reveal non-zero bids
            if(0 == _auctionInfo.topBid)
            {
                // Don't refund the player their max bid yet
                _refund -= _maxBid;

                // The player is the current winner
                _auctionInfo.topBidder = msg.sender;
                _auctionInfo.topBid    = _maxBid;
            }
            // If the user has made a higher bid than the current winner
            else if(_auctionInfo.topBid < _maxBid)
            {
                // Refund the previous winner their bid
                _auctionInfo.topBidder.transfer(_auctionInfo.topBid);

                // Don't refund the player their max bid yet
                _refund -= _maxBid;

                // The player is the current winner
                _auctionInfo.topBidder = msg.sender;
                _auctionInfo.topBid    = _maxBid;
            }
        }

        // Send the player his refund
        msg.sender.transfer(_refund);

        emit BlindBidsRevealed(_id, msg.sender, _maxBid);
    }

    /// @dev Close the auction and claim its unrevealed
    ///  amount as taxes
    /// @param _id The id of the auction to be closed
    function closeAuction(uint _id) public notPaused
    {
        // Lookup the auction's info
        AuctionInfo storage _auctionInfo = auctionInfo[_id];

        // Require that an auction exists
        require(0 != _auctionInfo.startTime);

        // Require that the auction hasn't already been closed
        require(!_auctionInfo.closed);

        // Require that it is after the reveal span
        require(_auctionInfo.startTime + bidSpan + revealSpan < now);

        // Set the auction to closed
        _auctionInfo.closed = true;

        // If nobody won the auction
        if(0x0 == _auctionInfo.topBidder)
        {
            // Mark that there is no current auction for this location
            _auctionInfo.startTime = 0;

            // Allow another auction to be created
            KingOfEthBoard(boardContract).auctionsIncrementAuctionsRemaining();

            // Pay the unrevelealed amount as taxes
            KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(_auctionInfo.unrevealedAmount)();
        }
        // If a player won the auction
        else
        {
            // Set the auction's winner as the owner of the house
            KingOfEthHousesAbstractInterface(housesContract).auctionsSetOwner(
                  _auctionInfo.x
                , _auctionInfo.y
                , _auctionInfo.topBidder
            );

            // The amount payed in taxes is the unrevealed amount plus
            // the winning bid
            uint _amount = _auctionInfo.unrevealedAmount + _auctionInfo.topBid;

            // Pay the taxes
            KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(_amount)();
        }

        emit BlindAuctionClosed(
              _id
            , _auctionInfo.x
            , _auctionInfo.y
            , _auctionInfo.topBidder
            , _auctionInfo.topBid
        );
    }
}
