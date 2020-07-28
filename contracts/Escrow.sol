pragma solidity ^0.6.0;

//IN PROCESS, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//escrow agent creates contract with submitted deposit (parties would directly pay deposit as escrow fee to agent separately, upon engagement)
//higher deposit requested by seller could be addressed in contribute()

contract EscrowFactory {
    address[] public deployedEscrows;
    
    function createEscrow(uint deposit) public {
        address newEscrow = address(new Escrow(deposit, msg.sender));
        deployedEscrows.push(newEscrow);
    }
    
    function getDeployedEscrows() public view returns (address[] memory) {
        return deployedEscrows;
    }
}

contract Escrow {

  struct InEscrow {
      string description;
      uint value;
      address payable recipient;
      bool complete;
      uint approvalCount;
      mapping(address => bool) approvals;
  }
  
  InEscrow[] public escrows;
  address public agent;
  uint minimumContribution;
  uint public approversCount;
  mapping(address => bool) public approvers;
  
  //restricts to agent (creator of escrow contract)
  modifier restricted() {
    require(msg.sender == agent);
    _;
  }
  
  //creator of escrow contract is agent and contributes deposit-- TODO: deposit returned to creator/agent after termination/failure of transaction
  constructor(uint deposit, address creator) public {
      agent = creator;
      minimumContribution = deposit;
  }
  
  //contribute value will need to ultimately == purchase price - deposit 
  function contribute() public payable {
      require(msg.value > minimumContribution);
      approvers[msg.sender] = true;
      approversCount++;
  }
  
  function sendEscrow(string memory description, uint value, address payable recipient) public restricted {
      InEscrow memory newRequest = InEscrow({
         description: description,
         value: value,
         recipient: recipient,
         complete: false,
         approvalCount: 0
      });
      escrows.push(newRequest);
  }
  
  function approveRequest(uint index) public {
      InEscrow storage escrow = escrows[index];
      require(approvers[msg.sender]);
      require(!escrow.approvals[msg.sender]);
      escrow.approvals[msg.sender] = true;
      escrow.approvalCount++;
  }
  
  function finalizeRequest(uint index) public restricted {
      InEscrow storage escrow = escrows[index];
      require(escrow.approvalCount > (approversCount / 2));
      require(!escrow.complete);
      escrow.recipient.transfer(escrow.value);
      escrow.complete = true;
  }
}
