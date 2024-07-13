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


 
contract test is IMMStore,OwnableUpgradeable,UUPSUpgradeable{

    address public btbConfig;

    address public recoverAddress;

    uint256 public returnsss;
 

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
        if(msg.sender != address(btbConfig)) revert NotConfig();
        _;
    }

    function initialize(address _btbConfig)external initializer{
        __Ownable_init();

        btbConfig = _btbConfig;
        returnsss = 0;
        
    }

    // required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}
  
 


    function testsig(uint256 refAmount,uint256 team,uint256 sameLevel,uint256 share,bytes memory signature)external {
        address user = 0x1516EfE4F8Bf4b843fB4016e1ea8c819ea106845;//msg.sender;
        bytes32 ethSignMsg = ECDSAUpgradeable.toEthSignedMessageHash(_getMessageHash(user, refAmount, team, sameLevel, share));
        recoverAddress = ECDSAUpgradeable.recover(ethSignMsg, signature);
        if(btbConfig != recoverAddress) revert NotOp();
        returnsss = 1;
   
    }

    function _getMessageHash(address user,uint256 refAmount,uint256 team,uint256 sameLevel,uint256 share) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(user, refAmount, team, sameLevel, share));
    }

    function getReturnsss()internal view returns(uint256){
        return returnsss;
    }

    function getBtbConfig()internal view returns(address){
        return btbConfig;
    }

    function getRecoverAddress()internal view returns(address){
        return recoverAddress;
    }

  
 


 


    
}