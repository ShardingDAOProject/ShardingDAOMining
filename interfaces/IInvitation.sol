pragma solidity 0.6.12;

interface IInvitation{

    function acceptInvitation(address _invitor) external;

    function getInvitation(address _sender) external view returns(address _invitor, address[] memory _invitees, bool _isWithdrawn);
    
}
