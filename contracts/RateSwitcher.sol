
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
contract RateSwitcher is usingProvable, Ownable{

    //@dev Events
    event SwapLog(address indexed _user, address indexed _reserve, uint256 _rate);
    event LogConstructorInitiated(string nextStep);
    event LogPriceUpdated(string price);
    event LogNewProvableQuery(string description);

    //user address
    address userAddress;

    string datasource = "URL";
    uint256 public queryPrice;
    string public ethPriceInUSD;

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

         provable_setCustomGasPrice(21 * 10 ** 9);
         queryPrice = provable_getPrice(datasource);
         emit LogConstructorInitiated("Constructor was initiated. Call 'getEthPriceInUSDViaProvable()' to send the Provable Query.");
    }

    function testLendingPoolAbstraction(address _reserve) public view returns (uint256){
        uint256 currentFixedBorrowRate = lendingPoolCore.getReserveCurrentFixedBorrowRate(_reserve);
        return currentFixedBorrowRate;
    }

    function testLendingPoolCoreAbstraction(address _reserve) public view returns (uint256){
        uint256 currentVariableBorrowRate = lendingPoolCore.getReserveCurrentVariableBorrowRate(_reserve);
        return currentVariableBorrowRate;
    }

    function testGetUserReserveData(address _reserve, address _user) public view returns (uint256, uint256){
        (, , , ,
        uint256 borrowRateMode, uint256 borrowRate, , , , ,) = lendingPool.getUserReserveData(_reserve, _user);

        return (borrowRateMode, borrowRate);
    }

    mapping (bytes32 => bool) public pendingQueries;

    //provable callback function
    function __callback(bytes32 _myid, string memory _result,  bytes memory _proof) public {
       require(msg.sender == provable_cbAddress());
       require(pendingQueries[_myid]==true);
       ethPriceInUSD = _result;
       emit LogPriceUpdated(ethPriceInUSD);
       getEthPriceInUSDViaProvable();
   }

    function rateSwapIndividual(address _reserve) public {
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

    function rateSwapAll(address _userAddress) public {
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

            uint256 variableRateDue = (currentVariableBorrowRate.div(12)).mul(_principalBorrowBalance);
            uint256 stableRateDue = (userCurrentFixedBorrowRate.div(12)).mul(_principalBorrowBalance);

            //Conditional to verify that they have are active on this reserve
            if(_principalBorrowBalance > 0){
                //Fixed rate to Variable Rate swap
                if((_borrowRateMode == 0) && (_borrowRate > currentVariableBorrowRate)) {
                    uint256 savedAmount = stableRateDue.sub(variableRateDue);
                    if(saveAmount > (_principalBorrowBalance.mul(0.05))){
                        lendingPool.swapBorrowRateMode(reservesListLocal[i]);
                        emit SwapLog(_userAddress, reservesListLocal[i], currentVariableBorrowRate);
                    }
                }
                //Variable Rate to Fixed Rate swap
                if((_borrowRateMode == 1) && (_borrowRate > userCurrentFixedBorrowRate)){
                    uint256 savedAmount = variableRateDue.sub(stableRateDue);
                    if(saveAmount > (_principalBorrowBalance.mul(0.05))){
                        lendingPool.swapBorrowRateMode(reservesListLocal[i]);
                        emit SwapLog(_userAddress, reservesListLocal[i], userCurrentFixedBorrowRate);
                    }
                }
            }
        }
    } //end of rateSwap function

    function getEthPriceInUSDViaProvable() public payable{
        require(queryPrice > 0);
        userAddress = msg.sender;
        if ((msg.value >= queryPrice)) {
             msg.sender.transfer(msg.value - queryPrice);
             //get results 180 seconds from now
             bytes32 queryId = provable_query(180, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0");
             pendingQueries[queryId] = true;
             //after the query, call rate swap all to optimize al the reserve interest rates
             rateSwapAll(userAddress);
             emit LogNewProvableQuery("Rate Swap hss been initiated and the provable query was sent, standing by for the answer..");
         }
         else{
             emit LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query/optimization fee");
         }
    }
}
