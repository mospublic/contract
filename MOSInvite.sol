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

/**
* 规则：
* 1. 奖励分配规则；
* 2. 规则 LEVEL 定义奖励层级；
* 3. decimal & rule 定义权重比例；
#################################################################
 例如：
    reward = 7500000
    decimal = 7500000
    rule = [30,5,5,5,5,5,5,5,5,5]
 解析：
   1级获得 3000000
   2级获得  500000
   3级获得  500000
   4级获得  500000
   5级获得  500000
   6级获得  500000
   7级获得  500000
   8级获得  500000
   9级获得  500000
   10级获得 500000
   主承销商获得  未分配的量
#################################################################
*/
contract MOSInviteInterface {

    function leader() external view returns (address);

    function truster() external view returns (address);

    function decimal() external view returns (uint256);

    function rule() external view returns (uint256[]);

    function checkRule() external view returns (bool);

    function getInviter(address member) external view returns (address);

    function getReward(address member) external view returns (uint256);

    function addMember(address member, address inviter, uint256 reward) external returns (bool);
}

contract MOSInvite is MOSInviteInterface {

    uint256 constant private LEVEL = 12;
    address private _leader;
    address private _truster;
    uint256[] private _rule;
    uint256 private _decimal;
    mapping(address => address) private _inviters;
    mapping(address => uint256) private _rewards;

    event rewardEvent(address member, address receiver, uint256 level, uint256 amount);

    /**
     * #leader: 承销节点自己的地址
     * #truster: 官方调用合约地址
     * #decimal: 将奖励精确划分份额
     * #rule: 每层权重规则
     */
    function MOSInvite(address leader, address truster, uint256 decimal, uint256[] rule) public {
        _truster = truster;
        _leader = leader;
        _decimal = decimal;
        _rule = rule;
        require(_checkRule());
    }

    function leader() external view returns (address) {
        return _leader;
    }

    function truster() external view returns (address) {
        return _truster;
    }

    function rule() external view returns (uint256[]) {
        return _rule;
    }

    function decimal() external view returns (uint256) {
        return _decimal;
    }

    function getInviter(address member) external view returns (address) {
        return _inviters[member];
    }

    function getReward(address member) external view returns (uint256) {
        return _rewards[member];
    }

    function addMember(address member, address inviter, uint256 reward) external returns (bool){
        require(msg.sender == _truster);
        require(_checkRule());
        require(reward > 0);
        require(inviter != address(0x0) && member != address(0x0));
        _addInviter(member, inviter);

        uint256 balance = reward;
        address to = _inviters[member];
        for (uint256 i = 0; i < LEVEL; i++) {
            if (i > _rule.length || balance == 0 || to == address(0x0)) {
                break;
            }
            if (_rule[i] > 0) {
                uint256 amount = SafeMath.div(SafeMath.mul(reward, _rule[i]), _decimal);
                if (balance < amount) {
                    amount = balance;
                }
                _rewards[to] = SafeMath.add(_rewards[to], amount);
                emit rewardEvent(member, to, 1, amount);
                balance = SafeMath.sub(balance, amount);
            }
            to = _inviters[to];
        }
        if (balance > 0) {
            _rewards[_leader] = SafeMath.add(_rewards[_leader], balance);
            emit rewardEvent(member, _leader, 0, balance);
        }
        return true;
    }

    function checkRule() external view returns (bool) {
        return _checkRule();
    }

    function _checkRule() internal view returns (bool) {
        if (_decimal == 0) {
            return false;
        }
        if (_rule.length > LEVEL) {
            return false;
        }
        uint256 sum = 0;
        for (uint256 i = 0; i < _rule.length; i++) {
            sum = SafeMath.add(sum, _rule[i]);
        }
        if (sum <= 0 || sum > _decimal) {
            return false;
        }
        return true;
    }

    function _addInviter(address member, address inviter) internal returns (bool){
        if (_inviters[member] != inviter) {
            _inviters[member] = inviter;
        }
        return true;
    }
}