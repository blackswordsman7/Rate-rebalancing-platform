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
import "./LogLibary.sol";

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
    RateSwitcher rateSwitcher;

    //contructor for this Smart Contract
    // @dev retrieves the contract of the LendingPoolAddressesProvider
    constructor() public {
         lpAddressesProvider = LendingPoolAddressesProvider(0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408);
         lendingPool = LendingPool(lpAddressesProvider.getLendingPool());
         lendingPoolCore = LendingPoolCore(lpAddressesProvider.getLendingPoolCore());
         logLib = new Log();
         rateSwitcher = RateSwitcher();
         userAddress = msg.sender();
    }

    struct AdvisorUserReserveData{
        uint256 monthlyPaymentAmount;
        uint256 expectedLoanDuration;
        uint256 earningsCashFlow;
        uint256 spendingCashFlow;
        int512 netCashFlow;
    }

    modifier onlyLocalOwner {
        require(
            msg.sender == userAddress,
            "Only local owner can call this function."
        );
        _;
    }

    // Get User Data
    uint256 totalLiquidityETH;
    uint256 totalCollateralETH;
    uint256 totalBorrowsETH;
    uint256 availableBorrowsETH;
    uint256 currentLiquidationThreshold;
    uint256 ltv;
    uint256 healthFactor;

    //get the values for the User
    (totalLiquidityETH, totalCollateralETH, totalBorrowsETH, availableBorrowsETH, currentLiquidationThreshold, ltv,
        healthFactor) = lendingPool.getUserAccountData(userAddress);

    mapping(address => mapping(address => AdvisorUserReserveData)) advisorUserReserveData;

    //sets the monthly payment amount (still needs to be fixed)
    function setMonthlyPaymentAmount(address _reserve, address _user, uint256 amount) external onlyLocalOwner {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        user.monthlyPaymentAmount = amount;
    }

    //gets the monthly payment amount
    function getMonthlyPaymentAmount()public view returns (uint256) onlyLocalOwner{
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.monthlyPaymentAmount;
    }

    //set the ExepectedLoanDuration
    function setExpectedLoanDuration(address _reserve, address _user) public{
        //Initialize the AdvisorUserReserveData Struct
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];

        //get User Reserve Data
        (,,, uint256 principalBorrowBalance,, uint256 borrowRate,,,,,) = lendingPool.getUserReserveData(reserve, userAddress);

        // utilize 1 and 2) log(M - log(M-PR/12)) and 3) log(1+R/12) then the exepcted loan duration = (2)/(3)
        uint256 paymentAmount = getMonthlyPaymentAmount();
        uint256 interestPayment = (principalBorrowBalance * borrowRate) / 12;
        uint256 part1 = LogLibary.log(paymentAmount - interestPayment);
        uint256 part2 = LogLibrary.log(paymentAmount - part1);
        uint256 part3 = LogLibrary.log(1+(borrowRate/12));
        user.expectedLoanDuration = part2 / part3;
    }

    function getExpectedLoanDuration() public view returns (uint256) onlyLocalOwner{
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.expectedLoanDuration;
    }

    //liquidity rate * currentUnderlyingBalance
    function setEarningsCashFlow(address _reserve, address _user, ) public {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, , ,
        , , uint256 liquidityRate, , , , ) = lendingPool.getUserReserveData(_reserve, _user);
        user.earningsCashFlow = ((currentUnderlyingBalance * liquidityRate) / 12);
    }

    function getEarningsCashFlow() public view returns (uint256) onlyLocalOwner{
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return earningsCashFlow;
    }

    function setSpendingCashFlow() public view returns(uint256){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        (, , uint256 currentBorrowBalance, uint256 principalBorrowBalance,
        , uint256 borrowRate, , , , , ) = lendingPool.getUserReserveData(reserve, userAddress);
        user.spendingCashFlow = ((principalBorrowBalance * borrowRate) / 12);
    }

    function setNetCashFlow()public {
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        user.netCashFlow = earningsCashFlow - spendingCashFlow;
    }

    //still needs testing
    function getNetCashFlow()public view returns(int512) onlyLocalOwner{
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        return user.netCashFlow;
    }

    //get the values for the User
    (totalLiquidityETH, totalCollateralETH, totalBorrowsETH, availableBorrowsETH, currentLiquidationThreshold, ltv,
        healthFactor) = lendingPool.getUserAccountData(userAddress);
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

    function setBestRateStrategy(address _reserve, address _user){
        AdvisorUserReserveData storage user = advisorUserReserveData[_user][_reserve];
        //get User Reserve Data
        (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance,
        uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp,
        bool usageAsCollateralEnabled) = lendingPool.getUserReserveData(reserve, userAddress);
        //
        rateSwitcher.rateSwapIndividual(_reserve, _user);
    }

}
