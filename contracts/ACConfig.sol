// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

 import {IERC20Upgradeable} from "../lib/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {UUPSUpgradeable} from "../lib/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "../lib/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IBTBPair} from "./pair/IBTBPair.sol";

interface IMMStore2 {

    function airdropMachine(address user,uint256 amount)external;
    
}

contract ACConfig is OwnableUpgradeable,UUPSUpgradeable{
    address constant public top = 0xd220B3cf1E4660C5509418B42A86d7945E6E2e18;

    address public usdt;
    address public btb;
    address public usb;
    address public mmStore;
    address public minePool;
    address public btbPair;


    address public platformAddress;
    address public monthDividendAddress;
    uint256 public platformRate;//usb swap to usdt ,usdt transfer to platform address rate
    uint256 public swapRate;//usb swap to usdt rate

    address public usbCollectionAddress;
    address public techAddress;
    address public marketAddress;

    uint256 public minComputingPower;
    uint256 public refRewardOneRate;//15% -> 150/1000
    uint256 public refRewardTwoRate;
    uint256 public sameLevelRewardRate;//10% -> 100/1000

    uint256 public teamRewardRate;//10% -> 100/1000
    address public teamRewardAddress;
    address public remainingAddress;

    uint256 public shareHolderRewardRate;//5% -> 50/1000
    uint256 public shareHolderMinLimit;

    mapping(uint256 => Level) public teamLevel;
    mapping(address => uint256) public userLevel;
    address[] public userArr;

    uint256 public machineExpireTime;
    uint256 public claimInterval;

    address public operator;

    mapping(address => bool) admin;

    uint256 public maxComputingPower;


    struct Level {
        uint256 amount;
        uint256 rate;//10% => 100/1000
    }

    modifier onlyAdmin(){
        require(admin[msg.sender] || msg.sender == owner(),'not admin');
        _;
    }



    function initialize(address _operator)external initializer{
        __Ownable_init();
        operator = _operator;

        platformAddress = 0xdF9228FC02F4554CD80AF6D036dADe242022e4f2;
        monthDividendAddress = 0x4076AF4556458cDd0ad25E86eD23B4dc8437DcE4;
        platformRate = 900;
        swapRate = 1000;

        usbCollectionAddress = 0xFAe25F1Ae4B758D7C96D7Eb075B62af4F3398b89;
        techAddress = 0x7FbA7858083836D9169eb3bE21A48189E1798c8e;
        marketAddress = 0x2737ac6359664096f22863088246d885F14E6FF2;
        
        minComputingPower = 20 ether;
        maxComputingPower = 6000 ether;
        refRewardOneRate = 150;
        refRewardTwoRate = 100;
        sameLevelRewardRate = 100;
        teamRewardRate = 100;
        teamRewardAddress = 0x2737ac6359664096f22863088246d885F14E6FF2;
        remainingAddress = 0xb36F6361dCf31D0D7956E9e826a9915A5ddEC272;
        shareHolderRewardRate = 50;
        shareHolderMinLimit = 20000 ether;

        teamLevel[0] = Level(0,0);
        teamLevel[1] = Level(10000 ether,200);
        teamLevel[2] = Level(30000 ether,350);
        teamLevel[3] = Level(100000 ether,500);

        userLevel[top] = 3;
        userArr.push(top);

        machineExpireTime = 365 days;
        claimInterval = 1 minutes; //1 hours;
    }

    // required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getTeamLevel()external view returns(uint256[] memory amounts,uint256[] memory rates){
        amounts = new uint256[](4);
        rates = new uint256[](4);
        for(uint256 i = 0; i < 4; i++){
            amounts[i] = teamLevel[i].amount;
            rates[i] = teamLevel[i].rate;
        }
    }

    function getRateConfig()external view returns(uint256[] memory rates){
        rates = new uint256[](6);

        rates[0] = refRewardOneRate;
        rates[1] = refRewardTwoRate;
        rates[2] = sameLevelRewardRate;
        rates[3] = teamRewardRate;
        rates[4] = shareHolderRewardRate;
        rates[5] = shareHolderMinLimit;
    }

    function getTeamAddress()external view returns(address[] memory addressArr){
        addressArr = new address[](2);
        addressArr[0] = teamRewardAddress;
        addressArr[1] = remainingAddress;
    }

    function getUserLevels()external view returns(address[] memory users,uint256[] memory levels){
        users = userArr;
        levels = new uint256[](users.length);
        for(uint256 i = 0; i < users.length; i++){
            levels[i] = userLevel[users[i]];
        }
    }

    function setAdmin(address user,bool auth)external onlyOwner{
        admin[user] = auth;
    }

    function changeOperator(address _operator)external onlyOwner{
        operator = _operator;
    }


    function airdropMachine(address user,uint256 amount)external onlyAdmin{
        IMMStore2(mmStore).airdropMachine(user, amount);
    }

    function setUserLevel(address _user,uint256 _level)external onlyAdmin{
        userLevel[_user] = _level;
        userArr.push(_user);
    }

    function setConfig(address _usdt,address _usb,address _btb,address _minePool,address _mmStore,address _btbPair)external onlyAdmin{
        usdt = _usdt;
        usb = _usb;
        btb = _btb;
        minePool = _minePool;
        mmStore = _mmStore;
        btbPair = _btbPair;
    }



    function changeMachineExpireTime(uint256 _machineExpireTime)external onlyAdmin{
        machineExpireTime = _machineExpireTime;
    }

    function changeClaimInterval(uint256 _claimInterval)external onlyAdmin{
        claimInterval = _claimInterval;
    }

    function changeTeamLevel(uint256[] memory _amount,uint256[] memory _rate)external onlyAdmin{
        require(_amount.length == _rate.length,'length error');

        for(uint256 i = 0; i < _amount.length; ++i){
            teamLevel[i] = Level(_amount[i],_rate[i]);
        }
    }

    function changeShareHolderMinLimit(uint256 _shareHolderMinLimit)external onlyAdmin{
        shareHolderMinLimit = _shareHolderMinLimit;
    }

    function changeShareHolderRewardRate(uint256 _shareHolderRewardRate)external onlyAdmin{
        shareHolderRewardRate = _shareHolderRewardRate;
    }

    function changeRemainingAddress(address _remainingAddress)external onlyAdmin{
        remainingAddress = _remainingAddress;
    }

    function changeTeamRewardAddress(address _teamRewardAddress)external onlyAdmin{
        teamRewardAddress = _teamRewardAddress;
    }

    function changeTeamRewardRate(uint256 _teamRewardRate)external onlyAdmin{
        teamRewardRate = _teamRewardRate;
    }
    function changeSameLevelRewardRate(uint256 _sameLevelRewardRate)external onlyAdmin{
        sameLevelRewardRate = _sameLevelRewardRate;
    }

    function changeRefRewardRate(uint256 _oneRate,uint256 _twoRate)external onlyAdmin{
        refRewardOneRate = _oneRate;
        refRewardTwoRate = _twoRate;
    }

    function changeMinComputingPower(uint256 _minComputingPower) external onlyAdmin{
        minComputingPower = _minComputingPower;
    }

    function changeMaxComputingPower(uint256 _maxComputingPower) external onlyAdmin{
        maxComputingPower = _maxComputingPower;
    }

    function changeUsbCollectionAddress(address _usbCollectionAddress) external onlyAdmin{
        usbCollectionAddress = _usbCollectionAddress;
    }

    function changeTechAddress(address _techAddress) external onlyAdmin{
        techAddress = _techAddress;
    }

    function changeMarketAddress(address _marketAddress) external onlyAdmin{
        marketAddress = _marketAddress;
    }

    function changePlatformAddress(address _platformAddress)external onlyAdmin {
        platformAddress = _platformAddress;
    }

    function changeMonthDividenAddress(address _monthDividendAddress) external onlyAdmin {
        monthDividendAddress = _monthDividendAddress;
    }

    function changeSwapRate(uint256 _swapRate)external onlyAdmin {
        swapRate = _swapRate;
    }

    function changePlatformRate(uint256 _platformRate)external onlyAdmin {
        platformRate = _platformRate;
    }


}