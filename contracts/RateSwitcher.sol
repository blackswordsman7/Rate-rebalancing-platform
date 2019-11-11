pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../AaveProtocol/aave-protocol/contracts/configuration/LendingPoolAddressesProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPool.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolCore.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolDataProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/libraries/CoreLibrary.sol";
import "../AaveProtocol/aave-protocol/contracts/configuration/AddressStorage.sol";
import "../AaveProtocol/aave-protocol/contracts/interfaces/ILendingPoolAddressesProvider.sol";

import "./provableAPI.sol";


// RateSwitcher contract will automate the interest rate mode depending on market
// variables. Which are determined by the base interests rates, untilization,
// and rate scaling ratios.
//()
contract RateSwitcher is UsingProvable, Ownable{

    //@dev Events
    event SwapLog(address indexed _user, address indexed _reserve, uint256 _rate);
    event LogConstructorInitiated(string nextStep);
    event LogPriceUpdated(string price);
    event LogNewProvableQuery(string description);

    //user address
    address userAddress;

    // Contract initialization
    LendingPoolAddressesProvider public lpAddressesProvider;
    LendingPoolCore lendingPoolCore;
    LendingPool lendingPool;

    //contructor for this Smart Contract
    // @dev retrieves the contract of the LendingPoolAddressesProvider
    constructor() public {
         lpAddressesProvider = LendingPoolAddressesProvider(0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408);
         lendingPool = LendingPool(lpAddressesProvider.getLendingPool());
         lendingPoolCore = LendingPoolCore(lpAddressesProvider.getLendingPoolCore());
         emit LogConstructorInitiated("Constructor was initiated. Call 'rateSwap()' to send the Provable Query.");
    }

    //provable callback function
    function __callback(bytes32 myid, string result) {
       if (msg.sender != provable_cbAddress()) revert();
       //
       emit LogPriceUpdated(result);
       updateInterestRate();
   }

    function rateSwapIndividual(address _reserve) internal payable{
         uint256 currentVariableBorrowRate = lendingPoolCore.getReserveCurrentVariableBorrowRate(_reserve);
         uint256 userCurrentFixedBorrowRate = lendingPoolCore.getUserCurrentFixedBorrowRate(_reserve, msg.sender);
         (,,,uint256 _principalBorrowBalance, uint256 _borrowRateMode,
         uint256 _borrowRate,,,,,) = lendingPool.getUserReserveData(_reserve, msg.sender);

         //Conditional to verify that they have are active on this reserve
         if(_principalBorrowBalance > 0){
             //Fixed rate to Variable Rate swap
             if((_borrowRateMode == 0) && (_borrowRate > currentVariableBorrowRate)) {
                 lendingPool.swapBorrowRateMode(_reserve);
                 emit SwapLog(msg.sender, _reserve, currentVariableBorrowRate);
             }
             //Variable Rate to Fixed Rate swap
             if((_borrowRateMode == 1) && (_borrowRate > userCurrentFixedBorrowRate)){
                 lendingPool.swapBorrowRateMode(_reserve);
                 emit SwapLog(msg.sender, _reserve, userCurrentFixedBorrowRate);
             }
         }
    }

    function rateSwapAll() external payable{
        //gets the list of reserves
        address[] memory reservesListLocal = lendingPool.getReserves();
        //@dev for loop that iterates through every resvere and updates the users borrowRateMode
        // WARN the for loop is currently unbounded
        for(uint i = 0; i < reservesListLocal.length; i++){
            uint256 currentVariableBorrowRate = lendingPoolCore.getReserveCurrentVariableBorrowRate(reservesListLocal[i]);
            //uint256 currentFixedBorrowRate = lendingPool.getReserveCurrentFixedBorrowRate(reservesListLocal[i]);
            uint256 userCurrentFixedBorrowRate = lendingPoolCore.getUserCurrentFixedBorrowRate(reservesListLocal[i], _userAddress);
            (,,,uint256 _principalBorrowBalance, uint256 _borrowRateMode,
            uint256 _borrowRate,,,,,) = lendingPool.getUserReserveData(reservesListLocal[i], _userAddress);

            //Conditional to verify that they have are active on this reserve
            if(_principalBorrowBalance > 0){
                //Fixed rate to Variable Rate swap
                if((_borrowRateMode == 0) && (_borrowRate > currentVariableBorrowRate)) {
                    lendingPool.swapBorrowRateMode(reservesListLocal[i]);
                    emit SwapLog(_userAddress, reservesListLocal[i], currentVariableBorrowRate);
                }
                //Variable Rate to Fixed Rate swap
                if((_borrowRateMode == 1) && (_borrowRate > userCurrentFixedBorrowRate)){
                    lendingPool.swapBorrowRateMode(reservesListLocal[i]);
                    emit SwapLog(_userAddress, reservesListLocal[i], userCurrentFixedBorrowRate);
                }
            }
        }
    } //end of rateSwap function

    function updateInterestRates() payable{
        if (provable_getPrice("URL") > this.balance) {
           emit LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query fee");
       }
       else{
           emit LogNewProvableQuery("Provable query was sent, standing by for the answer..");
           //get results 30 seconds from now
           provable_query(30, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0");
           rateSwapAll();
       }
    }
}
