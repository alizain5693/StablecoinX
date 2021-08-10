// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @dev what does address(this) contract do?
//  - It should be able to deposit and withdraw tokens from Idle
//  - It should be able to balance the correct ratio - stored in the mapping
//  - It should allow the funds handler contract to withdraw and deposit tokens
//  - It should be able to show the correct balance for each token, with interest, and without, as 
//    well as the earned interest
//  - It should allow the funds handler to update the mapping, so it withdraws everything it can, and 
//    deposits the correct amount according to the new ratio


// SO FAR:
//  - The initial code is there but is not tested
//  - There is no swapping mechanism
//  - How can we trigger the rebalance every X blocks?
//  - It copmiles but needs to be tested and need to add safemath to the code,
//    b/c i realized after compiling that solidity does not allow for negetive numbers
//    so we need to look at difference, "differently" and change match ratios accordingly



import './interfaces/IIdleToken.sol';
import './interfaces/IERC20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";


contract IdleConnector is Ownable{

    uint256 totalBalance;
    // @dev define wethereum token addresses
    address daiAddresss = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address wbtcAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // @dev erc20 token instances
    IERC20 dai = IERC20(daiAddresss);
    IERC20 weth = IERC20(wethAddress);
    IERC20 usdc = IERC20(usdcAddress);
    IERC20 usdt = IERC20(usdtAddress);
    IERC20 wbtc = IERC20(wbtcAddress);
    // @dev put all tokens in an array
    IERC20[] tokens = [dai, weth, usdc, usdt, wbtc];
    // @dev define idle connector addresses
    address daiConnectorAddress;
    address wethConnectorAddress;
    address usdcConnectorAddress;
    address usdtConnectorAddress;
    address wbtcConnectorAddress;
    // @dev put all addreses in an array
    address[] connectorAddresses = [daiConnectorAddress, wethConnectorAddress, usdcConnectorAddress, usdtConnectorAddress, wbtcConnectorAddress];

    // @dev create instances of IIdleTokens.sol for each contract address
    IIdleToken idleDAI = IIdleToken(daiConnectorAddress);
    IIdleToken idleWETH = IIdleToken(wethConnectorAddress);
    IIdleToken idleUSDC = IIdleToken(usdcConnectorAddress);
    IIdleToken idleUSDT = IIdleToken(usdtConnectorAddress);
    IIdleToken idleWBTC = IIdleToken(wbtcConnectorAddress);
    // @dev put all idle tokens in an array
    IIdleToken[] idleTokens = [idleDAI, idleWETH, idleUSDC, idleUSDT, idleWBTC];


    // @dev the mapping of addressees to their ratio
    mapping(address => uint256) ratios;
    // @dev the mapping of addresses to the amount of tokens they have
    mapping(address => uint256) rawBalances;
    // @dev mapping of idletoken balances
    mapping(address => uint256) idleBalances;
    // @dev the mapping of addresses to the amount of interest they have
    mapping(address => uint256) interest;


    // @dev constructor
    constructor(uint256 [] memory inital) {
        // @dev set initial ratio for connector addresses
        ratios[daiConnectorAddress] = inital[0];
        ratios[wethConnectorAddress] = inital[1];
        ratios[usdcConnectorAddress] = inital[2];
        ratios[usdtConnectorAddress] = inital[3];
        ratios[wbtcConnectorAddress] = inital[4];
        // @dev define funds handler address as owner
        address owner = address(msg.sender);// update later
    }

    // @dev function that updates the ratio for all connector addresses
    function updateRatio(uint256[] memory newratios) public onlyOwner{
        // @dev set the ratios for all connector addresses
        ratios[daiConnectorAddress] = newratios[0];
        ratios[wethConnectorAddress] = newratios[1];
        ratios[usdcConnectorAddress] = newratios[2];
        ratios[usdtConnectorAddress] = newratios[3];
        ratios[wbtcConnectorAddress] = newratios[4];
    }

    

    // @dev function that allows deposits into idle(basically mints idle tokens)
    function depositIdle(IERC20 token, IIdleToken _connector, address _connectorAddress, uint256 _tokens) private{
        token.approve(_connectorAddress, _tokens);
        _connector.mintIdleToken(_tokens, true, address(this));//not sure if skip rebalance is needed, also is address(this) okay for referral?
    }

    // @dev function that allows withdraws from idle(basically converts idle tokens to real tokens)
    function withdrawIdle(IIdleToken _connector, uint256 _idleTokens) private{
        _connector.redeemIdleToken(_idleTokens);
    }

    // Q: Do we need a function to allow the funds handler to deposit tokens?
    // @dev function that allows the funds handler to deposit tokens
    function deposit() payable public{}

    // @dev function that allows user to withdraw tokens from address(this) contract
    function withdraw(IERC20 token, uint256 _tokens) public onlyOwner {
        token.approve(msg.sender, _tokens);
        //need logic to check we have enough tokens to withdraw
        // and if we do we withdraw, otherwise we try to see if 
        // we have enough in other idle contracts to withdraw
        // if then we don't, we throw an error
        token.transfer(msg.sender, _tokens);
    }


    //@dev function that updates the idle balances for all addresses
    function updateIdleBalances() private{
        // @dev set the idle balances for all addresses
        idleBalances[daiConnectorAddress] = idleDAI.balanceOf(address(this));
        idleBalances[wethConnectorAddress] = idleWETH.balanceOf(address(this));
        idleBalances[usdcConnectorAddress] = idleUSDC.balanceOf(address(this));
        idleBalances[usdtConnectorAddress] = idleUSDT.balanceOf(address(this));
        idleBalances[wbtcConnectorAddress] = idleWBTC.balanceOf(address(this));
    }

    //@dev function that udpdates earned interest for all addresses
    function updateInterest() private{
        // @dev set the interest for all addresses
        interest[daiConnectorAddress] = idleBalances[daiConnectorAddress]*(idleDAI.tokenPriceWithFee(address(this)) - idleDAI.userAvgPrices(address(this)));
        interest[wethConnectorAddress] = idleBalances[wethConnectorAddress]*(idleWETH.tokenPriceWithFee(address(this)) - idleWETH.userAvgPrices(address(this)));
        interest[usdcConnectorAddress] = idleBalances[usdcConnectorAddress]*(idleUSDC.tokenPriceWithFee(address(this)) - idleUSDC.userAvgPrices(address(this)));
        interest[usdtConnectorAddress] = idleBalances[usdtConnectorAddress]*(idleUSDT.tokenPriceWithFee(address(this)) - idleUSDT.userAvgPrices(address(this)));
        interest[wbtcConnectorAddress] = idleBalances[wbtcConnectorAddress]*(idleWBTC.tokenPriceWithFee(address(this)) - idleWBTC.userAvgPrices(address(this)));
    }
    //@dev function that updates raw balances for all addresses
    function updateRawBalances() private{
        // @dev set the raw balances for all addresses
        rawBalances[daiConnectorAddress] = idleBalances[daiConnectorAddress]*idleDAI.tokenPriceWithFee(address(this));
        rawBalances[wethConnectorAddress] = idleBalances[wethConnectorAddress]*idleWETH.tokenPriceWithFee(address(this));
        rawBalances[usdcConnectorAddress] = idleBalances[usdcConnectorAddress]*idleUSDC.tokenPriceWithFee(address(this));
        rawBalances[usdtConnectorAddress] = idleBalances[usdtConnectorAddress]*idleUSDT.tokenPriceWithFee(address(this));
        rawBalances[wbtcConnectorAddress] = idleBalances[wbtcConnectorAddress]*idleWBTC.tokenPriceWithFee(address(this));
        //@dev define total balance as sum of raw balances
        totalBalance = rawBalances[daiConnectorAddress] + rawBalances[wethConnectorAddress] + rawBalances[usdcConnectorAddress] + rawBalances[usdtConnectorAddress] + rawBalances[wbtcConnectorAddress];
    }

    //@dev helper function ratio matcher
    function ratioMatcher(address _connectorAddress) private returns (uint256, uint16){
        if (rawBalances[_connectorAddress]!=ratios[_connectorAddress]*totalBalance) {
            // @dev if the ratio is not the same, then we need to rebalance
            // @dev calculate the difference between the raw balance and the ratio*total balance
            if(rawBalances[_connectorAddress]>ratios[_connectorAddress]*totalBalance) {
                uint256 difference = rawBalances[_connectorAddress] - (ratios[_connectorAddress]*totalBalance);
                // @dev return difference and the number denoting excess or shortage
                return (difference,1);
            }
            else (rawBalances[_connectorAddress]<ratios[_connectorAddress]*totalBalance) {
                uint256 difference = (ratios[_connectorAddress]*totalBalance) - rawBalances[_connectorAddress];
                // @dev return difference and the number denoting excess or shortage
                return (difference,2);
            }
        }
        else {
            // @dev if the ratio is the same, then we don't need to rebalance
            return (0,0);
        }

    }


    // @dev function that rebalances the idle tokens to have correct ratios
    function rebalance() private{
        //@dev check each of the addresses to see if their raw balance to total balance ratio is
        // the same as the ratio for that address
        // if not, then we need to rebalance
        
        // @dev differences from ideal ratio
        // mapping(address => uint256) memory diffs;
        // @dev differences from ideal ratio array
        uint256 [2][] memory  diffs;
        // @dev loop through all the addresses
        for (uint256 i = 0; i < connectorAddresses.length; i++) {
            diffs[i] = ratioMatcher(connectorAddresses[i]);
        }



        // @dev check the mapping for each address to see if the difference is positive or negative
        // loop through connecter addresses
        //first withdraw excess tokens from idle tokens
        for(uint i =0 ; i<connectorAddresses.length; i++){
            // @dev if the difference is positive, then we need to rebalance
            if(diffs[i][1] == 1){
                withdrawIdle(idleTokens[i], diffs[i][0]);
            }
        }
        //then deposit tokens to idle tokens
        for(uint i =0 ; i<connectorAddresses.length; i++){
            // @dev if the difference is negative, then we need to rebalance
            // @dev for now we will just leave it as is and will have to add a mechanism for
            // swapping tokens later

            if(diffs[i][1] ==2){
                depositIdle(tokens[i],idleTokens[i], connectorAddresses[i], diffs[i][0]);
            }
        }
               
    }






} 