pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../AaveProtocol/aave-protocol/contracts/configuration/LendingPoolAddressesProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPool.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolCore.sol";
import "../AaveProtocol/aave-protocol/contracts/lendingpool/LendingPoolDataProvider.sol";
import "../AaveProtocol/aave-protocol/contracts/libraries/CoreLibrary.sol";
import "../AaveProtocol/aave-protocol/contracts/libraries/WadRayMath.sol";
import "../AaveProtocol/aave-protocol/contracts/configuration/AddressStorage.sol";
import "../AaveProtocol/aave-protocol/contracts/interfaces/ILendingPoolAddressesProvider.sol";

import "./RateSwitcher.sol";
import { LogLibrary } from "./LogLibrary.sol";

contract RateAdvisorPlatform is Ownable{
    using SafeMath for uint256;
    using WadRayMath for uint256;
    using Address for address payable;

    // A platform can define a user's financial profile based on assets supplied, collateralization, expected loan duration,
    // payback strategy... and provide advice about the best loan strategy and best rate mode fit
    //user address
    address userAddress;

    // Contract initialization
    LendingPoolAddressesProvider public lpAddressesProvider;
    LendingPoolCore lendingPoolCore;
    LendingPool lendingPool;
    LogLibrary logLib;

    //contructor for this Smart Contract
    // @dev retrieves the contract of the LendingPoolAddressesProvider
    constructor() public {
         lpAddressesProvider = LendingPoolAddressesProvider(0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408);
         lendingPool = LendingPool(lpAddressesProvider.getLendingPool());
         lendingPoolCore = LendingPoolCore(lpAddressesProvider.getLendingPoolCore());
         userAddress = msg.sender;
    }

    struct AdvisorUserReserveData {
        uint256 monthlyPaymentAmount;
        int256 expectedLoanDuration;
        uint256 earningsCashFlow;
        uint256 spendingCashFlow;
        int256 netCashFlow;
    }

    modifier onlyLocalOwner {
        require(
            msg.sender == userAddress,
            "Only local owner can call this function."
        );
        _;
    }

    //get the values for the User
    /*
    (uint256 totalLiquidityETH, uint256 totalCollateralETH, uint256 totalBorrowsETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv,
    uint256 healthFactor) = lendingPool.getUserAccountData(userAddress);
    uint256 availableBorrowsETH = lendingPool.getUserAccountData(userAddress);*/

    /*
    (uint256 _totalLiquidityETH, uint256 _totalCollateralETH, uint256 _totalBorrowsETH, uint256 _availableBorrowsETH, uint256 _currentLiquidationThreshold, uint256 _ltv, uint256 _healthFactor) = lendingPool.getUserAccountData(userAddress);
*/
    mapping(address => mapping(address => AdvisorUserReserveData)) advisorUserReserveData;

    //sets the monthly payment amount (still needs to be fixed)
    function setMonthlyPaymentAmount(address _reserve, address _user, uint256 _amount) external onlyLocalOwner {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        user.monthlyPaymentAmount = _amount;
    }

    //gets the monthly payment amount
    function getMonthlyPaymentAmount(address _reserve, address _user)public view returns(uint256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.monthlyPaymentAmount;
    }

    //set the ExepectedLoanDuration
    function setExpectedLoanDuration(address _reserve, address _user) public{
        //Initialize the AdvisorUserReserveData Struct
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];

        //get User Reserve Data
        (,,, uint256 principalBorrowBalance,, uint256 borrowRate,,,,,) = lendingPool.getUserReserveData(_reserve, userAddress);

        // utilize 1 and 2) log(M - log(M-PR/12)) and 3) log(1+R/12) then the exepcted loan duration = (2)/(3)
        uint256 paymentAmount = getMonthlyPaymentAmount(_reserve, _user);
        uint256 interestPayment = (principalBorrowBalance.mul(borrowRate)).div(12);
        uint256 input = paymentAmount.sub(interestPayment);
        uint256 input2 = uint256(1).add((borrowRate.div(12)));
        int256 part1 = LogLibrary.log_2(input);
        int256 part2 = LogLibrary.log_2(paymentAmount - uint256(part1));
        int256 part3 = LogLibrary.log_2(input2);
        user.expectedLoanDuration = part2 / part3;
    }

    function getExpectedLoanDuration(address _reserve, address _user) public view returns (int256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.expectedLoanDuration;
    }

    //liquidity rate * currentUnderlyingBalance
    function setEarningsCashFlow(address _reserve, address _user) public {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        (, uint256 currentUnderlyingBalance, , ,
        , , uint256 liquidityRate, , , , ) = lendingPool.getUserReserveData(_reserve, _user);
        user.earningsCashFlow = ((currentUnderlyingBalance.mul(liquidityRate)).div(12));
    }

    function getEarningsCashFlow(address _reserve, address _user) public view returns (uint256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.earningsCashFlow;
    }

    function setSpendingCashFlow(address _reserve, address _user) public {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        (, , , uint256 principalBorrowBalance,
        , uint256 borrowRate, , , , , ) = lendingPool.getUserReserveData(_reserve, userAddress);
        user.spendingCashFlow = ((principalBorrowBalance.mul(borrowRate)).div(12));
    }

    function getSpendingCashFlow(address _reserve, address _user) public view returns (uint256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.spendingCashFlow;
    }

    function setNetCashFlow(address _reserve, address _user)public {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        user.netCashFlow = int256(user.earningsCashFlow) - int256(user.spendingCashFlow);
    }

    //still needs testing
    function getNetCashFlow(address _reserve, address _user)public view returns(int256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.netCashFlow;
    }

    /*
    //get User Reserve Data
    (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance,
    uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp,
    bool usageAsCollateralEnabled) = lendingPool.getUserReserveData(reserve, userAddress);

    function payBackStrategy(address _reserve, address _user) return (){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        //if the health factor is low, the netCashFlow is negative, and you have some money then you have to make payments
        if((healthFactor>=1) && (healthFactor<1.25)){
            if()
            //if the health factor is low, the netCashFlow is negative, and you dont have money then you have to liquidate
        }
        //Medium Health Factor
        if((healthFactor>=1.25) && (healthFactor<1.75)){
            if()
        }
        //if the health factor is in good standing, the netCashFlow is positive, then you can desosit more into the reserve
        // (no payment necessary)
        else{

        }

        //if
    }*/

    // should find the best rate strategy for all Reserves, even if the user doesnt
    // have an investments in it. This should be based off the stable APR and variable APR
    // as well as the offered Monthly payment, prinicpal balance, and expected loan duration
    // Basically find the method that gives them the most profit for their profile type.
    /*function setBestRateStrategy(address _reserve, address _user) public{
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        //get User Reserve Data
        (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance,
        uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp,
        bool usageAsCollateralEnabled) = lendingPool.getUserReserveData(_reserve, _user);
    }*/

}
