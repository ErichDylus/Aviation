pragma solidity ^0.6.0;

//in process, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//buyer or escrow agent creates contract with submitted deposit, amount and terms determined in offchain negotiations/documentation

contract EscrowFactory {
    address[] public deployedEscrows;
    
    //buyer or agent creates new escrow contract by submitting deposit amount
    function createEscrow(uint deposit, uint price) public payable {
        require(msg.value >= deposit);
        address newEscrow = address(new Escrow(deposit, price, msg.sender));
        deployedEscrows.push(newEscrow);
    }
    
    function getDeployedEscrows() public view returns (address[] memory) {
        return deployedEscrows;
    }
}

contract Escrow {
    
  //escrow struct to contain basic description of underlying asset/deal, purchase price, ultimate recipient of funds, whether complete, number of parties
  struct InEscrow {
      string description;
      uint price;
      address payable recipient;
      bool complete;
      uint approvalCount;
      mapping(address => bool) approvals;
  }
  
  InEscrow[] public escrows;
  address public agent;
  address escrowAddress = address(this);
  uint price;
  uint deposit;
  uint public approversCount;
  //map whether an address is a party to the transaction
  mapping(address => bool) public parties;
  
  //restricts to agent (creator of escrow contract)
  modifier restricted() {
    require(msg.sender == agent);
    _;
  }
  
  //creator of escrow contract is agent and contributes deposit-- could be third party agent/title co. or simply one of the parties to transaction
  //TODO: deposit returned to creator/agent after termination/failure of transaction
  //initiate escrow with deposit amount, purchase price and assign creator as agent
  constructor(uint _deposit, uint _price, address creator) public payable {
      agent = creator;
      deposit = _deposit;
      price = _price;
  }
  
  //amount sent needs to == total purchase price - deposit, either in one transfer or in chunks larger than deposit
  //in practice, sending total purchase amount would likely happen immediately before closeDeal()
  //TODO: anyone contributing enough money would become a party, might need to gate
  function sendFunds() public payable {
      require(msg.value >= deposit);
      //if sending funds, include as party to transaction (likely buyer or financier)
      parties[msg.sender] = true;
      approversCount++;
  }
  
  //create new escrow contract within master structure, e.g. for split closings or separate deliveries
  function sendEscrow(string memory description, uint _price, address payable recipient) public restricted {
      InEscrow memory newRequest = InEscrow({
         description: description,
         price: _price,
         recipient: recipient,
         complete: false,
         approvalCount: 0
      });
      escrows.push(newRequest);
  }
  
  //allow each approver (party to deal) confirm ready for closing
  function approveClosing(uint index) public {
      InEscrow storage escrow = escrows[index];
      //require approver is a party
      require(parties[msg.sender]);
      require(!escrow.approvals[msg.sender]);
      escrow.approvals[msg.sender] = true;
      escrow.approvalCount++;
  }
  
  //agent confirms conditions satisfied and finalizes transaction
  function closeDeal(uint index) public restricted {
      InEscrow storage escrow = escrows[index];
      //require purchase price in escrow and all involved parties confirm ready for closing
      require(escrowAddress.balance >= price);
      require(escrow.approvalCount == approversCount);
      require(!escrow.complete);
      escrow.recipient.transfer(escrow.price);
      escrow.complete = true;
  }
}
