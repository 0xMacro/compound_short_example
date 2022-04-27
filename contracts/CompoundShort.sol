// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/* Short UNI
1. supply USDC
2. borrow UNI
3. sell UNI on Uniswap for more USDC

Price of UNI goes down (good for us shorters!)
4. buy UNI on Uniswap (we can now buy the same amount, but for less)
5. repay borrowed UNI
6. Profit
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/Compound.sol";
import "./interfaces/Uniswap.sol";

import "hardhat/console.sol";

contract CompoundShort {
    CErc20 public cTokenCollateral;
    CErc20 public cTokenBorrow;
    IERC20 public tokenCollateral;
    IERC20 public tokenBorrow;
    uint256 public decimals;

    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    PriceFeed public priceFeed = PriceFeed(0x65c816077C29b557BEE980ae3cC2dCE80204A0C5);

    IUniswapV2Router private constant UNI =
        IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    constructor(
        address _cTokenCollateral,
        address _cTokenBorrow,
        address _tokenCollateral,
        address _tokenBorrow,
        uint256 _decimals
    ) {
        cTokenCollateral = CErc20(_cTokenCollateral);
        cTokenBorrow = CErc20(_cTokenBorrow);
        tokenCollateral = IERC20(_tokenCollateral);
        tokenBorrow = IERC20(_tokenBorrow);
        decimals = _decimals;

        // enter markets
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(_cTokenCollateral);
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        require(errors[0] == 0, "error entering markets");
    }

    function supply(uint256 mintAmount) external payable {
        // supply liquidity to USDC so we can borrow UNI
        tokenCollateral.transferFrom(msg.sender, address(this), mintAmount);
        tokenCollateral.approve(address(cTokenCollateral), mintAmount);
        console.log("USDC balance of address(this): %s", tokenCollateral.balanceOf(address(this)) / 1e6);

        uint256 err = cTokenCollateral.mint(mintAmount);
        require(err == 0, "error in minting");
    }

    function getBorrowAmount() view external returns (uint256) {
        // Get the amount of liquidity we can borrow against (this number is non-zero)
        // because we supplied USDC in the `.mint` up above in `.supply`.
        // This value is in units of USD, scaled by 1e18
        (uint256 err, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
        require(err == 0, "error in getAccountLiquidity");
        require(liquidity > 0, "insufficient liquidity");
        console.log("liquidity in units of USDC: %s", liquidity / 1e18);

        // get the price of UNI, which we'll use to calculate the maximum we can borrow
        uint256 price = priceFeed.getUnderlyingPrice(address(cTokenBorrow));
        console.log("the underlying price of UNI is: %s", price / 1e18);

        // this is the maximum amount we could borrow, given our account liquidity
        // and the collateral factor
        uint256 borrowAmountLimit = liquidity * 10**decimals / price;

        // We're allowed to borrow up to borrowAmountLimit, but that means we'll be
        // immediately liquidated. So instead we'll borrow 3/4th's of this so we
        // have some wiggle room

        uint256 borrowAmount = (borrowAmountLimit * 3) / 4;
        return borrowAmount;
    }

    
    function short(uint256 borrowAmount) external {
        // borrow UNI
        cTokenBorrow.borrow(borrowAmount);
        console.log("UNI balance of address(this): %s", tokenBorrow.balanceOf(address(this)) / 1e18);

        // sell UNI for USDC
        uint uniBalance = tokenBorrow.balanceOf(address(this));
        tokenBorrow.approve(address(UNI), uniBalance);

        console.log("USDC balance of address(this): %s", tokenCollateral.balanceOf(address(this)) / 1e6);
        address[] memory path = new address[](2);
        path[0] = address(tokenBorrow);
        path[1] = address(tokenCollateral);
        UNI.swapExactTokensForTokens(uniBalance, 1, path, address(this), block.timestamp);
        console.log("USDC balance of address(this): %s", tokenCollateral.balanceOf(address(this)) / 1e6);
    }

    // assumes the test function in test/index.ts "lowerUNIPrice" has already been called
    function repayBorrow() external {
        uint256 borrowed = cTokenBorrow.borrowBalanceCurrent(address(this));
        console.log("amount we must repay for the borrow: %s", borrowed);

        // sell USDC to get the UNI (we'll still have some USDC leftover, because the price went down)
        console.log("USDC balance of address(this): %s", tokenCollateral.balanceOf(address(this)) / 1e6);
        console.log("UNI balance of address(this): %s", tokenBorrow.balanceOf(address(this)) / 1e18);
        address[] memory path = new address[](2);
        path[0] = address(tokenCollateral);
        path[1] = address(tokenBorrow);
        tokenCollateral.approve(address(UNI), tokenCollateral.balanceOf(address(this)));
        // there is some residual allowance, so we set it to zero
        UNI.swapTokensForExactTokens(borrowed, type(uint256).max, path, address(this), block.timestamp);
        tokenCollateral.approve(address(UNI), 0);

        console.log("USDC balance of address(this): %s", tokenCollateral.balanceOf(address(this)) / 1e6);
        console.log("UNI balance of address(this): %s", tokenBorrow.balanceOf(address(this)) / 1e18);

        // repay the UNI we borrowed earlier

    }


}