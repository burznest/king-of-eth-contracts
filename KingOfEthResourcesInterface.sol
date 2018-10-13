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
import './KingOfEthExchangeReferencer.sol';
import './KingOfEthHousesReferencer.sol';
import './KingOfEthResource.sol';
import './KingOfEthResourceType.sol';
import './KingOfEthRoadsReferencer.sol';

/// @title King of Eth: Resources Interface
/// @author Anthony Burzillo <burz@burznest.com>
/// @dev Contract for interacting with resources
contract KingOfEthResourcesInterface is
      GodMode
    , KingOfEthExchangeReferencer
    , KingOfEthHousesReferencer
    , KingOfEthResourceType
    , KingOfEthRoadsReferencer
{
    /// @dev Amount of resources a user gets for building a house
    uint public constant resourcesPerHouse = 3;

    /// @dev Address for the bronze contract
    address public bronzeContract;

    /// @dev Address for the corn contract
    address public cornContract;

    /// @dev Address for the gold contract
    address public goldContract;

    /// @dev Address for the oil contract
    address public oilContract;

    /// @dev Address for the ore contract
    address public oreContract;

    /// @dev Address for the steel contract
    address public steelContract;

    /// @dev Address for the uranium contract
    address public uraniumContract;

    /// @dev Address for the wood contract
    address public woodContract;

    /// @param _bronzeContract The address of the bronze contract
    /// @param _cornContract The address of the corn contract
    /// @param _goldContract The address of the gold contract
    /// @param _oilContract The address of the oil contract
    /// @param _oreContract The address of the ore contract
    /// @param _steelContract The address of the steel contract
    /// @param _uraniumContract The address of the uranium contract
    /// @param _woodContract The address of the wood contract
    constructor(
          address _bronzeContract
        , address _cornContract
        , address _goldContract
        , address _oilContract
        , address _oreContract
        , address _steelContract
        , address _uraniumContract
        , address _woodContract
    )
        public
    {
        bronzeContract  = _bronzeContract;
        cornContract    = _cornContract;
        goldContract    = _goldContract;
        oilContract     = _oilContract;
        oreContract     = _oreContract;
        steelContract   = _steelContract;
        uraniumContract = _uraniumContract;
        woodContract    = _woodContract;
    }

    /// @dev Return the particular address for a certain resource type
    /// @param _type The resource type
    /// @return The address for that resource
    function contractFor(ResourceType _type)
        public
        view
        returns(address)
    {
        // ETH does not have a contract
        require(ResourceType.ETH != _type);

        if(ResourceType.BRONZE == _type)
        {
            return bronzeContract;
        }
        else if(ResourceType.CORN == _type)
        {
            return cornContract;
        }
        else if(ResourceType.GOLD == _type)
        {
            return goldContract;
        }
        else if(ResourceType.OIL == _type)
        {
            return oilContract;
        }
        else if(ResourceType.ORE == _type)
        {
            return oreContract;
        }
        else if(ResourceType.STEEL == _type)
        {
            return steelContract;
        }
        else if(ResourceType.URANIUM == _type)
        {
            return uraniumContract;
        }
        else if(ResourceType.WOOD == _type)
        {
            return woodContract;
        }
    }

    /// @dev Determine the resource type of a tile
    /// @param _x The x coordinate of the top left corner of the tile
    /// @param _y The y coordinate of the top left corner of the tile
    function resourceType(uint _x, uint _y)
        public
        pure
        returns(ResourceType resource)
    {
        uint _seed = (_x + 7777777) ^  _y;

        if(0 == _seed % 97)
        {
          return ResourceType.URANIUM;
        }
        else if(0 == _seed % 29)
        {
          return ResourceType.OIL;
        }
        else if(0 == _seed % 23)
        {
          return ResourceType.STEEL;
        }
        else if(0 == _seed % 17)
        {
          return ResourceType.GOLD;
        }
        else if(0 == _seed % 11)
        {
          return ResourceType.BRONZE;
        }
        else if(0 == _seed % 5)
        {
          return ResourceType.WOOD;
        }
        else if(0 == _seed % 2)
        {
          return ResourceType.CORN;
        }
        else
        {
          return ResourceType.ORE;
        }
    }

    /// @dev Lookup the number of resource points for a certain
    ///  player
    /// @param _player The player in question
    function lookupResourcePoints(address _player)
        public
        view
        returns(uint)
    {
        uint result = 0;

        result += KingOfEthResource(bronzeContract).balanceOf(_player);
        result += KingOfEthResource(goldContract).balanceOf(_player)    * 3;
        result += KingOfEthResource(steelContract).balanceOf(_player)   * 6;
        result += KingOfEthResource(oilContract).balanceOf(_player)     * 10;
        result += KingOfEthResource(uraniumContract).balanceOf(_player) * 44;

        return result;
    }

    /// @dev Burn the resources necessary to build a house
    /// @param _count the number of houses being built
    /// @param _player The player who is building the house
    function burnHouseCosts(uint _count, address _player)
        public
        onlyHousesContract
    {
        // Costs 2 corn per house
        KingOfEthResource(contractFor(ResourceType.CORN)).interfaceBurnTokens(
              _player
            , 2 * _count
        );

        // Costs 2 ore per house
        KingOfEthResource(contractFor(ResourceType.ORE)).interfaceBurnTokens(
              _player
            , 2 * _count
        );

        // Costs 1 wood per house
        KingOfEthResource(contractFor(ResourceType.WOOD)).interfaceBurnTokens(
              _player
            , _count
        );
    }

    /// @dev Burn the costs of upgrading a house
    /// @param _currentLevel The level of the house before the upgrade
    /// @param _player The player who is upgrading the house
    function burnUpgradeCosts(uint8 _currentLevel, address _player)
        public
        onlyHousesContract
    {
        // Do not allow upgrades after level 4
        require(5 > _currentLevel);

        // Burn the base house cost
        burnHouseCosts(1, _player);

        if(0 == _currentLevel)
        {
            // Level 1 costs bronze
            KingOfEthResource(contractFor(ResourceType.BRONZE)).interfaceBurnTokens(
                  _player
                , 1
            );
        }
        else if(1 == _currentLevel)
        {
            // Level 2 costs gold
            KingOfEthResource(contractFor(ResourceType.GOLD)).interfaceBurnTokens(
                  _player
                , 1
            );
        }
        else if(2 == _currentLevel)
        {
            // Level 3 costs steel
            KingOfEthResource(contractFor(ResourceType.STEEL)).interfaceBurnTokens(
                  _player
                , 1
            );
        }
        else if(3 == _currentLevel)
        {
            // Level 4 costs oil
            KingOfEthResource(contractFor(ResourceType.OIL)).interfaceBurnTokens(
                  _player
                , 1
            );
        }
        else if(4 == _currentLevel)
        {
            // Level 5 costs uranium
            KingOfEthResource(contractFor(ResourceType.URANIUM)).interfaceBurnTokens(
                  _player
                , 1
            );
        }
    }

    /// @dev Mint resources for a house and distribute all to its owner
    /// @param _owner The owner of the house
    /// @param _x The x coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _y The y coordinate of the house
    /// @param _level The new level of the house
    function distributeResources(address _owner, uint _x, uint _y, uint8 _level)
        public
        onlyHousesContract
    {
        // Calculate the count of resources for this level
        uint _count = resourcesPerHouse * uint(_level + 1);

        // Distribute the top left resource
        KingOfEthResource(contractFor(resourceType(_x - 1, _y - 1))).interfaceMintTokens(
            _owner
          , _count
        );

        // Distribute the top right resource
        KingOfEthResource(contractFor(resourceType(_x, _y - 1))).interfaceMintTokens(
            _owner
          , _count
        );

        // Distribute the bottom right resource
        KingOfEthResource(contractFor(resourceType(_x, _y))).interfaceMintTokens(
            _owner
          , _count
        );

        // Distribute the bottom left resource
        KingOfEthResource(contractFor(resourceType(_x - 1, _y))).interfaceMintTokens(
            _owner
          , _count
        );
    }

    /// @dev Burn the costs necessary to build a road
    /// @param _length The length of the road
    /// @param _player The player who is building the house
    function burnRoadCosts(uint _length, address _player)
        public
        onlyRoadsContract
    {
        // Burn corn
        KingOfEthResource(cornContract).interfaceBurnTokens(
              _player
            , _length
        );

        // Burn ore
        KingOfEthResource(oreContract).interfaceBurnTokens(
              _player
            , _length
        );
    }

    /// @dev The exchange can freeze tokens
    /// @param _type The type of resource
    /// @param _owner The owner of the tokens
    /// @param _tokens The amount of tokens to freeze
    function exchangeFreezeTokens(ResourceType _type, address _owner, uint _tokens)
        public
        onlyExchangeContract
    {
        KingOfEthResource(contractFor(_type)).interfaceFreezeTokens(_owner, _tokens);
    }

    /// @dev The exchange can thaw tokens
    /// @param _type The type of resource
    /// @param _owner The owner of the tokens
    /// @param _tokens The amount of tokens to thaw
    function exchangeThawTokens(ResourceType _type, address _owner, uint _tokens)
        public
        onlyExchangeContract
    {
        KingOfEthResource(contractFor(_type)).interfaceThawTokens(_owner, _tokens);
    }

    /// @dev The exchange can transfer tokens
    /// @param _type The type of resource
    /// @param _from The owner of the tokens
    /// @param _to The new owner of the tokens
    /// @param _tokens The amount of tokens to transfer
    function exchangeTransfer(ResourceType _type, address _from, address _to, uint _tokens)
        public
        onlyExchangeContract
    {
        KingOfEthResource(contractFor(_type)).interfaceTransfer(_from, _to, _tokens);
    }

    /// @dev The exchange can transfer frozend tokens
    /// @param _type The type of resource
    /// @param _from The owner of the tokens
    /// @param _to The new owner of the tokens
    /// @param _tokens The amount of frozen tokens to transfer
    function exchangeFrozenTransfer(ResourceType _type, address _from, address _to, uint _tokens)
        public
        onlyExchangeContract
    {
        KingOfEthResource(contractFor(_type)).interfaceFrozenTransfer(_from, _to, _tokens);
    }
}
