// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/vendor/SafeMathChainlink.sol";

//Contract to accept some type of payment, gets ETH<>USD conversion rate from chainlink Testnet
contract FundMe {
    using SafeMathChainlink for uint256; //checks for overflows - not needed for sol > 0.8

    mapping(address => uint256) public addressToAmountFunded; //address of person sending funds
    address[] public funders;
    address public owner;
    AggregatorV3Interface public priceFeed;

    //when we deploy this contract (FundMe.sol) we're the owner immediately
    constructor(address _priceFeed) public {
        priceFeed = AggregatorV3Interface(_priceFeed);
        owner = msg.sender;
    }

    //allows anyone to funds, with a min USD value
    function fund() public payable {
        uint256 minimumUSD = 50 * 10**18; //minimum amt to be funded into the contract (in Wei)
        require(
            getConversionRate(msg.value) >= minimumUSD,
            "You need to spend more ETH!"
        ); //if they dont send us enough, we kick them out!
        addressToAmountFunded[msg.sender] += msg.value;
        //msg.sender = sender of the function call
        //msg.value = how much they sent
        // what the ETH -> USD conversion
        // if we send 1 gwei (which is less than $50) we should kick them out
        funders.push(msg.sender); //whenever someone funds the acct we add the address to the funders[]
    }

    //get the version of the oracle(API) of chainlink
    function getVersion() public view returns (uint256) {
        return priceFeed.version();
    }

    //get the price of ETH in terms of USD - expressed as 3771949262880000000000 => divide by 10**18 to get $3771.949262880000000000 USD
    function getPrice() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData(); // (,int256 answer,,,) commas ignoring the other return values from AggregatorV3Interface.latestRoundData()
        return uint256(answer * 10000000000);
    }

    //we can convert what they send us to see if it's the right amount
    function getConversionRate(uint256 ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        return ethAmountInUsd;
    }

    function getEntranceFee() public view returns (uint256) {
        // mimimumUSD
        uint256 mimimumUSD = 50 * 10**18;
        uint256 price = getPrice();
        uint256 precision = 1 * 10**18;
        return (mimimumUSD * precision) / price;
    }

    //onlyOwner modifier so that we're the only ones that can withdraw from the account
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function withdraw() public payable onlyOwner {
        msg.sender.transfer(address(this).balance); //this sender (caller of the withdraw function) transfers the balance

        //reset each funders balance to 0 after the withdrawal
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0); // reset the funders[] array
    }
}
