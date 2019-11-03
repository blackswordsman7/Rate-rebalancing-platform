pragma solidity ^0.5.0;

import "../interfaces/IReserveInterestRateStrategy.sol";
import "../libraries/WadRayMath.sol";
import "../configuration/LendingPoolAddressesProvider.sol";
import "./LendingPoolCore.sol";
import "../interfaces/ILendingRateOracle.sol";
import "../libraries/CoreLibrary.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// RateSwitcher contract will automate the interest rate mode depending on market
// variables. Which are determined by the base interests rates, untilization,
// and rate scaling ratios.
//
contract RateSwitcher is LendingPoolCore, LendingPoolAddressesProvider{

    //user address
    address userAddress;
    //the lending pool address
    address lendingPool;

    // LendingPoolAddressesProvider object
    LendingPoolAddressesProvider public lpAddressesProvider;

    //contructor for this Smart Contract
    // @dev retrieves the address of the LendingPoolAddressesProvider
    constructor(address _LPProviderAddress) public {
         lpAddressesProvider = _LPProviderAddress;
    }

    //retrieves the lendingPoolCore address
    address _lendingPoolCore = lpAddressesProvider.getLendingPoolCore();
    //obtain the CoreLibrary address

    // LendingPoolCore object
    LendingPoolCore lendingPoolCore = LendingPoolCore(_lendingPoolCore);

    //mappings we need to access from LendingPoolCore.sol
    //mapping(address => CoreLibrary.ReserveData) reserves;
    //mapping(address => mapping(address => CoreLibrary.UserReserveData)) usersReserveData;
    //address[] public reservesList;

}
