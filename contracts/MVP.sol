pragma solidity ^0.8.0;

import './interfaces/IIdleToken.sol';
import './interfaces/IERC20.sol';


contract MVP {
    address owner;
    constructor(){
        owner = msg.sender;
    }

    //adresses of the contracts
    address public daiAddress = 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa;
    address public usdcAddress = 0x7079f3762805CFf9C979a5bDC6f5648bCFEE76C8;
    address public idleDaiAddress = 0x295CA5bC5153698162dDbcE5dF50E436a58BA21e;
    address public idleUsdcAddress = 0x0de23D3bc385a74E2196cfE827C8a640B8774B9f;
    //create erc20 and idle tokens
    IERC20 dai = IERC20(daiAddress);
    IERC20 usdc = IERC20(usdcAddress);
    IIdleToken idleDai = IIdleToken(idleDaiAddress);
    IIdleToken idleUsdc = IIdleToken(idleUsdcAddress);

    //things to keep track of
    uint256 public tvl;
    mapping(address=>uint256) public individualTvl;
    uint256 public totalDai;
    uint256 public totalUsdc;
    uint256 public daiPerc;
    uint256 public usdcPerc;

    //Transfer event
    event Transfer(address from, address to, uint256 amount);

    
    //random payable func to give contract ether
    function payme() payable public{
        //nothing to do
    }

    //deposit usdc and dai
    //depositDAI
    function depositDAI(uint256 amount) public payable{
        //do approval and transfer
        require(dai.balanceOf(msg.sender) >= amount);
        dai.transferFrom(msg.sender, address(this) , amount);
        emit Transfer(msg.sender,address(this), amount);
        //update values
        tvl += amount;
        individualTvl[msg.sender] += amount;
        totalDai += amount;
        //deposit into idle 
        dai.approve(idleDaiAddress, amount);
        idleDai.mintIdleToken(amount, false, address(this));
    }    
    //depositUSDC
    function depositUSDC(uint256 amount) public payable{
        require(usdc.balanceOf(msg.sender) >= amount);
        usdc.transferFrom(msg.sender, address(this) , amount);
        emit Transfer(msg.sender,address(this), amount);
        //update values
        tvl += amount;
        individualTvl[msg.sender] += amount;
        totalUsdc += amount;
        //deposit into idle
        usdc.approve(idleUsdcAddress, amount);
        idleUsdc.mintIdleToken(amount, false, address(this));
    }

    //withdraw value
    function withdraw(uint256 amount) public{
        require(amount <= tvl);
        require(amount <= individualTvl[msg.sender]);
        //get up to date percs
        daiPerc = (totalDai*100) / tvl;
        usdcPerc = (totalUsdc*100) / tvl;
        //get withdrawal value
        uint256 daiVal = (amount * daiPerc) / 100;
        uint256 usdcVal = (amount * usdcPerc) / 100;
        //get idle token price with fees
        uint256 idleDaiPrice = idleDai.tokenPriceWithFee(address(this));
        uint256 idleUsdcPrice = idleUsdc.tokenPriceWithFee(address(this));
        //calculate amount of idle tokens to withdraw
        uint256 idleDaiWithdraw = daiVal / idleDaiPrice;
        uint256 idleUsdcWithdraw = usdcVal / idleUsdcPrice;
        //withdraw those tokens from idle
        idleDai.redeemIdleToken(idleDaiWithdraw);
        idleUsdc.redeemIdleToken(idleUsdcWithdraw);
        //update values
        tvl -= amount;
        individualTvl[msg.sender] -= amount;
        totalDai -= daiVal;
        totalUsdc -= usdcVal;
        //transfer tokens to sender
        dai.transfer(msg.sender, daiVal);
        usdc.transfer(msg.sender, usdcVal);
        //emit events
        emit Transfer(msg.sender,address(this), amount);
        emit Transfer(msg.sender,address(this), amount);

    }
}