//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract nftstaking is ReentrancyGuard {
   using SafeERC20 for IERC20;//using the safeErc20 function to send tokens to addresses that wants to claim staking rewards

   IERC20 public immutable rewardsToken;//this interface is for our reward token FROM THE IERc20 contract
   IERC721 public immutable PtCollection;//this interface is for our nft collcetion from the IErC721 contract

   //running our constructor

   constructor(IERC721 _nftaddress, IERC20 __rewardToken) {
      rewardsToken = __rewardToken; //initializing the reward token address
      PtCollection = _nftaddress;//intializing the nft collection address
   }

   struct StakedToken { //this struct containing detains of the staked token
    address staker;
    uint256 tokenId;
   }

   struct Staker {
     uint256 stakedAmount; //amount of token staked 

     StakedToken [] stakedTokens; //staked tokens

     uint256 lastTimeUpdated;//this updates when a user withdraws or stake more nfts

     uint256 unclaimedTokens;//amount of tokens not claimed overtime
   }
     mapping (address => Staker) public stakers;//mapping of address to the Staker info
     mapping(uint256 => address) public stakerAddress;//this makes the contract remember stakers and their staked token
     uint256 private rewardPerHour = 100;// this is the reward per token per hour for stakers
   

   function stakeToken(uint256 _tokenId) external nonReentrant {
    //the first code calculates the rwards on an O staker before adding new token
    //so if the staker was earning 50 tokens...he will be getting extra 50 token for staking a new token
     if(stakers[msg.sender].stakedAmount > 0){
        uint rewards = calculateRewards(msg.sender);
        stakers[msg.sender].unclaimedTokens += rewards;

        require(PtCollection.ownerOf(_tokenId) == msg.sender, "you dont own this token");//sanity check
        PtCollection.transferFrom(msg.sender, address(this), _tokenId);//transferring token from msg.sender to contract for staking
     }

     StakedToken memory stakedToken = StakedToken(msg.sender, _tokenId); // this is for a token that got transferred to the contract

     stakers[msg.sender].stakedTokens.push(stakedToken);//adding the token to the stake token array

     stakers[msg.sender].stakedAmount++;//increasing the amount staked for this wallet

     stakerAddress[_tokenId] = msg.sender;//updating the mapping address of the tokenid to stakerAddress

     stakers[msg.sender].lastTimeUpdated = block.timestamp;//the last time of the staker
   }

   function withdrawToken(uint256 _tokenId) external nonReentrant {//this function is the opposite of the staking funtion

        require(stakers[msg.sender].stakedAmount > 0, "no tokens staked");
        require(PtCollection.ownerOf(_tokenId) == msg.sender, "not the owner of this token");//you must own the token you are trying to withdraw
        //now updating the reward of the user since less token equals less reward
        uint rewards = calculateRewards(msg.sender);
        stakers[msg.sender].unclaimedTokens += rewards;

         //finding the staked tokens in the arrays of staked tokens
         uint256 index = 0;
         for(uint256 i = 0; i < stakers[msg.sender].stakedTokens.length; ++i) {
          if(stakers[msg.sender].stakedTokens[i].tokenId == _tokenId) {
                index = 1;
                break;
            }
         }

         stakers[msg.sender].stakedTokens[index].staker = address(0);// removing the index from the staker arry
         stakers[msg.sender].stakedAmount--;//there is a decrease in amount stake for the wallet
         stakerAddress[_tokenId] = address(0);//updating the mapping of the tokenId to be address 0 that the token is no longer staked
         
         //transferring the token back to the withdrawer
         PtCollection.transferFrom(address(this), msg.sender, _tokenId);

         stakers[msg.sender].lastTimeUpdated =block.timestamp;//updating the last time of the withdraw

   }


      function claimRewards() external payable {
        //calculating the rewards for the user from the time of the lastupdate plus the unclaimed reward
        uint256 rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedTokens;
        require(rewards > 0, "You have no rewards to claim");//the reward is greater then 0 before you can reward
        stakers[msg.sender].lastTimeUpdated = block.timestamp;//settimg the lastupdatetime to the current timestamp
        stakers[msg.sender].unclaimedTokens = 0;//now setting the umclaimed token to 0
        rewardsToken.safeTransfer(msg.sender, rewards);//transfering the rewards to the staker from the contract
    }

        function calculateRewards(address _staker)
        internal
        view
        returns (uint256 _rewards)
    {
        Staker memory staker = stakers[_staker];
        return (((
            ((block.timestamp - staker.lastTimeUpdated) * staker.stakedAmount)
        ) * rewardPerHour) / 3600);
    }

    function availableReward (address _staker) public view returns(uint256) {
        //get available tokens by calculatin reward plus total unclaimed tokens
        uint256 rewards = calculateRewards(_staker) + stakers[_staker].unclaimedTokens;
        return rewards;
    }

    function getStakedTokens(address _user) public view returns (StakedToken[] memory) {
        //checking if this users is onboard
        if(stakers[_user].stakedAmount > 0) {
            //return all the tokens in the staked-array for the users that are not below -1
            StakedToken[] memory _stakedTokens = new StakedToken[](stakers[_user].stakedAmount);
            uint256 _index = 0;

            for(uint256 i = 0; i < stakers[_user].stakedTokens.length; i++){
               if(stakers[_user].stakedTokens[i].staker != (address(0))){
                _stakedTokens[_index] = stakers[_user].stakedTokens[i];
                _index++;

               }

            }

            return _stakedTokens;
        }

        else{
            return new StakedToken[](0);//return an empty array...
        }
    }


}