pragma solidity ^0.6.0;

//FOR DEMONSTRATION ONLY, in process, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//buyer or escrow agent creates contract with submitted deposit, amount and terms determined in offchain negotiations/documentation

/*contract EscrowFactory {
    address[] public deployedEscrows;
    
    //buyer or agent creates new escrow contract by submitting deposit and price amount along with at least as much ether as deposit value
    function createEscrow(uint deposit, uint price) public payable {
        require(msg.value >= deposit * 1 ether);
        address newEscrow = address(new Escrow(deposit, price, msg.sender));
        deployedEscrows.push(newEscrow);
    }
    
    function getDeployedEscrows() public view returns (address[] memory) {
        return deployedEscrows;
    }
}*/

contract Escrow {
    
  //escrow struct to contain basic description of underlying asset/deal, purchase price, ultimate recipient of funds, whether complete, number of parties
  struct InEscrow {
      string description;
      uint price;
      uint deposit;
      address payable recipient;
      bool complete;
      uint approvalCount;
      mapping(address => bool) approvals;
  }
  
  InEscrow[] public escrows;
  address escrowAddress = address(this);
  address payable agent;
  address payable buyer;
  address payable recipient;
  uint price;
  uint deposit;
  uint approversCount;
  uint index;
  string description;
  string terminationReason;
  //map whether an address is a party to the transaction
  mapping(address => bool) public parties;
  
  //restricts to agent (creator of escrow contract)
  modifier restricted() {
    require(msg.sender == agent);
    _;
  }
  
  //creator of escrow contract is agent and contributes deposit-- could be third party agent/title co. or simply one of the parties to transaction
  //initiate escrow with escription, deposit amount, purchase price, assign creator as agent, and recipient (likely seller or financier)
  constructor(string memory _description, uint _deposit, uint _price, address payable _creator, address payable _recipient) public payable {
      require(msg.value >= _deposit * 1 ether, "Submit deposit amount");
      agent = _creator;
      deposit = _deposit;
      price = _price;
      description = _description;
      recipient = _recipient;
      parties[agent] = true;
      approversCount = 1;
      index = 0;
      sendEscrow(description, price, deposit, recipient);
  }
  
  //agent confirms who are parties to the deal and therefore approvers to whether deal may ultimately close
  function approveParty(address _party) public restricted {
      require(!parties[_party], "Party already approved");
      parties[_party] = true;
      approversCount++;
  }
  
  //agent confirms recipient of escrowed funds as extra security measure, or if flow of funds changed since creation of escrow (likely seller or a lienholder)
  function approveRecipient(address payable _recipient) public restricted {
      parties[_recipient] = true;
      approversCount++;
      recipient = _recipient;
  }
  
  //amount sent needs to >= total purchase price - deposit, either in one transfer or in chunks larger than deposit
  //buyer must be cleared by agent first via approveParty(), to prevent unknown senders
  //in practice, sending total purchase amount would likely happen immediately before closeDeal()
  function sendFunds(uint _fundAmount) public payable {
      //funds must be sent in one transaction, and must be greater than or equal to the purchase price - deposit
      require(_fundAmount >= price - deposit, "fundAmount must satisfy outstanding amount of purchase price, minus deposit already received");
      require(_fundAmount <= msg.value);
      //require funds to come from party to transaction (likely buyer or financier)
      require(parties[msg.sender] == true, "Sender not approved party");
      buyer = msg.sender;
  }
  
  //create new escrow contract within master structure, e.g. for split closings or separate deliveries
  function sendEscrow(string memory _description, uint _price, uint _deposit, address payable _recipient) public restricted {
      InEscrow memory newRequest = InEscrow({
         description: _description,
         price: _price,
         deposit: _deposit,
         recipient: _recipient,
         complete: false,
         approvalCount: 0
      });
      escrows.push(newRequest);
  }
  
  //allow each approver (party to deal) confirm ready for closing
  function approveClosing(uint _index) public {
      InEscrow storage escrow = escrows[_index];
      //require approver is a party
      require(parties[msg.sender], "Approver must be a party");
      require(!escrow.approvals[msg.sender], "Already approved by this party");
      escrow.approvals[msg.sender] = true;
      escrow.approvalCount++;
  }
  
  //agent confirms conditions satisfied and finalizes transaction
  function closeDeal(uint _index) public restricted {
      InEscrow storage escrow = escrows[_index];
      require(escrowAddress.balance >= price, "Funds not yet received");
      //require approvalCount be greater than or equal to number of approvers
      require(escrow.approvalCount >= approversCount, "All parties must confirm approval of closing");
      require(!escrow.complete, "Deal already completed or terminated");
      escrow.recipient.transfer(escrow.price);
      escrow.complete = true;
  }
  
  //only agent may terminate deal, providing a reason for termination and will retain deposit
  function terminateDeal(uint _index, string memory _terminationReason) public restricted {
      InEscrow storage escrow = escrows[_index];
      require(!escrow.complete, "Deal already completed or terminated");
      //return deposit to agent (if negotiated as non-refundable)
      //TODO: ensure 'transfer' is the recommended operation 
      agent.transfer(escrow.deposit);
      //return purchase price - deposit to buyer, assuming deposit negotiated as non-refundable
      buyer.transfer(escrow.price - deposit);
      escrow.complete = true;
      terminationReason = _terminationReason;
  }
}
