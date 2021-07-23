pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

//openzeppelin contracts
import "./openzeppelin/contracts/token/IToken.sol";
import "./openzeppelin/contracts/token/IERC20.sol";
import "./openzeppelin/contracts/libraries/SafeMath.sol";
import "./openzeppelin/contracts/libraries/Ownable.sol";

//uniswap contracts
import "./pancakeswap/interfaces/IPancakeFactory.sol";
import "./pancakeswap/interfaces/IPancakePair.sol";
import "./pancakeswap/interfaces/IPancakeRouter01.sol";
import "./pancakeswap/interfaces/IPancakeRouter02.sol";

//hardhat contracts
import "hardhat/console.sol";

//minter contract
import "./minter/IPulseManager.sol";


//    #PULSE features:
//    5% Revive Basket: 
//    The owner will be able to define an arbitrary number of tokens, each with a corresponding weight. 
//    Each time a transfer is done, the 5% commission that is meant for the Revive basket will be used to buy these tokens 
//    from Pancake Swap according to their corresponding weight. After the contract buys the revive basket tokens, it will hold
//    the resulting LP. 

// 	A function will be implemented, and callable by the owner, which will redeem a specific LP, sell the obtained tokens for ETH, 
//     then use the ETH to acquire PULSE from Pancake Swap and distribute the resulting PULSE to all the PULSE holders proportional 
//     to their holdings.

//     2% Revive Launchdome:
//     There will be a revive launchdome wallet, changeable by the owner, which will receive 2% of the transferred token.

//     3% Pancake Swap Liquidity:
//     2% of the transferred amount will be used to add liquidity to the ETH <> PULSE pair in pancake swap. In this process, 
//     the contract will buy the proper amount of ETH (~equiv. with 1% of the transaction amount) and place them as liquidity in the 
//     Pancake Swap Pair, together with the remaining amount of the allocated 2%. The resulting LP will be held by the contract.
//     We will add a function which redeems the liquidity, sells the ETH for Pulse and burns the resulting pulse.


//     1% Distribution:
//     1% will be distributed among all the token holders

 


