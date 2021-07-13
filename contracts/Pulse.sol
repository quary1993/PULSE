pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

//openzeppelin contracts
import "./openzeppelin/contracts/token/IERC20.sol";
import "./openzeppelin/contracts/libraries/SafeMath.sol";
import "./openzeppelin/contracts/libraries/Ownable.sol";

//uniswap contracts
import "./uniswap/core/IUniswapV2Factory.sol";
import "./uniswap/core/IUniswapV2Pair.sol";
import "./uniswap/periphery/IUniswapV2Router01.sol";
import "./uniswap/periphery/IUniswapV2Router02.sol";

import "hardhat/console.sol";

contract Pulse is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Pulse";
    string private _symbol = "PULSE";
    uint8 private _decimals = 9;

    uint256 public _taxFee = 1;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _reviveLaunchDomeFee = 2;
    uint256 private _previousReviveLaunchDomeFee = _reviveLaunchDomeFee;
    address private reviveLaunchDomeAddress;

    uint256 public _reviveBasketFee = 5;
    uint256 private _previousReviveBasketFee = _reviveBasketFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    address public immutable minterAddress;

    uint256 public _maxTxAmount = 5000000 * 10**9;
    uint256 private numTokensSellToAddToLiquidity = 500000 * 10**9;

    uint256 tokenPrice = 20 * 10**18;
    uint256 publicSaleMintedTokens = 0;
    bool hasOwnerMintedHalf = false;
    uint256 periodicMintedTokens = 0;
    bool publicSalePaused = true;
    bool shouldTransfer = false;

    uint256 creationTime;
    uint8 periodicMintStage = 1;

    struct Values {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 rReviveLaunchDomeFee;
        uint256 rReviveBasketFee;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tReviveLaunchDomeFee;
        uint256 tReviveBasketFee;
    }

    modifier isTransfer {
        require(
            shouldTransfer,
            "Public sale: Transactions are stopped until the end of public sale"
        );
        _;
    }

    //checks if the address that called the function is the contract who handles the minting
    modifier onlyMinter {
        require(msg.sender == minterAddress, "Mint: you are not the minter!");
        _;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event Mint(address to, uint256 amount);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(uint256 _tokenPrice, address _minterAddress) public {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        tokenPrice = _tokenPrice;

        minterAddress = _minterAddress;
        reviveLaunchDomeAddress = owner();

        //exclude owner, this contract, router and pair
        _isExcluded[owner()] = true;
        _isExcluded[address(this)] = true;
        _isExcluded[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;
        _isExcluded[uniswapV2Pair] = true;
        _isExcluded[address(0)]=true;

        _rOwned[address(0)]=_rTotal;
        _tOwned[address(0)]=_tTotal;
        
        _excluded.push(owner());
        _excluded.push(address(this));
        _excluded.push(address(0));
        _excluded.push(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _excluded.push(uniswapV2Pair);

        creationTime = block.timestamp;
    }

    receive() external payable {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function setTokenPrice(uint256 _tokenPrice) public {
        tokenPrice = _tokenPrice;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setReviveLaunchDomeAddress(address _reviveLaunchDomeAddress)
        public
        onlyOwner
    {
        reviveLaunchDomeAddress = _reviveLaunchDomeAddress;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        isTransfer
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override isTransfer returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount)
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue)
        );
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        Values memory values = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
        _rTotal = _rTotal.sub(values.rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        Values memory values = _getValues(tAmount);
        if (!deductTransferFee) {
            return values.rAmount;
        } else {
            return values.rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent) / 10**2;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (Values memory) {
        Values memory values;
        (
            values.tTransferAmount,
            values.tFee,
            values.tReviveLaunchDomeFee,
            values.tLiquidity,
            values.tReviveBasketFee
        ) = _getTValues(tAmount);
        (
            values.rAmount,
            values.rTransferAmount,
            values.rFee,
            values.rReviveLaunchDomeFee,
            values.rReviveBasketFee
        ) = _getRValues(
            tAmount,
            values.tFee,
            values.tReviveLaunchDomeFee,
            values.tReviveBasketFee,
            values.tLiquidity,
            _getRate()
        );
        return (values);
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tTransferAmount = tAmount.sub(calculateFee(tAmount, _taxFee));
        tTransferAmount = tTransferAmount.sub(
            calculateFee(tAmount, _liquidityFee)
        );
        tTransferAmount = tTransferAmount.sub(
            calculateFee(tAmount, _reviveLaunchDomeFee)
        );
        tTransferAmount = tTransferAmount.sub(
            calculateFee(tAmount, _reviveBasketFee)
        );
        return (
            tTransferAmount,
            calculateFee(tAmount, _taxFee),
            calculateFee(tAmount, _reviveLaunchDomeFee),
            calculateFee(tAmount, _liquidityFee),
            calculateFee(tAmount, _reviveBasketFee)
        );
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tReviveLaunchDomeFee,
        uint256 tReviveBasketFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rTransferAmount = tAmount.mul(currentRate);
        rTransferAmount = rTransferAmount.sub(tFee.mul(currentRate));
        rTransferAmount = rTransferAmount.sub(tLiquidity.mul(currentRate));
        rTransferAmount = rTransferAmount.sub(
            tReviveLaunchDomeFee.mul(currentRate)
        );
        rTransferAmount = rTransferAmount.sub(
            tReviveBasketFee.mul(currentRate)
        );
        return (
            tAmount.mul(currentRate),
            rTransferAmount,
            tFee.mul(currentRate),
            tReviveLaunchDomeFee.mul(currentRate),
            tReviveBasketFee.mul(currentRate)
        );
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) {
                
                return (_rTotal, _tTotal);
            } 
            
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        
        if (rSupply < _rTotal / _tTotal){
            return (_rTotal, _tTotal);
        } 
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        _rOwned[address(this)] = _rOwned[address(this)].add(tLiquidity.mul(_getRate()));
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _takeReviveLaunchDomeFee(
        uint256 tReviveLaunchDomeFee
    ) private {
        _rOwned[reviveLaunchDomeAddress] = _rOwned[reviveLaunchDomeAddress].add(
            tReviveLaunchDomeFee.mul(_getRate())
        );
        if (_isExcluded[reviveLaunchDomeAddress])
            _tOwned[reviveLaunchDomeAddress] = _tOwned[reviveLaunchDomeAddress]
            .add(tReviveLaunchDomeFee);
    }

    function _takeReviveBasketFee(
        uint256 tReviveBasketFee
    ) private {
        _rOwned[minterAddress] = _rOwned[minterAddress].add(tReviveBasketFee.mul(_getRate()));
        _tOwned[minterAddress] = _tOwned[minterAddress].add(tReviveBasketFee);
        // (bool success, ) = minterAddress.call(
        //     abi.encodeWithSignature(
        //         "handleReviveBasket(uint256)",
        //         tReviveBasketFee
        //     )
        // );
        // require(success, 'Revive basket error');
    }

    function calculateFee(uint256 _amount, uint256 _tax)
        private
        pure
        returns (uint256)
    {
        return _amount.mul(_tax) / 10**2;
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousReviveLaunchDomeFee = _reviveLaunchDomeFee;
        _previousReviveBasketFee = _reviveBasketFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _reviveLaunchDomeFee = 0;
        _reviveBasketFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _reviveLaunchDomeFee = _previousReviveLaunchDomeFee;
        _reviveBasketFee = _previousReviveBasketFee;
    }

    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) private {
        require(to != address(0), "Mint: mint to the zero address.");
        require(amount > 0, "Mint: mint amount must be greater than zero.");
        //uint rate = _getRate();
        if (_isExcluded[to]) {        
            _tOwned[to] = _tOwned[to].add(amount);  
            _rOwned[to] = _rOwned[to].add(amount.mul(_getRate()));
            
        } else {
            _rOwned[to] = _rOwned[to].add(amount.mul(_getRate()));
        }
        _rOwned[address(0)].sub(amount * _getRate());
        _tOwned[address(0)].sub(amount);
        emit Mint(to, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        if (
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            !_isExcluded[to] &&
            !_isExcluded[from] &&
            contractTokenBalance > 0
        ) {
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcluded account then remove the fee
        if (_isExcluded[from] || _isExcluded[to]) {
            takeFee = false;
        }
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance.sub(half);
        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForEth(half); // <- this breaks the BNB -> PULSE swap when swap+liquify is triggered

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 7 days
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uint256 amountToken;
        uint256 amountETH;
        uint256 liquidity;
        (amountToken, amountETH, liquidity) = uniswapV2Router.addLiquidityETH{
            value: ethAmount
        }(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp + 7 days
        );
    }

    // function redeemLpTokens() public onlyOwner() {
    //     //get contract interafce of the uniswapV2PairToken
    //     IUniswapV2Pair uniswapV2PairContract = IUniswapV2Pair(uniswapV2Pair);

    //     //approve the router to use all the LP's of this contract
    //     uniswapV2PairContract.approve(
    //         0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
    //         uniswapV2PairContract.balanceOf(address(this))
    //     );

    //     //switch all the LP's into ETH and Pulse
    //     uint256 amountEth;
    //     uint256 amountPulse = balanceOf(address(this));
    //     amountEth = uniswapV2Router
    //     .removeLiquidityETHSupportingFeeOnTransferTokens(
    //         address(this),
    //         uniswapV2PairContract.balanceOf(address(this)),
    //         1,
    //         1,
    //         address(this),
    //         block.timestamp + 7 days
    //     );
    //     amountPulse = balanceOf(address(this)).sub(amountPulse);

    //     //generate the uniswap pair path of WETH -> PULSE
    //     address[] memory path = new address[](2);
    //     path[0] = uniswapV2Router.WETH();
    //     path[1] = address(this);

    //     //get the balance of the owner account
    //     uint256 balance = _tOwned[owner()];

    //     //converts all of the eth into PULSE tokens and transfers them to the owner
    //     uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
    //         value: amountEth
    //     }(1, path, owner(), block.timestamp + 7 days);

    //     //calculate the amount of tokens that owner has received from the previous conversion
    //     uint256 tokensToBeBurnedFromOwner = _tOwned[owner()].sub(balance);

    //     //get the current reflection rate
    //     uint256 currentRate = _getRate();

    //     //burn the resulted amount from the owner balances
    //     _tOwned[owner()] = _tOwned[owner()].sub(tokensToBeBurnedFromOwner);
    //     _rOwned[owner()] = _rOwned[owner()].sub(
    //         tokensToBeBurnedFromOwner * currentRate
    //     );

    //     //burn the resulted pulse from liquidity removing
    //     _tOwned[address(this)] = _tOwned[address(this)].sub(amountPulse);
    //     _tOwned[address(this)] = _rOwned[address(this)].sub(
    //         amountPulse * currentRate
    //     );

    //     //burn the resulted pulse from liquidity removing and eth swaping from the total supplies
    //     _burn(tokensToBeBurnedFromOwner + amountPulse, currentRate);
    // }

    // function burn(uint256 tokensToBeBurned) public {
    //     _burn(tokensToBeBurned, _getRate());
    // }

    // //burn the resulted amount from the total supplies
    // //params: tokensToBeBurned (uint256): the amount of tokens that needs to be removed from supplies
    // //        currentRate (uint256): the current rate of reflection
    // function _burn(uint256 tokensToBeBurned, uint256 currentRate)
    //     private
    //     onlyOwner()
    // {
    //     _tTotal = _tTotal.sub(tokensToBeBurned);
    //     _rTotal = _rTotal.sub(tokensToBeBurned * currentRate);
    // }

    function resumeTransactions() public onlyOwner() {
        shouldTransfer = true;
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        Values memory values = _getValues(amount);
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _tOwned[sender] = _tOwned[sender].sub(amount);
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _tOwned[recipient] = _tOwned[recipient].add(values.tTransferAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _tOwned[sender] = _tOwned[sender].sub(amount);
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _tOwned[recipient] = _tOwned[recipient].add(values.tTransferAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        } else {
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        }
        _takeLiquidity(values.tLiquidity);
        _takeReviveLaunchDomeFee(
            values.tReviveLaunchDomeFee
        );
        _takeReviveBasketFee(
            values.tReviveBasketFee
        );
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
        if (!takeFee) restoreAllFee();
    }
}
