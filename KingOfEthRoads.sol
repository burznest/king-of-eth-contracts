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
import './KingOfEthBoard.sol';
import './KingOfEthBoardReferencer.sol';
import './KingOfEthHousesAbstractInterface.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthReferencer.sol';
import './KingOfEthResourcesInterface.sol';
import './KingOfEthResourcesInterfaceReferencer.sol';
import './KingOfEthRoadRealty.sol';
import './KingOfEthRoadRealtyReferencer.sol';
import './KingOfEthRoadsAbstractInterface.sol';

/// @title King of Eth: Roads
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for roads
contract KingOfEthRoads is
      GodMode
    , KingOfEthBoardReferencer
    , KingOfEthHousesReferencer
    , KingOfEthReferencer
    , KingOfEthResourcesInterfaceReferencer
    , KingOfEthRoadRealtyReferencer
    , KingOfEthRoadsAbstractInterface
{
    /// @dev ETH cost to build a road
    uint public roadCost = 0.0002 ether;

    /// @dev Mapping from the x, y, direction coordinate of the location to its owner
    mapping (uint => mapping (uint => address[2])) owners;

    /// @dev Mapping from a players address to his road counts
    mapping (address => uint) roadCounts;

    /// @param _boardContract The address of the board contract
    /// @param _roadRealtyContract The address of the road realty contract
    /// @param _kingOfEthContract The address of the king contract
    /// @param _interfaceContract The address of the resources
    ///  interface contract
    constructor(
          address _boardContract
        , address _roadRealtyContract
        , address _kingOfEthContract
        , address _interfaceContract
    )
        public
    {
        boardContract      = _boardContract;
        roadRealtyContract = _roadRealtyContract;
        kingOfEthContract  = _kingOfEthContract;
        interfaceContract  = _interfaceContract;
    }

    /// @dev Fired when new roads are built
    event NewRoads(
          address owner
        , uint x
        , uint y
        , uint8 direction
        , uint length
    );

    /// @dev Fired when a road is sent from one player to another
    event SentRoad(
          uint x
        , uint y
        , uint direction
        , address from
        , address to
    );

    /// @dev Get the owner of the road at some location
    /// @param _x The x coordinate of the road
    /// @param _y The y coordinate of the road
    /// @param _direction The direction of the road (either
    ///  0 for right or 1 for down)
    /// @return The address of the owner
    function ownerOf(uint _x, uint _y, uint8 _direction)
        public
        view
        returns(address)
    {
        // Only 0 or 1 is a valid direction
        require(2 > _direction);

        return owners[_x][_y][_direction];
    }

    /// @dev Get the number of roads owned by a player
    /// @param _player The player's address
    /// @return The number of roads
    function numberOfRoads(address _player) public view returns(uint)
    {
        return roadCounts[_player];
    }

    /// @dev Only the owner of a road can run this
    /// @param _x The x coordinate of the road
    /// @param _y The y coordinate of the road
    /// @param _direction The direction of the road
    modifier onlyRoadOwner(uint _x, uint _y, uint8 _direction)
    {
        require(owners[_x][_y][_direction] == msg.sender);
        _;
    }

    /// @dev Build houses to the right
    /// @param _x The x coordinate of the starting point of the first road
    /// @param _y The y coordinate of the starting point of the first road
    /// @param _length The length to build
    function buildRight(uint _x, uint _y, uint _length) private
    {
        // Require that nobody currently owns the road
        require(0x0 == owners[_x][_y][0]);

        KingOfEthHousesAbstractInterface _housesContract = KingOfEthHousesAbstractInterface(housesContract);

        // Require that either the player owns the house at the
        // starting location, the road below it, the road to the
        // left of it, or the road above it
        address _houseOwner = _housesContract.ownerOf(_x, _y);
        require(_houseOwner == msg.sender || (0x0 == _houseOwner && (
               owners[_x][_y][1] == msg.sender
            || owners[_x - 1][_y][0] == msg.sender
            || owners[_x][_y - 1][1] == msg.sender
        )));

        // Set the new owner
        owners[_x][_y][0] = msg.sender;

        for(uint _i = 1; _i < _length; ++_i)
        {
            // Require that nobody currently owns the road
            require(0x0 == owners[_x + _i][_y][0]);

            // Require that either the house location is empty or
            // that it is owned by the player
            require(
                   _housesContract.ownerOf(_x + _i, _y) == 0x0
                || _housesContract.ownerOf(_x + _i, _y) == msg.sender
            );

            // Set the new owner
            owners[_x + _i][_y][0] = msg.sender;
        }
    }

    /// @dev Build houses downwards
    /// @param _x The x coordinate of the starting point of the first road
    /// @param _y The y coordinate of the starting point of the first road
    /// @param _length The length to build
    function buildDown(uint _x, uint _y, uint _length) private
    {
        // Require that nobody currently owns the road
        require(0x0 == owners[_x][_y][1]);

        KingOfEthHousesAbstractInterface _housesContract = KingOfEthHousesAbstractInterface(housesContract);

        // Require that either the player owns the house at the
        // starting location, the road to the right of it, the road to
        // the left of it, or the road above it
        address _houseOwner = _housesContract.ownerOf(_x, _y);
        require(_houseOwner == msg.sender || (0x0 == _houseOwner && (
               owners[_x][_y][0] == msg.sender
            || owners[_x - 1][_y][0] == msg.sender
            || owners[_x][_y - 1][1] == msg.sender
        )));

        // Set the new owner
        owners[_x][_y][1] = msg.sender;

        for(uint _i = 1; _i < _length; ++_i)
        {
            // Require that nobody currently owns the road
            require(0x0 == owners[_x][_y + _i][1]);

            // Require that either the house location is empty or
            // that it is owned by the player
            require(
                   _housesContract.ownerOf(_x, _y + _i) == 0x0
                || _housesContract.ownerOf(_x, _y + _i) == msg.sender
            );

            // Set the new owner
            owners[_x][_y + _i][1] = msg.sender;
        }
    }

    /// @dev Build houses to the left
    /// @param _x The x coordinate of the starting point of the first road
    /// @param _y The y coordinate of the starting point of the first road
    /// @param _length The length to build
    function buildLeft(uint _x, uint _y, uint _length) private
    {
        // Require that nobody currently owns the road
        require(0x0 == owners[_x - 1][_y][0]);

        KingOfEthHousesAbstractInterface _housesContract = KingOfEthHousesAbstractInterface(housesContract);

        // Require that either the player owns the house at the
        // starting location, the road to the right of it, the road
        // below it, or the road above it
        address _houseOwner = _housesContract.ownerOf(_x, _y);
        require(_houseOwner == msg.sender || (0x0 == _houseOwner && (
               owners[_x][_y][0] == msg.sender
            || owners[_x][_y][1] == msg.sender
            || owners[_x][_y - 1][1] == msg.sender
        )));

        // Set the new owner
        owners[_x - 1][_y][0] = msg.sender;

        for(uint _i = 1; _i < _length; ++_i)
        {
            // Require that nobody currently owns the road
            require(0x0 == owners[_x - _i - 1][_y][0]);

            // Require that either the house location is empty or
            // that it is owned by the player
            require(
                   _housesContract.ownerOf(_x - _i, _y) == 0x0
                || _housesContract.ownerOf(_x - _i, _y) == msg.sender
            );

            // Set the new owner
            owners[_x - _i - 1][_y][0] = msg.sender;
        }
    }

    /// @dev Build houses upwards
    /// @param _x The x coordinate of the starting point of the first road
    /// @param _y The y coordinate of the starting point of the first road
    /// @param _length The length to build
    function buildUp(uint _x, uint _y, uint _length) private
    {
        // Require that nobody currently owns the road
        require(0x0 == owners[_x][_y - 1][1]);

        KingOfEthHousesAbstractInterface _housesContract = KingOfEthHousesAbstractInterface(housesContract);

        // Require that either the player owns the house at the
        // starting location, the road to the right of it, the road
        // below it, or the road to the left of it
        address _houseOwner = _housesContract.ownerOf(_x, _y);
        require(_houseOwner == msg.sender || (0x0 == _houseOwner && (
               owners[_x][_y][0] == msg.sender
            || owners[_x][_y][1] == msg.sender
            || owners[_x - 1][_y][0] == msg.sender
        )));

        // Set the new owner
        owners[_x][_y - 1][1] = msg.sender;

        for(uint _i = 1; _i < _length; ++_i)
        {
            // Require that nobody currently owns the road
            require(0x0 == owners[_x][_y - _i - 1][1]);

            // Require that either the house location is empty or
            // that it is owned by the player
            require(
                   _housesContract.ownerOf(_x, _y - _i) == 0x0
                || _housesContract.ownerOf(_x, _y - _i) == msg.sender
            );

            // Set the new owner
            owners[_x][_y - _i - 1][1] = msg.sender;
        }
    }

    /// @dev God can change the road cost
    /// @param _newRoadCost The new cost of a road
    function godChangeRoadCost(uint _newRoadCost)
        public
        onlyGod
    {
        roadCost = _newRoadCost;
    }

    /// @dev The road realty contract can transfer road ownership
    /// @param _x The x coordinate of the road
    /// @param _y The y coordinate of the road
    /// @param _direction The direction of the road
    /// @param _from The previous owner of road
    /// @param _to The new owner of road
    function roadRealtyTransferOwnership(
          uint _x
        , uint _y
        , uint8 _direction
        , address _from
        , address _to
    )
        public
        onlyRoadRealtyContract
    {
        // Assert that the previous owner still has the road
        assert(owners[_x][_y][_direction] == _from);

        // Set the new owner
        owners[_x][_y][_direction] = _to;

        // Update the road counts
        --roadCounts[_from];
        ++roadCounts[_to];
    }

    /// @dev Build a road in a direction from a location
    /// @param _x The x coordinate of the starting location
    /// @param _y The y coordinate of the starting location
    /// @param _direction The direction to build (right is 0, down is 1,
    ///  2 is left, and 3 is up)
    /// @param _length The number of roads to build
    function buildRoads(
          uint _x
        , uint _y
        , uint8 _direction
        , uint _length
    )
        public
        payable
    {
        // Require at least one road to be built
        require(0 < _length);

        // Require that the cost for each road was payed
        require(roadCost * _length == msg.value);

        KingOfEthBoard _boardContract = KingOfEthBoard(boardContract);

        // Require that the start is within bounds
        require(_boardContract.boundX1() <= _x);
        require(_boardContract.boundY1() <= _y);
        require(_boardContract.boundX2() > _x);
        require(_boardContract.boundY2() > _y);

        // Burn the resource costs for each road
        KingOfEthResourcesInterface(interfaceContract).burnRoadCosts(
              _length
            , msg.sender
        );

        // If the direction is right
        if(0 == _direction)
        {
            // Require that the roads will be in bounds
            require(_boardContract.boundX2() > _x + _length);

            buildRight(_x, _y, _length);
        }
        // If the direction is down
        else if(1 == _direction)
        {
            // Require that the roads will be in bounds
            require(_boardContract.boundY2() > _y + _length);

            buildDown(_x, _y, _length);
        }
        // If the direction is left
        else if(2 == _direction)
        {
            // Require that the roads will be in bounds
            require(_boardContract.boundX1() < _x - _length - 1);

            buildLeft(_x, _y, _length);
        }
        // If the direction is up
        else if(3 == _direction)
        {
            // Require that the roads will be in bounds
            require(_boardContract.boundY1() < _y - _length - 1);

            buildUp(_x, _y, _length);
        }
        else
        {
            // Revert if the direction is invalid
            revert();
        }

        // Update the number of roads of the player
        roadCounts[msg.sender] += _length;

        // Pay taxes
        KingOfEthAbstractInterface(kingOfEthContract).payTaxes.value(msg.value)();

        emit NewRoads(msg.sender, _x, _y, _direction, _length);
    }

    /// @dev Send a road to another player
    /// @param _x The x coordinate of the road
    /// @param _y The y coordinate of the road
    /// @param _direction The direction of the road
    /// @param _to The recipient of the road
    function sendRoad(uint _x, uint _y, uint8 _direction, address _to)
        public
        onlyRoadOwner(_x, _y, _direction)
    {
        // Set the new owner
        owners[_x][_y][_direction] = _to;

        // Update road counts
        --roadCounts[msg.sender];
        ++roadCounts[_to];

        // Cancel any sales that exist
        KingOfEthRoadRealty(roadRealtyContract).roadsCancelRoadSale(
              _x
            , _y
            , _direction
        );

        emit SentRoad(_x, _y, _direction, msg.sender, _to);
    }
}
