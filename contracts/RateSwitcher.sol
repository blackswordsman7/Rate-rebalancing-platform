pragma solidity ^0.5.0;

import "../AaveProtocol/aave-protocol/contracts/configuration/LendingPoolAddressesProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPool.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolCore.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolDataProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/libraries/CoreLibrary.sol";
import "../AaveProtocol/aave-protocol/contracts/libraries/WadRayMath.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// RateSwitcher contract will automate the interest rate mode depending on market
// variables. Which are determined by the base interests rates, untilization,
// and rate scaling ratios.
//
contract RateSwitcher is LendingPoolCore, LendingPool, LendingPoolAddressesProvider{

    //@dev Events
    event swapLog(address indexed _user, address indexed _reserve, uint256 _rate, uint256 indexed mode);

    //user address
    address userAddress;

    // Contract initialization
    LendingPoolAddressesProvider public lpAddressesProvider;
    LendingPoolCore lendingPoolCore;
    LendingPool lendingPool;

    //contructor for this Smart Contract
    // @dev retrieves the contract of the LendingPoolAddressesProvider
    constructor(LendingPoolAddressesProvider _LPProviderAddress, address _addressProvider) public {
         lpAddressesProvider = _LPProviderAddress(_addressProvider);
         lendingPool = LendingPool(lpAddressesProvider.getLendingPool());
         lendingPoolCore = LendingPoolCore(lpAddressesProvider.getLendingPoolCore());
    }

    //mappings we need to access from LendingPoolCore.sol
    mapping(address => CoreLibrary.ReserveData) reserves;
    //mapping(address => mapping(address => CoreLibrary.UserReserveData)) usersReserveData;
    mapping(address => mapping(address => CoreLibrary.ReserveData)) usersReserves;

    //gets the list of reserves
    address[] public reservesListLocal = lendingPoolCore.getReserves();

    function rateSwap(address _userAddress, address[] memory reservesListLocal, uint numOfReserves) public{
        //@dev for loop that iterates through every resvere and updates the users borrowRateMode
        // WARN the for loop is currently unbounded
        for(uint i = 0; i < reservesListLocal.length; i++){
            uint256 currentVariableBorrowRate = lendingPool.getReserveCurrentVaraibleBorrowRate(reservesListLocal[i]);
            //uint256 currentFixedBorrowRate = lendingPool.getReserveCurrentFixedBorrowRate(reservesListLocal[i]);
            //uint256 userCurrentFixedBorrowRate = lendingPoolCore.getUserCurrentFixedBorrowRate(reservesListLocal[i], userAddress);
            (,,,uint256 _principalBorrowBalance, uint256 _borrowRateMode,
            uint256 _borrowRate,,,,,) = lendingPool.getUserReserveData(reservesListLocal[i], _userAddress);

            //Conditional to verify that they have are active on this reserve
            if(_principalBorrowBalance > 0){
                //Fixed rate to Variable Rate swap
                if((_borrowRateMode == 0) && (userCurrentFixedBorrowRate > currentVariableBorrowRate)){
                    lendingPool.swapBorrowRateMode(reservesListLocal[]);
                }
                //Variable Rate to Fixed Rate swap
                if((_borrowRateMode == 1) && (currentVariableBorrowRate > userCurrentFixedBorrowRate)){
                    lendingPool.swapBorrowRateMode(reservesListLocal[]);
                }
            }
        }
    }

    //Can add more functionality later


}
