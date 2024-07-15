// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

 
 

import {StringsUpgradeable} from "../lib/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IERC20Upgradeable} from "../lib/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol"; 
import {UUPSUpgradeable} from "../lib/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "../lib/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSAUpgradeable} from "../lib/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

 



import {BokkyPooBahsDateTimeLibrary} from "../lib/BokkyPooBahsDateTimeLibrary.sol";
import {ACConfig} from "./ACConfig.sol";
import {IMMStore} from "./interface/IMMStore.sol";


interface IACBPair_ {
    function token0()external view returns (address);
    function remove(uint256 amount0,uint256 amount1,address to) external;
    function simpleSwap(address token,address to, uint256 amountIn) external returns(uint256 amountOut);
    function mint(address to) external returns (uint liquidity);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    
}

interface IMinePool {
    function withdraw(address to,uint256 amount) external;
}

contract MMStore is IMMStore,OwnableUpgradeable,UUPSUpgradeable{

    ACConfig public acbConfig;

    User[] public users;
    MiningMachine[] public machineArr;
    ClaimOrder[] public claimOrderArr;
    TransferOrder[] public transferNoOrder;
    TransferOrder[] public transferMaxOrder;

    mapping(address => address) public ref;
    mapping(address => uint256[]) public userMachine;
    mapping(address => bool) public isBuyMachine;
    mapping(string => bool) public isAutoCancel;
    mapping(address => uint256) public claimedAmount;

    uint256 public noOrderPool;
    uint256 public maxOrderPool;
    uint256 public lastOrderTime;
    uint256 public maxOrderIndex;
    uint256 public lastMaxOrderSettleTime;

    mapping(address => mapping(uint256 => uint256)) dynamicReward;

    ClaimOrder[] public claimDynOrderArr;



    error Registered();
    error NotSelf();
    error NoBuyMachine();
    error NoRegistered();
    error TimeNotYet();
    error NotOp();
    error NotConfig();

    modifier onlyConfig(){
        if(msg.sender != address(acbConfig)) revert NotConfig();
        _;
    }

    function initialize(address _acbConfig)external initializer{
        __Ownable_init();

        acbConfig = ACConfig(_acbConfig);
        users.push(
            User(acbConfig.top(),address(0),block.timestamp)
        );
    }

    // required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function changeConfig(address _acbConfig)external onlyOwner{
        acbConfig = ACConfig(_acbConfig);
    }

    function register(address _refAddress)external {
        //if(ref[msg.sender] != address(0)) revert Registered();
        //if(msg.sender == _refAddress) revert NotSelf();
        //The ref address must be someone who has purchased a mining machine or top address
        //if(!isBuyMachine[_refAddress] && _refAddress != btbConfig.top()) revert NoBuyMachine();

        //ref[msg.sender] = _refAddress;
        //users.push(User(msg.sender,_refAddress,block.timestamp));

        //syncPool();
        //autoCancelLp();
    }

    function airdropMachine(address user,uint256 amount) external onlyConfig{
        if(ref[user] == address(0)) revert NoRegistered();
        userMachine[user].push(machineArr.length);
        machineArr.push(MiningMachine(user,amount,block.timestamp,block.timestamp));
        isBuyMachine[msg.sender] = true;

        _settleNoOrderReward();
        _settleMaxOrderReward();
    }

    function buyMachine(uint256 amount,uint256 bType)external {

        //if(ref[msg.sender] == address(0)) revert NoRegistered();

        IERC20Upgradeable(_usdt()).transferFrom(msg.sender, address(this), amount / 2);
	if(bType == 0){
		IERC20Upgradeable(acbConfig.mv()).transferFrom(msg.sender, acbConfig.mvCollectionAddress(), amount / 2 * acbConfig.swapRate() / 1000);
	} else {
		uint256 bPrice = _acbPrice();
		IERC20Upgradeable(_acb()).transferFrom(msg.sender, address(1), amount / 2 / bPrice * 1e18 );
	}

        userMachine[msg.sender].push(machineArr.length);
        machineArr.push(MiningMachine(msg.sender,amount,block.timestamp,block.timestamp));
        isBuyMachine[msg.sender] = true;

        //distribute usdt
        IERC20Upgradeable(_usdt()).transfer(acbConfig.techAddress(), amount / 2 * 20 / 1000); //2% to tech fee
        IERC20Upgradeable(_usdt()).transfer(acbConfig.marketAddress(), amount / 2 * 20 / 1000); //2% to market fee

        //20% buy acb to mine pool
        IERC20Upgradeable(_usdt()).approve(_acbPair(), amount / 2 * 200 / 1000);
        IACBPair_(_acbPair()).simpleSwap(_usdt(), _minePool(), amount / 2 * 200 / 1000);

        //70% add lp
        uint256 uAmount = amount / 2 * 700 / 1000;
        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        uint256 bAmount = _reserveB * uAmount / _reserveU;
        IERC20Upgradeable(_usdt()).transfer(_acbPair(), uAmount);
        IMinePool(_minePool()).withdraw(_acbPair(), bAmount);
        IACBPair_(_acbPair()).mint(address(1));

        _settleNoOrderReward();
        _settleMaxOrderReward();

        noOrderPool += amount / 2 * 35 / 1000; //3.5% to no order pool
        maxOrderPool += amount / 2 * 25 / 1000; //2.5% to max order pool

        syncPool();
        autoCancelLp();
    }
    

    function claim()external {
        uint256[] memory machines = userMachine[msg.sender];
        uint256 reward = 0;
        uint256 bPrice = _acbPrice();
        for(uint256 i = 0; i < machines.length; ++i){
            MiningMachine storage machine = machineArr[machines[i]];
            if(block.timestamp - machine.lastTime <= acbConfig.claimInterval()) revert TimeNotYet();

            uint256 settleTime = block.timestamp < machine.createTime + _machineExpireTime() ? block.timestamp : 
                                                                                               machine.createTime + _machineExpireTime();

            if(settleTime <= machine.lastTime) continue;
            reward += (settleTime - machine.lastTime) * (machine.computingPower/100/86400) / bPrice * 1e18;
            machine.lastTime = settleTime;
        }

        if(reward > 0){
            IMinePool(_minePool()).withdraw(address(this),reward);
            IERC20Upgradeable(_acb()).transfer(msg.sender,reward / 2);

            //add claim record
            claimOrderArr.push(ClaimOrder(msg.sender,reward / 2,0,block.timestamp));
            claimedAmount[msg.sender] += reward / 2;

        }

        syncPool();
        autoCancelLp();
    }



    function claimDynamic(uint256 refAmount,uint256 team,uint256 sameLevel,uint256 share,bytes memory signature)external {
        address user = msg.sender;
        bytes32 ethSignMsg = ECDSAUpgradeable.toEthSignedMessageHash(_getMessageHash(user, refAmount, team, sameLevel, share));
        address recoverAddress = ECDSAUpgradeable.recover(ethSignMsg, signature);

        if(acbConfig.operator() != recoverAddress) revert NotOp();
  
        uint256 refClaimed = dynamicReward[user][0];
        uint256 teamClaimed = dynamicReward[user][1];
        uint256 sameLevelClaimed = dynamicReward[user][2];
        uint256 shareClaimed = dynamicReward[user][3];

        uint256 ableClaim = 0;
        if(refAmount > refClaimed){
            ableClaim += refAmount - refClaimed;
            dynamicReward[user][0] = refAmount;
        }
        if(team > teamClaimed){
            ableClaim += team - teamClaimed;
            dynamicReward[user][1] = team;
        }
        if(sameLevel > sameLevelClaimed){
            ableClaim += sameLevel - sameLevelClaimed;
            dynamicReward[user][2] = sameLevel;
        }
        if(share > shareClaimed){
            ableClaim += share - shareClaimed;
            dynamicReward[user][3] = share;
        }

        if(ableClaim > 0){
            claimOrderArr.push(ClaimOrder(msg.sender,ableClaim / 2,1,block.timestamp));
            IERC20Upgradeable(_acb()).transfer(user, ableClaim);
        }
    }

    function _getMessageHash(address user,uint256 refAmount,uint256 team,uint256 sameLevel,uint256 share) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(user, refAmount, team, sameLevel, share));
    }


    function swap(uint256 amount)external {
        IERC20Upgradeable(_acb()).transferFrom(msg.sender,address(1),amount);//to zero

        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);

        uint256 uAmount = IACBPair_(_acbPair()).getAmountOut(amount, _reserveB, _reserveU);
        uint256 bAmount = _reserveB * uAmount / _reserveU;
        (uint256 amount0,uint256 amount1) = IACBPair_(_acbPair()).token0() == _usdt() ? (uAmount,bAmount) : (bAmount,uAmount);
        IACBPair_(_acbPair()).remove(amount0, amount1, address(this));

        IERC20Upgradeable(_usdt()).transfer(msg.sender,uAmount);
        IERC20Upgradeable(_acb()).transfer(_minePool(),bAmount);

        syncPool();
        autoCancelLp();
    }


    function syncPool()public {
        uint256 minePoolBalance = IERC20Upgradeable(_acb()).balanceOf(_minePool());
        uint256 lpBalance = IERC20Upgradeable(_acb()).balanceOf(_acbPair());

        if(lpBalance <= minePoolBalance + minePoolBalance * 50 / 1000) return;

        //remove lp 1%
        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        IACBPair_(_acbPair()).remove(_reserve0 * 10 / 1000, _reserve1 * 10 / 1000, address(this));
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);

        IERC20Upgradeable(_acb()).transfer(_minePool(),_reserveB * 10 / 1000);
        IERC20Upgradeable(_usdt()).approve(_acbPair(),_reserveU * 10 / 1000);
        IACBPair_(_acbPair()).simpleSwap(_usdt(), _minePool(), _reserveU * 10 / 1000);

    }

    function autoCancelLp()public {
        (uint year, uint month, uint day, uint hour,,) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
        hour += 8;
        if(hour > 24 ){
            day += 1;
            hour -= 24;
        }

        if(hour < 8) return;
        string memory dateString = string(
            abi.encodePacked(StringsUpgradeable.toString(year),StringsUpgradeable.toString(month),StringsUpgradeable.toString(day))
        );

        if(isAutoCancel[dateString]) return;
        isAutoCancel[dateString] = true;

        //remove lp 1%
        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        
        IACBPair_(_acbPair()).remove(_reserve0 * 10 / 1000, _reserve1 * 10 / 1000, address(this));
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);

        IERC20Upgradeable(_acb()).transfer(_minePool(),_reserveB * 10 / 1000);
        IERC20Upgradeable(_usdt()).approve(_acbPair(),_reserveU * 10 / 1000 / 2);
        uint256 amountOut = IACBPair_(_acbPair()).simpleSwap(_usdt(), address(this), _reserveU * 10 / 1000 / 2);

        IERC20Upgradeable(_acb()).transfer(_acbPair(),amountOut);
        IERC20Upgradeable(_usdt()).transfer(_acbPair(), _reserveU * 10 / 1000 / 2);
        IACBPair_(_acbPair()).mint(address(1));

    }




    function _acbPrice()internal view returns(uint256) {
        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        return IACBPair_(_acbPair()).getAmountOut(1 ether, _reserveB, _reserveU);
    }


    function _settleMaxOrderReward()internal {
        if(machineArr.length == 1) return;
        MiningMachine memory curentMaxMachine = machineArr[maxOrderIndex];
        if(block.timestamp - curentMaxMachine.createTime > 1 days
            && block.timestamp - lastMaxOrderSettleTime > 1 days){

            uint256 reward = maxOrderPool * 500 / 1000;
            maxOrderPool -= reward;
            if(reward > 0){
                IERC20Upgradeable(_usdt()).transfer(curentMaxMachine.user,reward);
                transferMaxOrder.push(TransferOrder(curentMaxMachine.user,reward,block.number,block.timestamp));
            }
            lastMaxOrderSettleTime = block.timestamp;
        }

        if(machineArr[machineArr.length - 1].computingPower > curentMaxMachine.computingPower){
            maxOrderIndex = machineArr.length - 1;
        }
    }

    function _settleNoOrderReward()internal {
        if(lastOrderTime > 0 && (block.timestamp - lastOrderTime) > 10 minutes){
            uint256 reward = noOrderPool * 100 / 1000;
            noOrderPool -= reward;
            if(reward > 0) {
                IERC20Upgradeable(_usdt()).transfer(machineArr[machineArr.length - 2].user,reward);
                transferNoOrder.push(TransferOrder(machineArr[machineArr.length - 2].user,reward,block.number,block.timestamp));
            }
        }

        lastOrderTime = block.timestamp;
    }

    
    function _minePool()internal view returns(address){
        return acbConfig.minePool();
    }

    function _usdt()internal view returns(address){
        return acbConfig.usdt();
    }

    function _acb()internal view returns(address){
        return acbConfig.acb();
    }

    function _btbtestup2()external view returns(address){
        return acbConfig.acb();
    }

    function _acbPair()internal view returns(address){
        return acbConfig.acbPair();
    }

    function _machineExpireTime()internal view returns(uint256){
        return acbConfig.machineExpireTime();
    }




    //////////////////////////////////////////////////VIEW////////////////////////////////////////////////////////


    function claimedDynReward(address user)external view returns(ClaimedDynReward memory dynReward){

        dynReward = ClaimedDynReward(
            dynamicReward[user][0],
            dynamicReward[user][1],
            dynamicReward[user][2],
            dynamicReward[user][3]
        );
    }


    function superFomo()external view returns(SuperFomo memory fomo){
        uint256 countdown = lastOrderTime + 10 minutes;

        fomo = SuperFomo(
            block.timestamp >= countdown ? 0 : countdown - block.timestamp,
            noOrderPool,
            noOrderPool * 100 / 1000,
            IERC20Upgradeable(_acb()).balanceOf(address(1)),
            machineArr[machineArr.length - 1].user
        );
    }



    function maxOrderReward()external view returns(MaxOrderReward memory order){
        uint256 countdown = lastMaxOrderSettleTime >= machineArr[maxOrderIndex].createTime ?
                                                 lastMaxOrderSettleTime : machineArr[maxOrderIndex].createTime;
        countdown += 1 days;
        order = MaxOrderReward(
            block.timestamp >= countdown ? 0 : countdown - block.timestamp,
            maxOrderPool,
            maxOrderPool / 2,
            machineArr[maxOrderIndex].computingPower,
            machineArr[maxOrderIndex].user
        );
    }

    function acbPrice()external view returns(uint256) {
        return _acbPrice();
    }

    function swapOutAmount(uint256 amount)external view returns(uint256) {
        (uint112 _reserve0, uint112 _reserve1,) = IACBPair_(_acbPair()).getReserves();
        (uint112 _reserveU,uint112 _reserveB) = IACBPair_(_acbPair()).token0() == _usdt() ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        return IACBPair_(_acbPair()).getAmountOut(amount, _reserveB, _reserveU);
    }

    function computingPower(address user)external view returns(uint256 amount){
        uint256[] memory arr = userMachine[user];

        for(uint256 i = 0; i < arr.length; i++){
            MiningMachine memory machine = machineArr[arr[i]];
            if(machine.createTime + _machineExpireTime() <= block.timestamp) continue;
            amount += machine.computingPower;
        }
    }


    function machineReward(address user)external view returns(MachineReward memory rewardInfo){
        uint256[] memory machines = userMachine[user];
        uint256 reward = 0;
        uint256 bPrice = _acbPrice();
        bool canClaim = true;
        for(uint256 i = 0; i < machines.length; ++i){
            MiningMachine memory machine = machineArr[machines[i]];

            if(block.timestamp - machine.lastTime <= acbConfig.claimInterval()){
                canClaim = false;
            }
            uint256 settleTime = block.timestamp < machine.createTime + _machineExpireTime() ? block.timestamp : machine.createTime + _machineExpireTime();

            if(settleTime <= machine.lastTime) continue;
            reward += (settleTime - machine.lastTime) * (machine.computingPower/100/86400) / bPrice * 1e18;
        }

        rewardInfo = MachineReward(
            reward / 2,
            reward / 2,
            claimedAmount[user],
            claimedAmount[user],
            canClaim
        );
    }

    function getUserByIndex(uint256 start,uint256 end)external view returns(User[] memory userArr) {
        uint256 length = end - start + 1;
        userArr = new User[](length);
        for(uint256 i = 0; i < length; i++){
            userArr[i] = users[start + i];
        }
    }

    function getUserLength()external view returns(uint256) {
        return users.length;
    }

    function getMiningMachineByIndex(uint256 start,uint256 end)external view returns(MiningMachine[] memory miningMachineArr) {
        uint256 length = end - start + 1;
        miningMachineArr = new MiningMachine[](length);
        for(uint256 i = 0; i < length; i++){
            miningMachineArr[i] = machineArr[start + i];
        }
    }

    function getMiningMachineLength()external view returns(uint256) {
        return machineArr.length;
    }


    function getClaimOrderByIndex(uint256 start,uint256 end) external view returns(ClaimOrder[] memory claimOrder) {
        uint256 length = end - start + 1;
        claimOrder = new ClaimOrder[](length);
        for(uint256 i = 0; i < length; i++){
            claimOrder[i] = claimOrderArr[start + i];
        }
    }

    function getClaimOrderLength() external view returns(uint256) {
        return claimOrderArr.length;
    }


    function getNoOrderReward(uint256 index) external view returns(TransferOrder memory) {
        return transferNoOrder[index];
    }

    function getMaxOrderReward(uint256 index) external view returns(TransferOrder memory) {
        return transferMaxOrder[index];
    }


    function userMachineArr(address user)external view returns(MachineResponse[] memory list){
        uint256[] memory idList = userMachine[user];
        list = new MachineResponse[](idList.length);

        for(uint256 i = 0; i < idList.length; i++){
            MiningMachine memory mm = machineArr[idList[i]];
            uint256 countdown = mm.createTime + acbConfig.machineExpireTime() > block.timestamp ? 
                                            mm.createTime + acbConfig.machineExpireTime() - block.timestamp : 0;
            list[i] = MachineResponse(mm.computingPower,mm.createTime,countdown,mm.lastTime);
        }
    }



 


    
}