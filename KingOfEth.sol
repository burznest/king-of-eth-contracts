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
import './KingOfEthHouses.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthRoads.sol';
import './KingOfEthRoadsReferencer.sol';
import './KingOfEthResourcesInterface.sol';
import './KingOfEthResourcesInterfaceReferencer.sol';

/// @title King of Eth
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for titles, and taxes
contract KingOfEth is
      GodMode
    , KingOfEthHousesReferencer
    , KingOfEthRoadsReferencer
    , KingOfEthResourcesInterfaceReferencer
{
    /// @dev Number used to divide the taxes to yield the King's share
    uint public constant kingsTaxDivisor = 5;

    /// @dev Number used to divide the taxes to yield the Wayfarer's share
    uint public constant wayfarersTaxDivisor = 20;

    /// @dev Number used to divide the taxes to yield Parliament's share
    uint public constant parliamentsTaxDivisor = 4;

    /// @dev Amount of time the King, Wayfarer, and Paliament must wait
    ///  between claiming/distributing their taxes
    uint public constant timeBetweenClaims = 2 weeks;

    /// @dev Amount of time the King or Parliement has to claim/distribute
    ///  their taxes before the other side is able to overthrow them
    uint public constant gracePeriod = 1 days;

    /// @dev The address of the current King
    address public king;

    /// @dev The amount of taxes currently reserved for the King
    uint public kingsTaxes;

    /// @dev The last time that the King claimed his taxes
    uint public kingsTaxesLastClaimed;

    /// @dev The address of the current Wayfarer
    address public wayfarer;

    /// @dev The amount of taxes currently reserved for the Wayfarer
    uint public wayfarersTaxes;

    /// @dev The last time that the Wayfarer claimed his taxes
    uint public wayfarersTaxesLastClaimed;

    /// @dev Relevant data for each seat of Parliament
    struct ParliamentSeatData {
        /// @dev The number of resource points the seat holds
        uint points;

        /// @dev The amount of unclaimed taxes the seat has
        ///  and can claim at any time
        uint unclaimedTaxes;
    }

    /// @dev The 10 seats of Parliament
    address[10] public parliamentSeats;

    /// @dev Mapping from an arbitrary address to data about a seat
    ///  of Parliament (this data exists only for the current seats)
    mapping (address => ParliamentSeatData) parliamentSeatData;

    /// @dev The number of taxes currently reserved for Parliament
    uint public parliamentsTaxes;

    /// @dev The last time that Parliament's taxes were distributed
    uint public parliamentsTaxesLastDistributed;

    /// @param _interfaceContract The address for the resources
    ///  interface contract
    constructor(address _interfaceContract) public
    {
        interfaceContract = _interfaceContract;

        // Game is paused as God must start it
        isPaused = true;
    }

    /// @dev Fired when the King's taxes are claimed
    event KingsTaxesClaimed(address king, uint claimedTime);

    /// @dev Fired when the Wayfarer's taxes are claimed
    event WayfarersTaxesClaimed(address wayfarer, uint claimedTime);

    /// @dev Fired when a seat in Parliament claims their
    ///  unclaimed taxes
    event ParliamentTaxesClaimed(address seat);

    /// @dev Fired when a new King claims the throne
    event NewKing(address king);

    /// @dev Fired when a new Wayfarer claims the title
    event NewWayfarer(address wayfarer);

    /// @dev Fired when a player claims a seat in Parliament
    event ParliamentSeatClaimed(address seat, uint points);

    /// @dev Fired when a successful inquest is made against a
    ///  seat of Parliament
    event ParliamentInquest(address seat, uint points);

    /// @dev Fired when Parliament's taxes are distributed
    event ParliamentsTaxesDistributed(
          address distributor
        , uint share
        , uint distributedTime
    );

    /// @dev Fired when Parliament is overthrown by the king
    event ParliamentOverthrown(uint overthrownTime);

    /// @dev Fired when the King is overthrown by Parliament
    event KingOverthrown(uint overthrownTime);

    /// @dev Only the King can run this
    modifier onlyKing()
    {
        require(king == msg.sender);
        _;
    }

    /// @dev Only the Wayfarer can run this
    modifier onlyWayfarer()
    {
        require(wayfarer == msg.sender);
        _;
    }

    /// @dev Only a Parliament seat can run this
    modifier onlyParliamentSeat()
    {
        require(0 != parliamentSeatData[msg.sender].points);
        _;
    }

    /// @dev God can withdraw his taxes
    function godWithdrawTaxes()
        public
        onlyGod
    {
        // Add up each Parliament seat's unclaimed taxes
        uint _parliamentsUnclaimed = 0;
        for(uint8 _i = 0; _i < 10; ++_i)
        {
            _parliamentsUnclaimed += parliamentSeatData[parliamentSeats[_i]].unclaimedTaxes;
        }

        // God's share is the balance minus the king's, the wayfarer's,
        //  Parliament's, as well as any of Parliament's seat's unclaimed taxes
        uint taxes = address(this).balance - kingsTaxes - wayfarersTaxes
                   - parliamentsTaxes - _parliamentsUnclaimed;

        god.transfer(taxes);
    }

    /// @dev God can start the game
    function godStartGame() public onlyGod
    {
        // Reset time title taxes were last claimed
        kingsTaxesLastClaimed           = now;
        wayfarersTaxesLastClaimed       = now;
        parliamentsTaxesLastDistributed = now;

        // Unpause the game
        isPaused = false;
    }

    /// @dev The King can claim his taxes
    function kingWithdrawTaxes()
        public
        onlyKing
    {
        // Require that enought time has passed since the King's last claim
        require(kingsTaxesLastClaimed + timeBetweenClaims < now);

        // The last claim time is now
        kingsTaxesLastClaimed = now;

        // Temporarily save the King's taxes
        uint _taxes = kingsTaxes;

        // Reset the King's taxes
        kingsTaxes = 0;

        king.transfer(_taxes);

        emit KingsTaxesClaimed(msg.sender, now);
    }

    /// @dev The Wayfarer can claim his taxes
    function wayfarerWithdrawTaxes()
        public
        onlyWayfarer
    {
        // Require that enough time has passed since the Wayfarer's last claim
        require(wayfarersTaxesLastClaimed + timeBetweenClaims < now);

        // The last claim time is now
        wayfarersTaxesLastClaimed = now;

        // Temporarily save the Wayfarer's taxes
        uint _taxes = wayfarersTaxes;

        // Reset the Wayfarer's taxes
        wayfarersTaxes = 0;

        wayfarer.transfer(_taxes);

        emit WayfarersTaxesClaimed(msg.sender, now);
    }

    /// @dev A seat of Parliament can withdraw any unclaimed taxes
    function parliamentWithdrawTaxes()
        public
    {
        // Lookup the data on the sender
        ParliamentSeatData storage _senderData = parliamentSeatData[msg.sender];

        // If the sender does indeed have unclaimed taxes
        if(0 != _senderData.unclaimedTaxes)
        {
            // Temporarily save the taxes
            uint _taxes = _senderData.unclaimedTaxes;

            // Mark the taxes as claimed
            _senderData.unclaimedTaxes = 0;

            // Send the sender the unclaimed taxes
            msg.sender.transfer(_taxes);
        }

        emit ParliamentTaxesClaimed(msg.sender);
    }

    /// @dev Claim the King's throne
    function claimThrone() public
    {
        KingOfEthHouses _housesContract = KingOfEthHouses(housesContract);

        // Require the claimant to have more points than the King
        require(_housesContract.numberOfPoints(king) < _housesContract.numberOfPoints(msg.sender));

        // Save the new King
        king = msg.sender;

        emit NewKing(msg.sender);
    }

    /// @dev Claim the Wayfarer's title
    function claimWayfarerTitle() public
    {
        KingOfEthRoads _roadsContract = KingOfEthRoads(roadsContract);

        // Require the claimant to have more roads than the wayfarer
        require(_roadsContract.numberOfRoads(wayfarer) < _roadsContract.numberOfRoads(msg.sender));

        // Save the new Wayfarer
        wayfarer = msg.sender;

        emit NewWayfarer(msg.sender);
    }

    /// @dev Claim a seat in Parliament
    function claimParliamentSeat() public
    {
        // Lookup the sender's data
        ParliamentSeatData storage _senderData = parliamentSeatData[msg.sender];

        // If the sender is not already in Parliament
        if(0 == _senderData.points)
        {
            // Determine the points of the sender
            uint _points
                = KingOfEthResourcesInterface(interfaceContract).lookupResourcePoints(msg.sender);

            // Lookup the lowest seat in parliament (the last seat)
            ParliamentSeatData storage _lastSeat = parliamentSeatData[parliamentSeats[9]];

            // If the lowest ranking seat has fewer points than the sender
            if(_lastSeat.points < _points)
            {
                // If the lowest ranking seat has unclaimed taxes
                if(0 != _lastSeat.unclaimedTaxes)
                {
                    // Put them back into Parliament's pool
                    parliamentsTaxes += _lastSeat.unclaimedTaxes;
                }

                // Delete the lowest seat's data
                delete parliamentSeatData[parliamentSeats[9]];

                // Record the sender's points
                _senderData.points = _points;

                // Record the new seat's temporary standing
                parliamentSeats[_i] = msg.sender;

                uint8 _i;

                // Move the new seat up until they are in the correct position
                for(_i = 8; _i >= 0; --_i)
                {
                    // If the seat above has fewer points than the new seat
                    if(parliamentSeatData[parliamentSeats[_i]].points < _points)
                    {
                        // Move the seat above down
                        parliamentSeats[_i + 1] = parliamentSeats[_i];
                    }
                    else
                    {
                        // We have found the new seat's position
                        parliamentSeats[_i] = msg.sender;

                        break;
                    }
                }

                emit ParliamentSeatClaimed(msg.sender, _points);
            }
        }
    }

    /// @dev Question the standing of a current seat in Parliament
    /// @param _seat The seat to run the inquest on
    function parliamentInquest(address _seat) public
    {
        // Grab the seat's data
        ParliamentSeatData storage _seatData = parliamentSeatData[_seat];

        // Ensure that the account in question is actually in Parliament
        if(0 != _seatData.points)
        {
            // Determine the current points held by the seat
            uint _newPoints
                = KingOfEthResourcesInterface(interfaceContract).lookupResourcePoints(_seat);

            uint _i;

            // If the seat has more points than before
            if(_seatData.points < _newPoints)
            {
                // Find the seat's current location
                _i = 9;
                while(_seat != parliamentSeats[_i])
                {
                    --_i;
                }

                // For each seat higher than the seat in question
                for(; _i > 0; --_i)
                {
                    // If the higher seat has fewer points than the seat in question
                    if(parliamentSeatData[parliamentSeats[_i - 1]].points < _newPoints)
                    {
                        // Move the seat back
                        parliamentSeats[_i] = parliamentSeats[_i - 1];
                    }
                    else
                    {
                        // Record the seat's (new) position
                        parliamentSeats[_i] = _seat;

                        break;
                    }
                }
            }
            // If the seat has the same number of points
            else if(_seatData.points == _newPoints)
            {
                revert();
            }
            // If the seat has fewer points than before
            else
            {
                // Find the seat's current position
                _i = 0;
                while(_seat != parliamentSeats[_i])
                {
                    ++_i;
                }

                // For each seat lower than the seat in question
                for(; _i < 10; ++_i)
                {
                    // If the lower seat has more points than the seat in question
                    if(parliamentSeatData[parliamentSeats[_i + 1]].points > _newPoints)
                    {
                        // Move the lower seat up
                        parliamentSeats[_i] = parliamentSeats[_i + 1];
                    }
                    else
                    {
                        // Record the seat's (new) position
                        parliamentSeats[_i] = _seat;

                        break;
                    }
                }
            }

            // Save the seat in question's points
            _seatData.points = _newPoints;

            emit ParliamentInquest(_seat, _newPoints);
        }
    }

    /// @dev Distribute the taxes set aside for Parliament to
    ///  the seats of Parliament
    function distributeParliamentTaxes()
        public
        onlyParliamentSeat
    {
        // Require enough time has passed since Parliament's last taxes
        // were distributed
        require(parliamentsTaxesLastDistributed + timeBetweenClaims < now);

        // Determine the share for each seat of Parliament (plus an additional
        // share for the distributor)
        uint _share = parliamentsTaxes / 11;

        // Calculate the distributor's share
        uint _distributorsShare = parliamentsTaxes - _share * 9;

        // Reset Parliament's claimable taxes
        parliamentsTaxes = 0;

        // For each seat of Parliament
        for(uint8 _i = 0; _i < 10; ++_i)
        {
            // If the distributor is not the seat in question
            if(msg.sender != parliamentSeats[_i])
            {
                // Add the share to the seat's unclaimedTaxes
                parliamentSeatData[parliamentSeats[_i]].unclaimedTaxes += _share;
            }
        }

        // Set the last time the taxes were distributed to now
        parliamentsTaxesLastDistributed = now;

        // Send the distributor their double share
        msg.sender.transfer(_distributorsShare);

        emit ParliamentsTaxesDistributed(msg.sender, _share, now);
    }

    /// @dev If the grace period has elapsed, the king can overthrow
    ///  Parliament and claim their taxes
    function overthrowParliament()
        public
        onlyKing
    {
        // Require that the time between claims plus
        //  the grace period has elapsed
        require(parliamentsTaxesLastDistributed + timeBetweenClaims + gracePeriod < now);

        // The king can now claim Parliament's taxes as well
        kingsTaxes += parliamentsTaxes;

        // Parliament has lost their taxes
        parliamentsTaxes = 0;

        // Parliament must wait before distributing their taxes again
        parliamentsTaxesLastDistributed = now;

        emit ParliamentOverthrown(now);
    }

    /// @dev If the grace period has elapsed, Parliament can overthrow
    ///  the king and claim his taxes
    function overthrowKing()
        public
        onlyParliamentSeat
    {
        // Require the time between claims plus
        // the grace period has elapsed
        require(kingsTaxesLastClaimed + timeBetweenClaims + gracePeriod < now);

        // Parliament can now claim the King's taxes as well
        parliamentsTaxes += kingsTaxes;

        // The King has lost his taxes
        kingsTaxes = 0;

        // The King must wait before claiming his taxes again
        kingsTaxesLastClaimed = now;

        emit KingOverthrown(now);
    }

    /// @dev Anyone can pay taxes
    function payTaxes() public payable
    {
        // Add the King's share
        kingsTaxes += msg.value / kingsTaxDivisor;

        // Add the Wayfarer's share
        wayfarersTaxes += msg.value / wayfarersTaxDivisor;

        // Add Parliament's share
        parliamentsTaxes += msg.value / parliamentsTaxDivisor;
    }
}