contract Pulse is Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 10**9; 
    //maximum supply starts with 10^9 and can grow to 10*18 
    uint256 private _rTotal = (MAX - (MAX % _tTotal)) / 10**9;
    uint256 private _tFeeTotal;

    string private constant _name = "Pulse";
    string private constant _symbol = "PULSE";
    uint8 private constant _decimals = 9;

    //declaring fee percentages 
    uint256 public _taxFee = 1;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 2;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _reviveLaunchDomeFee = 2;
    uint256 private _previousReviveLaunchDomeFee = _reviveLaunchDomeFee;
    address private reviveLaunchDomeAddress;

    uint256 public _reviveBasketFee = 5;
    uint256 private _previousReviveBasketFee = _reviveBasketFee;

    IPancakeRouter02 public immutable uniswapV2Router;
    address public uniswapV2Pair;

    address public immutable minterAddress;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 public _maxTxAmount = 5000000 * 10**9;

    uint256 tokenPrice = 20 * 10**18;
    bool shouldTransfer = false;

    uint256 creationTime;

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

    //used to block all transactions while public sale is taking place
    modifier isTransfer {
        require(
            shouldTransfer,
            "Public sale: Transactions are stopped until the end of public sale"
        );
        _;
    }

    //checks if the address that called the function is the contract who handles the minting
    modifier onlyMinter {
        require(_msgSender() == minterAddress, "Mint: you are not the minter!");
        _;
    }

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier checkFeeSum {
        _;
        require(_taxFee.add(_liquidityFee.add(_reviveBasketFee).add(_reviveLaunchDomeFee)) <= 10, "Pulse: the sum of fees should be less or equal to ten");
    }

    //declaring events that are occuring in this contract
    event Mint(address to, uint256 amount);
    event Approval(address owner, address spender, uint256 amount);
    event Transfer(address sender, address recipient, uint256 amount);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    constructor(uint256 _tokenPrice, address _minterAddress) public {
        IPancakeRouter02 _uniswapV2Router = IPancakeRouter02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );

        // Create a uniswap pair for this new token
        uniswapV2Pair = IPancakeFactory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());
        console.log(uniswapV2Pair);
        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        tokenPrice = _tokenPrice;

        minterAddress = _minterAddress;
        reviveLaunchDomeAddress = owner();

        //exclude owner, this contract, router and pair
        _isExcluded[owner()] = true;
        _isExcluded[_minterAddress] = true;
        _isExcluded[address(this)] = true;
        _isExcluded[0xD99D1c33F9fC3444f8101754aBC46c52416550D1] = true;
        _isExcluded[uniswapV2Pair] = true;
        _isExcluded[address(0)]=true;

        _rOwned[address(0)]=_rTotal;
        _tOwned[address(0)]=_tTotal;
        
        _excluded.push(owner());
        _excluded.push(_minterAddress);
        _excluded.push(address(this));
        _excluded.push(address(0));
        _excluded.push(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        _excluded.push(uniswapV2Pair);

        creationTime = block.timestamp;
    }

    function getPair() public view returns(address) {
        return uniswapV2Pair;
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

    function totalSupply() public view returns (uint256) {
        return _tTotal;
    }

    //sets how much ETH should PULSE cost (it should be an 18 decimals number)
    function setTokenPrice(uint256 _tokenPrice) public onlyOwner {
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

    function balanceOf(address account) public view returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        isTransfer
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public isTransfer returns (bool) {
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

    function deliver(uint256 tAmount) public  {
        address sender = _msgSender();
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

    function excludeFromReward(address account) external onlyOwner {
        // require(account != 0xD99D1c33F9fC3444f8101754aBC46c52416550D1, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
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

    function setTaxFeePercent(uint256 taxFee) external checkFeeSum onlyOwner {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external checkFeeSum onlyOwner {
        _liquidityFee = liquidityFee;
    }

    function setReviveLaunchDomeFeePercent(uint256 reviveLaunchDomeFee) external checkFeeSum onlyOwner {
        _reviveLaunchDomeFee = reviveLaunchDomeFee;
    }

    function setReviveBasketFeePercent(uint256 reviveBasketDomeFee) external checkFeeSum onlyOwner {
        _reviveLaunchDomeFee = reviveBasketDomeFee;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
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
        uint256 tTransferAmount = tAmount.sub(_calculateFee(tAmount, _taxFee));
        tTransferAmount = tTransferAmount.sub(
            _calculateFee(tAmount, _liquidityFee)
        );
        tTransferAmount = tTransferAmount.sub(
            _calculateFee(tAmount, _reviveLaunchDomeFee)
        );
        tTransferAmount = tTransferAmount.sub(
            _calculateFee(tAmount, _reviveBasketFee)
        );
        return (
            tTransferAmount,
            _calculateFee(tAmount, _taxFee),
            _calculateFee(tAmount, _reviveLaunchDomeFee),
            _calculateFee(tAmount, _liquidityFee),
            _calculateFee(tAmount, _reviveBasketFee)
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
        pure
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

    
    // Used to deposit "tLiquidity" amount of Pulse in the balance of this contract where
    // "tLiquidity" is "_liquidityFee" percentage of the amount that is being transfered 
    
    function _takeLiquidity(uint256 tLiquidity) private {
        _rOwned[address(this)] = _rOwned[address(this)].add(tLiquidity.mul(_getRate()));
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    
    // Used to deposit "tReviveLaunchDomeFee" amount of Pulse in the balance of this contract where
    // "tReviveLaunchDomeFee" is "_reviveLaunchDomeFee" percentage of the amount that is being transfered
    
    function _takeReviveLaunchDomeFee(
        uint256 tReviveLaunchDomeFee
    ) private {
        _rOwned[reviveLaunchDomeAddress] = _rOwned[reviveLaunchDomeAddress].add(
            tReviveLaunchDomeFee.mul(_getRate())
        );
        if (_isExcluded[reviveLaunchDomeAddress]) {
            _tOwned[reviveLaunchDomeAddress] = _tOwned[reviveLaunchDomeAddress]
            .add(tReviveLaunchDomeFee);
        }
    }

    // Used to deposit "tReviveBasketFee" amount of Pulse in the balance of this contract where
    // "tReviveBasketFee" is "_reviveBasketFee" percentage of the amount that is being transfered 
    // and revive basket functionality is called if "tReviveBasketFee" is greater than 0
    
    function _takeReviveBasketFee(
        uint256 tReviveBasketFee
    ) private {
        _rOwned[minterAddress] = _rOwned[minterAddress].add(tReviveBasketFee.mul(_getRate()));
        _tOwned[minterAddress] = _tOwned[minterAddress].add(tReviveBasketFee);
        if(tReviveBasketFee > 0) {
        IPulseManager minter = IPulseManager(minterAddress);
        minter.handleReviveBasket(tReviveBasketFee);
        }
    }

    //returns "_tax" percentage of "_amount"
    function _calculateFee(uint256 _amount, uint256 _tax)
        private
        pure
        returns (uint256)
    {
        return _amount.mul(_tax) / 10**2;
    }

    //used to remove all the fees that are being charged when a transfer is taking place
    function _removeAllFee() private {
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

    //used to restore all the fees after a transfer that didn't charged any fee had occured
    function _restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _reviveLaunchDomeFee = _previousReviveLaunchDomeFee;
        _reviveBasketFee = _previousReviveBasketFee;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) private {
        require(to != address(0), "Mint: mint to the zero address.");
        require(amount > 0, "Mint: mint amount must be greater than zero.");
        if (_isExcluded[to]) {        
            _rOwned[to] = _rOwned[to].add(amount.mul(_getRate()));
            _tOwned[to] = _tOwned[to].add(amount);  
        } else {
            _rOwned[to] = _rOwned[to].add(amount.mul(_getRate()));
        }
        _rTotal = amount.mul(_getRate());
        _tTotal = amount;

        _tOwned[address(0)] = 0;
        _rOwned[address(0)] = 0;

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
        // also, don't swap & liquify if sender and receiver is excluded.
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
            _swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcluded account then remove the fee
        if (_isExcluded[from] || _isExcluded[to]) {
            takeFee = false;
        }
        //transfer amount, it will take tax, burn, liquidity, revive launch dome, revive basket fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance.sub(half);
        
        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialEthBalance = address(this).balance;
        uint256 initialPulseBalance  = balanceOf(address(this));

        // swap tokens for ETH
        _swapTokensForEth(half); // <- this breaks the ETH -> PULSE swap when swap+liquify is triggered
        // how much ETH did we just swap into?
        uint256 ethAmount = address(this).balance.sub(initialEthBalance);
        uint256 actualPulseSwapped = initialPulseBalance.sub(balanceOf(address(this)));
        otherHalf = otherHalf.add(half - actualPulseSwapped);
        _addLiquidity(otherHalf, ethAmount);
        emit SwapAndLiquify(half, ethAmount, otherHalf);
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> ETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        //approve "tokenAmount" of tokens for the Uniswap Router to use
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

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{
            value: ethAmount
        }(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            minterAddress,
            block.timestamp + 7 days
        );
        
        if(balanceOf(address(this)) > 0) {
            _transfer(address(this), minterAddress, balanceOf(address(this)));
        }
        if(address(this).balance > 0) { 
            payable(minterAddress).transfer(address(this).balance);
        }
    }


    //burn the resulted amount from the total supplies
    function burn(uint256 tokensToBeBurned)
        public
    {
        uint256 currentRate = _getRate();

        _rOwned[_msgSender()] = _rOwned[_msgSender()].sub(
            tokensToBeBurned * currentRate
        );
        if(_isExcluded[_msgSender()]){
            _tOwned[_msgSender()] = _tOwned[_msgSender()].sub(tokensToBeBurned);
        }
        _rTotal = _rTotal.sub(tokensToBeBurned * currentRate);
        _tTotal = _tTotal.sub(tokensToBeBurned);
    }

    function resumeTransactions() public onlyOwner {
        shouldTransfer = true;
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) _removeAllFee();
        Values memory values = _getValues(amount);
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _tOwned[sender] = _tOwned[sender].sub(amount);
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _rOwned[recipient] = _rOwned[recipient].add(values.rTransferAmount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _rOwned[sender] = _rOwned[sender].sub(values.rAmount);
            _tOwned[recipient] = _tOwned[recipient].add(values.tTransferAmount);
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
        //handle fees
        _takeLiquidity(values.tLiquidity);
        _takeReviveLaunchDomeFee(
            values.tReviveLaunchDomeFee
        );
        _takeReviveBasketFee(
            values.tReviveBasketFee
        );
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
        if (!takeFee) _restoreAllFee();
    }
}
