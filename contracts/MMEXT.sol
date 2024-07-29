// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

 
 

import {StringsUpgradeable} from "../lib/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IERC20Upgradeable} from "../lib/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol"; 
import {UUPSUpgradeable} from "../lib/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "../lib/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSAUpgradeable} from "../lib/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

 



import {BokkyPooBahsDateTimeLibrary} from "../lib/BokkyPooBahsDateTimeLibrary.sol";
//import {ACConfig} from "./ACConfig.sol";
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



interface ACCONFIG {
    function usdt()external view returns (address);
    function platformAddress()external view returns (address);
    function mv()external view returns (address);
    function swapRate()external view returns (uint256 );
    function buylocked()external view returns (uint );
    function mvCollectionAddress() external view returns (address);  
    function techAddress() external view returns (address);
    function marketAddress() external view returns (address); 
    function claimInterval()external view returns (uint256 );
    function operator() external view returns (address); 
    function minePool() external view returns (address); 
    function acb() external view returns (address); 
    function acbPair() external view returns (address); 
    function machineExpireTime() external view returns (uint256);
    
     
    
}
interface MMSTORE is IMMStore{
   
    
    function getNoOrderRewardArr() external view returns(TransferOrder[] memory) ;
    function transferNoOrder() external view returns(TransferOrder[] memory) ;

}
contract MMEXT is IMMStore,OwnableUpgradeable,UUPSUpgradeable{

     
    address public MMstore;

     
    MiningMachine[] public machineArr;
    ClaimOrder[] public claimOrderArr;
    TransferOrder[] public NoOrder;
    TransferOrder[] public transferMaxOrder;

 
  

  



  
    function initialize( address _store)external initializer{
        __Ownable_init();

       
        MMstore = _store;
     
    }

    
    function _authorizeUpgrade(address) internal override onlyOwner {}

    
    
    function changeMmstore(address _store)external onlyOwner{
        MMstore = _store;
    }
 
 

    function getNoOrderRewardByIndex(uint256 start,uint256 end) external view returns(TransferOrder[] memory NoOrderReward) {
        TransferOrder[] memory NoOrderr = MMSTORE(MMstore).getNoOrderRewardArr();
        uint256 length = end - start + 1;
        NoOrderReward = new TransferOrder[](length);
        for(uint256 i = 0; i < length; i++){
            NoOrderReward[i] = NoOrderr[start + i];
        }
    }


    function getNoOrderRewardBy( ) external view returns(TransferOrder[] memory NoOrderReward) {
        NoOrderReward = MMSTORE(MMstore).getNoOrderRewardArr();
       
    }

   


    
}

 