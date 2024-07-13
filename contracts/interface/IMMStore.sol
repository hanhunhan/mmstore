// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;


interface IMMStore {

    struct MiningMachine {
        address user;
        uint256 computingPower;
        uint256 createTime;
        uint256 lastTime;
    }

    struct ClaimOrder{
        address user;
        uint256 amount;
        uint256 orderType;
	uint256 createTime;
    }

    struct TransferOrder{
        address user;
        uint256 amount;
        uint256 number;
        uint256 timestamp;
    }

    struct User{
        address user;
        address ref;
        uint256 registerTime;
    }



    
    struct ClaimedDynReward{
        uint256 ref;
        uint256 team;
        uint256 sameLevel;
        uint256 share;
    }

    
    struct SuperFomo{
        uint256 countdown;
        uint256 poolAmount;
        uint256 rewardAmount;
        uint256 totalBurnAmount;
        address lastUser;
    }


    struct MaxOrderReward {
        uint256 countdown;
        uint256 poolAmount;
        uint256 rewardAmount;
        uint256 maxComputingPower;
        address maxOrderUser;
    }



    struct MachineReward{
        uint256 pendingReward;
        uint256 pendingRebate;
        uint256 claimedReward;
        uint256 rebatedReward;
        bool canClaim;
    }
    struct MachineResponse {
        uint256 computingPower;
        uint256 createTime;
	uint256 countdown;
	uint256 lastTime;
    }

    
}