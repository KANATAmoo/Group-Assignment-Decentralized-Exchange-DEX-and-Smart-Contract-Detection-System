// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library Math{
    //取最小值函数
    function min(uint x, uint y) internal pure returns(uint z){
        z = x < y ? x : y;
    }

    //牛顿迭代法计算平方根函数
    function sqrt(uint y) internal pure returns(uint z){
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract DEX is ERC20{
    //构建一对代币合约
    IERC20 public TokenA;
    IERC20 public TokenB;

    //交易池里的代币储量
    uint public ReserveA;
    uint public ReserveB;

    //mapping(address => uint) public balanceOf;

    //初始化代币地址
    //构建两个代币合约，分别传入代币合约的地址
    //使用两个ERC20代币_tokenA和_tokenB初始化合约，并设置流动性代币的名称和符号为"DEXtoken"和"dext"
    constructor(IERC20 _TokenA, IERC20 _TokenB) ERC20("DEXtoken", "dext"){
        TokenA = _TokenA;
        TokenB = _TokenB;
    }


//——————流动性提供——————

    //铸造事件
    event Mint(address indexed sender, uint amount0, uint amount1);

//流动性提供：流动性提供者给市场提供流动性
//从流动性提供者转移amountA的tokenA和amountB的tokenB到合约
//Liquidity Provider（LP）：流动性提供者代币
    //添加流动性
    // 如果首次添加，铸造的LP数量 = sqrt(amountA * amountB)
    // 如果非首次，铸造的LP数量 = min(amountA/reserveA, amountB/reserveB)* totalSupply_LP
    // amountA 添加的tokenA数量
    // amountB 添加的tokenB数量
    function addLiquidity(uint amountA, uint amountB) public returns(uint liquidity){
        //给合约授权
        TokenA.transferFrom(msg.sender, address(this), amountA);
        TokenB.transferFrom(msg.sender, address(this), amountB);

        //计算添加的流动性份额，铸造LP
        //流动性计算：
        //如果没有流动性存在，基于几何平均值（使用平方根）铸造LP代币。
        //否则，基于添加代币与现有储备的比例铸造，确保平衡。
        uint TotalSupply = totalSupply(); //ERC20合约函数，返回代币总供给

        if(TotalSupply == 0){ //首次添加流动性，铸造LP
            liquidity = Math.sqrt(amountA * amountB);
        }else{ //非首次添加，按添加代币的数量比例铸造LP，取两个代币更小的那个比例
            liquidity = Math.min((amountA * TotalSupply) / ReserveA, (amountB * TotalSupply) / ReserveB);
        }

        //检查铸造的LP数量
        require(liquidity > 0, "Liquidity minted is not enough!");

        //更新交易池代币储量
        ReserveA = TokenA.balanceOf(address(this));
        ReserveB = TokenB.balanceOf(address(this));

        //给流动性提供者铸造LP代币，代表他们提供的流动性
        _mint(msg.sender, liquidity); //ERC20铸造代币函数

        //触发铸造事件
        emit Mint(msg.sender, amountA, amountB);
    }

/*
https://web3dao-cn.github.io/solidity-example/defi/constant-product-amm/
    function _addLiquidity(uint _amount0, uint _amount1) external returns (uint shares) {
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        uint d0 = bal0 - reserve0;
        uint d1 = bal1 - reserve1;

        if (reserve0 > 0 || reserve1 > 0) {
            require(reserve0 * d1 == reserve1 * d0, "x / y != dx / dy");
        }

        if (totalSupply > 0) {
            shares = _min((d0 * totalSupply) / reserve0, (d1 * totalSupply) / reserve1);
        } else {
            shares = _sqrt(d0 * d1);
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        _update(bal0, bal1);
    }
*/

    //销毁事件
    event Burn(address indexed sender, uint amount0, uint amount1);

    //移除流动性
    // 销毁LP，转出代币
    // 转出数量 = (liquidity / totalSupply_LP) * reserve
    // liquidity 移除的流动性数量
    function removeLiquidity(uint liquidity) external returns(uint amountA, uint amountB){
        //获取合约中的代币余额
        uint balanceA = TokenA.balanceOf(address(this));
        uint balanceB = TokenB.balanceOf(address(this));

        //按LP的比例计算要转出的代币数量
        uint TotalSupply = totalSupply();
        amountA = liquidity * balanceA / TotalSupply;
        amountB = liquidity * balanceB / TotalSupply;

        //检查代币数量
        require(amountA > 0 && amountB > 0, "Liquidity burned is not enough!");

        //销毁LP份额
        _burn(msg.sender, liquidity);

        //转出代币，将相应的代币转账给用户
        TokenA.transfer(msg.sender, amountA);
        TokenB.transfer(msg.sender, amountB);

        //更新代币储量
        ReserveA = TokenA.balanceOf(address(this));
        ReserveB = TokenB.balanceOf(address(this));

        //触发销毁事件
        emit Burn(msg.sender, amountA, amountB);
    }

/*
https://web3dao-cn.github.io/solidity-example/defi/constant-product-amm/
    function _removeLiquidity(uint _shares) external returns (uint amount0, uint amount1) {
        amount0 = (_shares * reserve0) / totalSupply;
        amount1 = (_shares * reserve1) / totalSupply;

        _burn(msg.sender, _shares);
        _update(reserve0 - amount0, reserve1 - amount1);

        if (amount0 > 0) {
            token0.transfer(msg.sender, amount0);
        }
        if (amount1 > 0) {
            token1.transfer(msg.sender, amount1);
        }
    }
*/

//——————交易——————

    //交易计算公式
    //给定一个资产的数量和代币对的储备，计算交换另一个代币的数量
    function GetAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns(uint amountOut){
        //输入合法性判断
        require(amountIn > 0, "Amount is insufficient!");
        require(reserveIn > 0 && reserveOut > 0, "Liquidity is insufficient!");
        
        amountOut = amountIn * reserveOut / (reserveIn + amountIn);
    }

    //交易事件
    event Swap(address indexed sender, uint amountIn, address tokenIn, uint amountOut, address tokenOut);

//交易函数
    //用户在调用函数时指定用于交换的代币数量，交换的代币地址，以及换出另一种代币的最低数量。
    //判断是 tokenA 交换 tokenB，还是 tokenB 交换 tokenA。
    //利用上面的公式，计算交换出代币的数量。
    //判断交换出的代币是否达到了用户指定的最低数量，这里类似于交易的滑点。
    //将用户的代币转入合约。
    //将交换的代币从合约转给用户。
    //更新合约的代币储备量。
    //触发交易事件

    // amountIn 用于交换的代币数量
    // tokenIn 用于交换的代币合约地址
    // amountOutMin 交换出另一种代币的最低数量
    function swap(uint amountIn, IERC20 tokenIn, uint amountOutMin) external returns(uint amountOut, IERC20 tokenOut){
        //合法性判断
        require(amountIn > 0, "Output amount insufficient");
        require(tokenIn == TokenA || tokenIn == TokenB, "Invalid Token");

        uint balanceA = TokenA.balanceOf(address(this));
        uint balanceB = TokenB.balanceOf(address(this));

        //判断是哪种交易
        if(tokenIn == TokenA){
            //情况：TokenA交换TokenB
            tokenOut = TokenB;

            //计算可交换出来的TokenB数量
            amountOut = GetAmountOut(amountIn, balanceA, balanceB);

            //判断交换出的代币是否达到了用户指定的最低数量
            require(amountOut > amountOutMin, "Output amount insufficient");
            
            // 进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut); 
        }else{
            //情况：TokenB交换TokenA
            tokenOut = TokenA;

            // 计算可交换出的TokenB数量
            amountOut = GetAmountOut(amountIn, balanceA, balanceB);
            
            //判断交换出的代币是否达到了用户指定的最低数量
            require(amountOut > amountOutMin, "Output amount insufficient");
            
            // 进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);
        }

        //更新代币储量
        ReserveA = TokenA.balanceOf(address(this));
        ReserveB = TokenB.balanceOf(address(this));

        //触发交易事件
        emit Swap(msg.sender, amountIn, address(tokenIn), amountOut, address(tokenOut));
    }

}