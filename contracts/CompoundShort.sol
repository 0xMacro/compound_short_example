// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/* Short ETH
1. supply USDC
2. borrow ETH
3. sell ETH on Uniswap for more USDC

Price of ETH goes down (good for us shorters!)
4. buy ETH on Uniswap (we can now buy the same amount, but for less)
5. repay borrowed ETH
6. Profit
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/Compound.sol";
import "./interfaces/Uniswap.sol";

contract CompoundShort {
    CErc20 public cTokenCollateral;
    CEth public cTokenBorrow;
    IERC20 public tokenBorrow;
    uint256 public decimals;

    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    PriceFeed public priceFeed = PriceFeed(0x65c816077C29b557BEE980ae3cC2dCE80204A0C5);

    IUniswapV2Router private constant UNI =
        IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(
        address _cTokenCollateral,
        address _cTokenBorrow,
        address _tokenBorrow,
        uint256 _decimals
    ) {
        cTokenCollateral = CErc20(_cTokenCollateral);
        cTokenBorrow = CEth(_cTokenBorrow);
        tokenBorrow = IERC20(_tokenBorrow);
        decimals = _decimals;

        // enter markets
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(_cTokenCollateral);
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        require(errors[0] == 0, "error entering markets");
    }

    function supply(uint256 mintAmount) external payable {
        // supply liquidity to USDC so we can borrow ETH
        cTokenCollateral.transferFrom(msg.sender, address(this), mintAmount);
        cTokenCollateral.mint(mintAmount);
    }

    function short() external {
        // borrow ETH
        // sell ETH for USDC
    }

    function lowerETHPrice() external {
        // sell a lot of ETH for USDC
        // verify the price is lower
    }

    function repayBorrow() external {
        // buy the necessary ETH using USDC
        // repay the compound borrow

    }


//   constructor(
//     address _cTokenCollateral,
//     address _cTokenBorrow,
//     address _tokenBorrow,
//     uint _decimals
//   ) {
//     cEth = CEth(_cEth);
//     cTokenBorrow = CErc20(_cTokenBorrow);
//     tokenBorrow = IERC20(_tokenBorrow);
//     decimals = _decimals;

//     // enter market to enable borrow
//     address[] memory cTokens = new address[](1);
//     cTokens[0] = address(cEth);
//     uint[] memory errors = comptroller.enterMarkets(cTokens);
//     require(errors[0] == 0, "Comptroller.enterMarkets failed.");
//   }

//   receive() external payable {}

//   function supply() external payable {
//     cEth.mint{value: msg.value}();
//   }

//   function getMaxBorrow() external view returns (uint) {
//     (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(
//       address(this)
//     );

//     require(error == 0, "error");
//     require(shortfall == 0, "shortfall > 0");
//     require(liquidity > 0, "liquidity = 0");

//     uint price = priceFeed.getUnderlyingPrice(address(cTokenBorrow));
//     uint maxBorrow = (liquidity * (10**decimals)) / price;

//     return maxBorrow;
//   }

//   function long(uint _borrowAmount) external {
//     // borrow
//     require(cTokenBorrow.borrow(_borrowAmount) == 0, "borrow failed");
//     // buy ETH
//     uint bal = tokenBorrow.balanceOf(address(this));
//     tokenBorrow.approve(address(UNI), bal);

//     address[] memory path = new address[](2);
//     path[0] = address(tokenBorrow);
//     path[1] = address(WETH);
//     UNI.swapExactTokensForETH(bal, 1, path, address(this), block.timestamp);
//   }

//   function repay() external {
//     // sell ETH
//     address[] memory path = new address[](2);
//     path[0] = address(WETH);
//     path[1] = address(tokenBorrow);
//     UNI.swapExactETHForTokens{value: address(this).balance}(
//       1,
//       path,
//       address(this),
//       block.timestamp
//     );
//     // repay borrow
//     uint borrowed = cTokenBorrow.borrowBalanceCurrent(address(this));
//     tokenBorrow.approve(address(cTokenBorrow), borrowed);
//     require(cTokenBorrow.repayBorrow(borrowed) == 0, "repay failed");

//     uint supplied = cEth.balanceOfUnderlying(address(this));
//     require(cEth.redeemUnderlying(supplied) == 0, "redeem failed");

//     // supplied ETH + supplied interest + profit (in token borrow)
//   }

//   // not view function
//   function getSuppliedBalance() external returns (uint) {
//     return cEth.balanceOfUnderlying(address(this));
//   }

//   // not view function
//   function getBorrowBalance() external returns (uint) {
//     return cTokenBorrow.borrowBalanceCurrent(address(this));
//   }

//   function getAccountLiquidity()
//     external
//     view
//     returns (uint liquidity, uint shortfall)
//   {
//     // liquidity and shortfall in USD scaled up by 1e18
//     (uint error, uint _liquidity, uint _shortfall) = comptroller.getAccountLiquidity(
//       address(this)
//     );
//     require(error == 0, "error");
//     return (_liquidity, _shortfall);
//   }
}