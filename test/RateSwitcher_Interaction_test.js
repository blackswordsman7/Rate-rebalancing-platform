
const RateSwitcher = artifacts.require("RateSwitcher");
const LendingPool = artifacts.require("LendingPool");
const LendingPoolCore = artifacts.require("LendingPoolCore");
const LendingPoolAddressesProvider = artifacts.require("LendingPoolAddressesProvider");


const {waitForEvent, expectRevert} = require('./utils');

///initialize web3 object

const Web3 = require('web3');
//var web3 = new Web3("https://kovan.infura.io/v3/344452915ed54c76a762b0eee4b66060");
//Websockets Keeps timing out :(
var web3 = new Web3(new Web3.providers.WebsocketProvider("wss://kovan.infura.io/ws/v3/344452915ed54c76a762b0eee4b66060"));

const lendingPoolAddressesProviderAddress = '0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408';

const lendingPoolAddressessProv = new web3.eth.Contract(LendingPoolAddressesProvider.abi, lendingPoolAddressesProviderAddress);

const lendingPoolAddress = lendingPoolAddressessProv.methods.getLendingPool();
const lendingPoolProv = new web3.eth.Contract(LendingPool.abi, lendingPoolAddress);

const lendingPoolCoreAddress = lendingPoolAddressessProv.methods.getLendingPoolCore();
const lendingPoolCoreProv = new web3.eth.Contract(LendingPoolCore.abi, lendingPoolCoreAddress);

//const myAddress = '0xa3e1c2602f628112E591A10094bbD59BDC3cb512';

beforeEach('Define the _deployer, _user, and Accounts', async () => {
    const accounts = await web3.eth.getAccounts();
    const _user = '0xa3e1c2602f628112E591A10094bbD59BDC3cb512';
    done();
})
const _user = '0xa3e1c2602f628112E591A10094bbD59BDC3cb512';

contract('RateSwitcher', (_user, accounts) => {

    describe('Caller-pays-for-query tests', () => {
      let contractEvents;
      let contractMethods;
      let contractAddress;
      let contractQueryPrice;
      let contractEthPriceInUSDString;

      const gasPrice = 20e9;
      const gasLimit = 20e6;

      it('Should get contract methods & events', async () => {
        const deployedContract = await RateSwitcher.deployed();
        const rateSwitcher = new web3.eth.Contract(deployedContract.abi, deployedContract.address);
        contractEvents = rateSwitcher.events;
        contractMethods = rateSwitcher.methods;
        contractAddress = await deployedContract._address;
        done()
      })

      it('Should be able to call `queryPrice` public getter', async () => {
        const queryPrice = await contractMethods
          .queryPrice()
          .call()
        contractQueryPrice = parseInt(queryPrice)
        done()
      })

      it('Contract balance should be 0', async () => {
        const contractBalance = await web3.eth.getBalance(contractAddress)
        assert.isTrue(parseInt(contractBalance) === 0)
        done()
      })

      it('Query price should be > 0', () => {
        assert.isTrue(contractQueryPrice > 0)
        done()
      })

      it('User cannot make query if msg.value === 0', async () => {
        await expectRevert(
          contractMethods
            .getEthPriceInUSDViaProvable()
            .send({
              value: 0,
              from: _user,
              gas: gasLimit,
              gasPrice: gasPrice
            })
        )
        done()
      })

      it('User cannot make query if msg.value < query cost', async () => {
        await expectRevert(
          contractMethods
            .getEthPriceInUSDViaProvable()
            .send({
              value: contractQueryPrice - 1,
              from: _user,
              gas: gasLimit,
              gasPrice: gasPrice
            })
        )
        done()
      })

      it('User can make query if msg.value === query cost', () => {
        contractMethods
          .getEthPriceInUSDViaProvable()
          .send({
            value: contractQueryPrice,
            from: _user,
            gas: gasLimit,
            gasPrice: gasPrice
          })
         done()
      })

      it('Query should have emitted event with ETH price in USD', async () => {
        const event = await waitForEvent(contractEvents.LogPriceUpdated)
        contractEthPriceInUSDString = event.returnValues._price
        if(contractEthPriceInUSDString){
            done(true)
        }
        else{
            done()
        }
      })

      it('Eth price in USD should be saved in contract', async () => {
        const ethPriceInUSDString = await contractMethods
          .ethPriceInUSD()
          .call()
        assert.isTrue(parseInt(ethPriceInUSDString) > 0)
        assert.strictEqual(
          ethPriceInUSDString,
          contractEthPriceInUSDString
        )
        done()
      })

      it('User should get refund when making query but sending > query cost', async () => {
        const overspendAmount = contractQueryPrice * 2
        const balanceBeforeBN = web3.utils.toBN(await web3.eth.getBalance(_user))
        const { gasUsed } = await contractMethods
          .getEthPriceInUSDViaProvable()
          .send({
            from: _user,
            gas: gasLimit,
            gasPrice: gasPrice,
            value: overspendAmount
          })
        const balanceAfterBN = web3.utils.toBN(await web3.eth.getBalance(_user))
        const totalGasCostBN = web3.utils.toBN(gasUsed).mul(web3.utils.toBN(gasPrice))
        const balanceDeltaBN = balanceBeforeBN.sub(balanceAfterBN)
        const expectedDeltaBN = web3.utils.toBN(contractQueryPrice).add(totalGasCostBN)
        assert.isTrue(expectedDeltaBN.eq(balanceDeltaBN))
        done()
      })
    })

    describe('Rate Swapper works', ()=>{
        let instance;
        beforeEach('beforeEachTest', async()=>{
            instance = await RateSwitcher.deployed();
        })
        it('should have a deployed contract and initialized the Contract Abstractions', async()=>{
            let lpcValue = await instance.testLendingPoolCoreAbstraction('0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD', {from:account[0]});
            let lpcValue2 = await lendingPoolCoreProv.methods.getReserveCurrentVariableBorrowRate('0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD').call({from: account[0]});
            assert.equal(lpcValue.toNumber(),lpcValue2.toNumber());
        })
        it('should swap the interest rates', async()=>{
            let _daiReserve = '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD'
            let {_borrowRateMode, _borrowRate} = lendingPool.getUserReserveData(_daiReserve, account[0].address).call{fomr:account[0]};
            instance.rateSwapIndividual(_daiReserve, accouont[0].address);
        })

    })


})
*/
