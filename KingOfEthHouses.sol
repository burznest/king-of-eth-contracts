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
import './KingOfEthAuctionsAbstractInterface.sol';
import './KingOfEthAuctionsReferencer.sol';
import './KingOfEthBoard.sol';
import './KingOfEthBoardReferencer.sol';
import './KingOfEthHouseRealty.sol';
import './KingOfEthHouseRealtyReferencer.sol';
import './KingOfEthHousesAbstractInterface.sol';
import './KingOfEthReferencer.sol';
import './KingOfEthRoadsAbstractInterface.sol';
import './KingOfEthRoadsReferencer.sol';
import './KingOfEthResourcesInterface.sol';
import './KingOfEthResourcesInterfaceReferencer.sol';

/// @title King of Eth: Houses
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for houses
contract KingOfEthHouses is
      GodMode
    , KingOfEthAuctionsReferencer
    , KingOfEthBoardReferencer
    , KingOfEthHouseRealtyReferencer
    , KingOfEthHousesAbstractInterface
    , KingOfEthReferencer
    , KingOfEthRoadsReferencer
    , KingOfEthResourcesInterfaceReferencer
{
    /// @dev ETH cost to build or upgrade a house
    uint public houseCost = 0.001 ether;

    /// @dev Struct to hold info about a house location on the board
    struct LocationInfo {
        /// @dev The owner of the house at this location
        address owner;

        /// @dev The level of the house at this location
        uint8 level;
    }

    /// @dev Mapping from the (x, y) coordinate of the location to its info
    mapping (uint => mapping (uint => LocationInfo)) locationInfo;

    /// @dev Mapping from a player's address to his points
    mapping (address => uint) pointCounts;

    /// @param _blindAuctionsContract The address of the blind auctions contract
    /// @param _boardContract The address of the board contract
    /// @param _kingOfEthContract The address of the king contract
    /// @param _houseRealtyContract The address of the house realty contract
    /// @param _openAuctionsContract The address of the open auctions contract
    /// @param _roadsContract The address of the roads contract
    /// @param _interfaceContract The address of the resources
    ///  interface contract
    constructor(
          address _blindAuctionsContract
        , address _boardContract
        , address _kingOfEthContract
        , address _houseRealtyContract
        , address _openAuctionsContract
        , address _roadsContract
        , address _interfaceContract
    )
        public
    {
        blindAuctionsContract = _blindAuctionsContract;
        boardContract         = _boardContract;
        kingOfEthContract     = _kingOfEthContract;
        houseRealtyContract   = _houseRealtyContract;
        openAuctionsContract  = _openAuctionsContract;
        roadsContract         = _roadsContract;
        interfaceContract     = _interfaceContract;
    }

    /// @dev Fired when new houses are built
    event NewHouses(address owner, uint[] locations);

    /// @dev Fired when a house is sent from one player to another
    event SentHouse(uint x, uint y, address from, address to, uint8 level);

    /// @dev Fired when a house is upgraded
    event UpgradedHouse(uint x, uint y, address owner, uint8 newLevel);

    /// @dev Get the owner of the house at some location
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @return The address of the owner
    function ownerOf(uint _x, uint _y) public view returns(address)
    {
        return locationInfo[_x][_y].owner;
    }

    /// @dev Get the level of the house at some location
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @return The level of the house
    function level(uint _x, uint _y) public view returns(uint8)
    {
        return locationInfo[_x][_y].level;
    }

    /// @dev Get the number of points held by a player
    /// @param _player The player's address
    /// @return The number of points
    function numberOfPoints(address _player) public view returns(uint)
    {
        return pointCounts[_player];
    }

    /// @dev Helper function to build a house at a location
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    function buildHouseInner(uint _x, uint _y) private
    {
        // Lookup the info about the house
        LocationInfo storage _locationInfo = locationInfo[_x][_y];

        KingOfEthBoard _boardContract = KingOfEthBoard(boardContract);

        // Require the house to be within the current bounds of the game
        require(_boardContract.boundX1() <= _x);
        require(_boardContract.boundY1() <= _y);
        require(_boardContract.boundX2() > _x);
        require(_boardContract.boundY2() > _y);

        // Require the spot to be empty
        require(0x0 == _locationInfo.owner);

        KingOfEthRoadsAbstractInterface _roadsContract = KingOfEthRoadsAbstractInterface(roadsContract);

        // Require either either the right, bottom, left or top road
        // to be owned by the player
        require(
                _roadsContract.ownerOf(_x, _y, 0) == msg.sender
             || _roadsContract.ownerOf(_x, _y, 1) == msg.sender
             || _roadsContract.ownerOf(_x - 1, _y, 0) == msg.sender
             || _roadsContract.ownerOf(_x, _y - 1, 1) == msg.sender
        );

        // Require that there is no existing blind auction at the location
        require(!KingOfEthAuctionsAbstractInterface(blindAuctionsContract).existingAuction(_x, _y));

        // Require that there is no existing open auction at the location
        require(!KingOfEthAuctionsAbstractInterface(openAuctionsContract).existingAuction(_x, _y));

        // Set new owner
        _locationInfo.owner = msg.sender;

        // Update player's points
        ++pointCounts[msg.sender];

        // Distribute resources to the player
        KingOfEthResourcesInterface(interfaceContract).distributeResources(
              msg.sender
            , _x
            , _y
            , 0 // Level 0
        );
    }

    /// @dev God can change the house cost
    /// @param _newHouseCost The new cost of a house
    function godChangeHouseCost(uint _newHouseCost)
        public
        onlyGod
    {
        houseCost = _newHouseCost;
    }

    /// @dev The auctions contracts can set the owner of a house after an auction
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _owner The new owner of the house
    function auctionsSetOwner(uint _x, uint _y, address _owner)
        public
        onlyAuctionsContract
    {
        // Lookup the info about the house
        LocationInfo storage _locationInfo = locationInfo[_x][_y];

        // Require that nobody already owns the house.
        // Note that this would be an assert if only the blind auctions
        // contract used this code, but the open auctions contract
        // depends on this require to save space.
        require(0x0 == _locationInfo.owner);

        // Set the house's new owner
        _locationInfo.owner = _owner;

        // Give the player a point for the house
        ++pointCounts[_owner];

        // Distribute the resources for the house
        KingOfEthResourcesInterface(interfaceContract).distributeResources(
              _owner
            , _x
            , _y
            , 0 // Level 0
        );

        // Set up the locations for the event
        uint[] memory _locations = new uint[](2);
        _locations[0] = _x;
        _locations[1] = _y;

        emit NewHouses(_owner, _locations);
    }

    /// @dev The house realty contract can transfer house ownership
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _from The previous owner of house
    /// @param _to The new owner of house
    function houseRealtyTransferOwnership(
          uint _x
        , uint _y
        , address _from
        , address _to
    )
        public
        onlyHouseRealtyContract
    {
        // Lookup the info about the house
        LocationInfo storage _locationInfo = locationInfo[_x][_y];

        // Assert that the previous owner still has the house
        assert(_locationInfo.owner == _from);

        // Set the new owner
        _locationInfo.owner = _to;

        // Calculate the total points of the house
        uint _points = _locationInfo.level + 1;

        // Update the point counts
        pointCounts[_from] -= _points;
        pointCounts[_to]   += _points;
    }

    /// @dev Build multiple houses at once
    /// @param _locations An array of coordinates for the houses. These
    ///  are specified sequentially like [x1, y1, x2, y2] representing
    ///  location (x1, y1) and location (x2, y2).
    function buildHouses(uint[] _locations)
        public
        payable
    {
        // Require that there are an even number of locations
        require(0 == _locations.length % 2);

        uint _count = _locations.length / 2;

        // Require the house cost
        require(houseCost * _count == msg.value);

        // Pay taxes
        KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(msg.value)();

        // Burn the required resource costs for the houses
        KingOfEthResourcesInterface(interfaceContract).burnHouseCosts(
              _count
            , msg.sender
        );

        // Build a house at each one of the locations
        for(uint i = 0; i < _locations.length; i += 2)
        {
            buildHouseInner(_locations[i], _locations[i + 1]);
        }

        emit NewHouses(msg.sender, _locations);
    }

    /// @dev Send a house to another player
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _to The recipient of the house
    function sendHouse(uint _x, uint _y, address _to) public
    {
        // Lookup the info about the house
        LocationInfo storage _locationInfo = locationInfo[_x][_y];

        // Require that the sender is the owner
        require(_locationInfo.owner == msg.sender);

        // Set the new owner
        _locationInfo.owner = _to;

        // Calculate the points of the house
        uint _points = _locationInfo.level + 1;

        // Update point counts
        pointCounts[msg.sender] -= _points;
        pointCounts[_to]        += _points;

        // Cancel any sales that exist
        KingOfEthHouseRealty(houseRealtyContract).housesCancelHouseSale(_x, _y);

        emit SentHouse(_x, _y, msg.sender, _to, _locationInfo.level);
    }

    /// @dev Upgrade a house
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    function upgradeHouse(uint _x, uint _y) public payable
    {
        // Lookup the info about the house
        LocationInfo storage _locationInfo = locationInfo[_x][_y];

        // Require that the sender is the owner
        require(_locationInfo.owner == msg.sender);

        // Require the house cost be payed
        require(houseCost == msg.value);

        // Pay the taxes
        KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(msg.value)();

        // Burn the resource costs of the upgrade
        KingOfEthResourcesInterface(interfaceContract).burnUpgradeCosts(
              _locationInfo.level
            , msg.sender
        );

        // Update the house's level
        ++locationInfo[_x][_y].level;

        // Update the owner's points
        ++pointCounts[msg.sender];

        // Distribute the resources for the house
        KingOfEthResourcesInterface(interfaceContract).distributeResources(
              msg.sender
            , _x
            , _y
            , _locationInfo.level
        );

        emit UpgradedHouse(_x, _y, msg.sender, _locationInfo.level);
    }
}
