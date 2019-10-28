pragma solidity ^0.4.21;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract MOSClashInterface {

    function mosToken() external view returns (MOSToken);

    function truster() external view returns (address);

    function clashPool() external view returns (address);

    function levelPrice(uint level) external view returns (uint256);

    function clashPrice() external view returns (uint256);

    function clashLevel() external view returns (uint256);

    function clashLevelAmount() external view returns (uint256);

    function clashLevelBalance() external view returns (uint256);

    function clashedAmount(address account) external view returns (uint256);

    function clashedUsdtAmount() external view returns (uint256);

    function clashedMosAmount() external view returns (uint256);

    function clashMosBalance() external view returns (uint256);

    function clash(address clashAccount, uint256 usdtAmount) external returns (bool);
}


contract MOSToken {
    function balanceOf(address account) public view returns (uint256);

    function allowance(address owner, address spender) public view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
}

contract MOSClash is MOSClashInterface {

    // CONSTANT
    uint256 constant private MOS_DECIMALS = 1e18;
    uint256 constant private MAX_LEVEL = 3618;
    uint256 constant private LEVEL_AMOUNT = 45000 * 1e6;
    uint256 constant private LEVEL_PRICE = 0.500 * 1e6;
    // ACCOUNT
    MOSToken private _mosToken;
    address private _truster;
    address private _clashPool;

    // DATA
    uint256 private _level = 1;
    uint256 private _levelBalance = LEVEL_AMOUNT;
    uint256 private _price = LEVEL_PRICE;
    mapping(address => uint256) private _clasheds;
    uint256 private _usdtAmount = 0;
    uint256 private _mosAmount = 0;

    // EVENT
    event clashEvent(address clashAccount, uint256 clashLevel, uint256 clashPrice, uint256 clashAmount, uint256 usdtAmount);

    function MOSClash(MOSToken mosToken, address truster, address clashPool) public {
        _mosToken = mosToken;
        _truster = truster;
        _clashPool = clashPool;
    }

    function mosToken() external view returns (MOSToken) {
        return _mosToken;
    }

    function truster() external view returns (address) {
        return _truster;
    }

    function clashPool() external view returns (address) {
        return _clashPool;
    }

    // EXTERNAL
    function clashPrice() external view returns (uint256) {
        return _price;
    }

    function clashLevel() external view returns (uint256) {
        return _level;
    }

    function clashLevelAmount() external view returns (uint256){
        return LEVEL_AMOUNT;
    }

    function clashLevelBalance() external view returns (uint256){
        return _levelBalance;
    }

    function clashedAmount(address account) external view returns (uint256){
        return _clasheds[account];
    }

    function clashedUsdtAmount() external view returns (uint256){
        return _usdtAmount;
    }

    function clashedMosAmount() external view returns (uint256){
        return _mosAmount;
    }

    function clashMosBalance() external view returns (uint256) {
        return _mosToken.balanceOf(_clashPool);
    }

    function levelPrice(uint level) external view returns (uint256) {
        require(0 < level && level <= MAX_LEVEL);
        return _levelPrice(level);
    }

    function clash(address clashAccount, uint256 usdtAmount) external returns (bool) {
        require(msg.sender == _truster);
        require(usdtAmount > 0);
        require(SafeMath.add(_usdtAmount, usdtAmount) <= SafeMath.mul(LEVEL_AMOUNT, MAX_LEVEL));
        //solhint-disable-line indent
        _usdtAmount = SafeMath.add(_usdtAmount, usdtAmount);
        //solhint-disable-line indent
        uint256 clashAmount = _clashHandle(clashAccount, usdtAmount);
        //solhint-disable-line indent
        require(_mosToken.balanceOf(_clashPool) >= clashAmount);
        require(_mosToken.allowance(_clashPool, address(this)) >= clashAmount);
        _mosToken.transferFrom(_clashPool, _truster, clashAmount);
        // //solhint-disable-line indent
        _clasheds[clashAccount] = SafeMath.add(_clasheds[clashAccount], clashAmount);
        _mosAmount = SafeMath.add(_mosAmount, clashAmount);
        return true;
    }

    // INTERNAL
    function _levelPrice(uint level) internal pure returns (uint256) {
        return SafeMath.div(SafeMath.mul(MAX_LEVEL, LEVEL_PRICE), SafeMath.sub(MAX_LEVEL + 1, level));
    }

    function _clashHandle(address clashAccount, uint usdtAmount) internal returns (uint256){
        uint256 clashAmount = 0;
        while (usdtAmount > 0) {
            uint256 _clashAmount = 0;
            if (usdtAmount > _levelBalance) {
                _clashAmount = SafeMath.div(SafeMath.mul(_levelBalance, MOS_DECIMALS), _price);
                emit clashEvent(clashAccount, _level, _price, _clashAmount, _levelBalance);
                //solhint-disable-line indent
                clashAmount = SafeMath.add(clashAmount, _clashAmount);
                usdtAmount = SafeMath.sub(usdtAmount, _levelBalance);
                //solhint-disable-line indent
                _level = SafeMath.add(_level, 1);
                _levelBalance = LEVEL_AMOUNT;
                _price = _levelPrice(_level);
            } else if (usdtAmount == _levelBalance) {
                _clashAmount = SafeMath.div(SafeMath.mul(_levelBalance, MOS_DECIMALS), _price);
                emit clashEvent(clashAccount, _level, _price, _clashAmount, _levelBalance);
                //solhint-disable-line indent
                clashAmount = SafeMath.add(clashAmount, _clashAmount);
                usdtAmount = SafeMath.sub(usdtAmount, _levelBalance);
                //solhint-disable-line indent
                _level = SafeMath.add(_level, 1);
                _levelBalance = LEVEL_AMOUNT;
                _price = _levelPrice(_level);
            } else {
                _clashAmount = SafeMath.div(SafeMath.mul(usdtAmount, MOS_DECIMALS), _price);
                if (_clashAmount > 0) {
                    emit clashEvent(clashAccount, _level, _price, _clashAmount, usdtAmount);
                    //solhint-disable-line indent
                    _levelBalance = SafeMath.sub(_levelBalance, usdtAmount);
                    //solhint-disable-line indent
                    clashAmount = SafeMath.add(clashAmount, _clashAmount);
                    usdtAmount = 0;
                } else {
                    _levelBalance = SafeMath.sub(_levelBalance, usdtAmount);
                    usdtAmount = 0;
                }
            }
        }
        return clashAmount;
    }
}