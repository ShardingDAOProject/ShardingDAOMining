// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../interfaces/IInvitation.sol";
import "../MarketingMiningDelegator.sol";

// Invitaion is the ...
//
// Note that ...
contract Invitation is IInvitation{
    
    struct InvitationInfo{
        address invitor;    
        address[] invitees;
        bool isUsed;
        bool isWithdrawn;
    }
   
    mapping (address => InvitationInfo) public usersInfo;

    MarketingMiningDelegator public activity;
    IERC20 public lptoken;

    function buildMyselfInvitation() public {
        buildInvitation(address(this), address(this));
    }

    function acceptInvitation(address _invitor) external override {
        require(_invitor != msg.sender, 'invitee should not be invitor');
        buildInvitation(_invitor, msg.sender);
        
    }

    function buildInvitation(address _invitor, address _invitee) public{
        InvitationInfo storage invitee = usersInfo[_invitee];
        if(!invitee.isUsed){
            invitee.isUsed = true;
            invitee.isWithdrawn = false;
        }
        require(invitee.invitor == address(0), 'has accepted invitation');
        invitee.invitor = _invitor;
        InvitationInfo storage invitor = usersInfo[_invitor];
        if(!invitor.isUsed){
            invitor.isUsed = true;
        }
        invitor.invitees.push(_invitee);
    }

    function cut() public {
        InvitationInfo storage invitee = usersInfo[msg.sender];
        invitee.isWithdrawn = true;
        address invitorAddress = invitee.invitor;
        InvitationInfo storage invitor = usersInfo[invitorAddress];
        uint256 i = 0;
        for(i; i < invitor.invitees.length; i ++){
            if(invitor.invitees[i] == msg.sender){
                break;
            }
        }
        invitor.invitees[i] = invitor.invitees[invitor.invitees.length - 1];
        invitor.invitees.pop();
    }

    function resetInvitationRelationship(address _user) public {
        InvitationInfo memory senderInfo = usersInfo[_user];
        if(!senderInfo.isUsed)
            return;
        InvitationInfo storage invitorInfo = usersInfo[senderInfo.invitor];
        uint256 targetIndex = 0;
        for(uint256 i = 0; i < invitorInfo.invitees.length; i ++){
            if(invitorInfo.invitees[i] == _user){
                targetIndex = i;
                break;
            }
        }
        invitorInfo.invitees[targetIndex] = invitorInfo.invitees[invitorInfo.invitees.length - 1];
        invitorInfo.invitees.pop();
        for(uint256 i = 0; i < senderInfo.invitees.length; i ++){
            InvitationInfo storage inviteeInfo = usersInfo[senderInfo.invitees[i]];
            delete inviteeInfo.invitor;
        }
        delete usersInfo[_user];
    }

    function getInvitation(address _user) external view override returns(address _invitor, address[] memory _invitees, bool _isWithdrawn) {
        _invitees = usersInfo[_user].invitees;
        _invitor = usersInfo[_user].invitor;
        _isWithdrawn = usersInfo[_user].isWithdrawn;
    }

    function getBlockNum() public view returns(uint256){
        return block.number;
    }

    function setActivityOne(MarketingMiningDelegator _ac) public{
        activity = _ac;
    }

    function setlpToken(IERC20 _lptoken) public{
        lptoken = _lptoken;
    }

    function deposit(uint256 _pid, uint256 _amount) public{
        activity.deposit(_pid, _amount);
    }

    function approve(address _to, uint256 _amount) public{
        lptoken.approve(_to, _amount);
    }
}