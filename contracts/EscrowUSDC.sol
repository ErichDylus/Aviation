// SPDX-License-Identifier: MIT
// IN PROCESS

pragma solidity ^0.8.0;

//FOR DEMONSTRATION ONLY, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//buyer or escrow agent creates contract with submitted deposit, total purchase price, description, recipient of funds (seller or financier), days until expiry
//other terms may be determined in offchain negotiations/documentation

contract Escrow {
    
  //escrow struct to contain basic description of underlying asset/deal, purchase price, ultimate recipient of funds, whether complete, number of parties
  struct InEscrow {
      string description;
      uint256 price;
      uint256 deposit;
      address payable recipient;
      bool complete;
      uint256 approvalCount;
  }
  
  InEscrow[] public escrows;
  address escrowAddress = address(this);
  address payable agent;
  address payable buyer;
  address payable recipient;
  uint256 price;
  uint256 deposit;
  uint256 approversCount;
  uint256 index;
  uint256 effectiveTime;
  uint256 expirationTime;
  uint32 constant DAY_IN_SECONDS = 86400;
  bool isExpired;
  string description;
  string terminationReason;
  //map whether an address is a party to the transaction and has authority 
  mapping(address => bool) public parties;
  mapping(address => bool) registeredAddresses;
  
  //events for when party approves closing, purchase price received in escrow, deal closes, deal terminated
  event ReadyToClose(address approver);
  event FundsInEscrow(address buyer);
  event DealClosed();
  event DealTerminated(string terminationReason, bool isExpired);
  
  //restricts to agent (creator of escrow contract) or internal calls
  modifier restricted() {
    require(registeredAddresses[msg.sender] == true, "This may only be called by the Agent or the escrow contract itself");
    _;
  }
  
  // TODO: adapt for USDC payments
  //creator of escrow contract is agent and contributes deposit-- could be third party agent/title co. or simply the buyer
  //initiate escrow with description, USD deposit amount, USD purchase price, unique chosen index number, assign creator as agent, designate recipient (likely seller or financier), and term length
  constructor(string memory _description, uint256 _deposit, uint256 _price, uint256 _index, address payable _creator, address payable _recipient, uint8 _daysUntilExpiration) payable {
      require(msg.value >= deposit, "Submit deposit amount");
      agent = _creator;
      //convert deposit and purchase price to wei from USD
      deposit = (_deposit*10000000000) * 10000000000000000;
      price = (_price*10000000000) * 10000000000000000;
      description = _description;
      recipient = _recipient;
      parties[agent] = true;
      registeredAddresses[agent] = true;
      registeredAddresses[escrowAddress] = true;
      approversCount = 1;
      index = _index;
      effectiveTime = block.timestamp;
      expirationTime = effectiveTime + uint256(DAY_IN_SECONDS * uint32(_daysUntilExpiration));
      isExpired = false;
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
      require(_recipient != recipient, "Party already designated as recipient");
      require(!isExpired, "Too late to change recipient");
      parties[_recipient] = true;
      approversCount++;
      recipient = _recipient;
  }
  
  //amount sent needs to >= total purchase price - deposit, either in one transfer or in installments larger than deposit
  //buyer must be cleared by agent first via approveParty(), to prevent unknown senders
  //in practice, sending total purchase amount would likely happen immediately before closeDeal()
  function sendFunds(uint256 _fundAmount) public payable {
      //funds must be sent in one transaction, and must be greater than or equal to the purchase price - deposit
      require(_fundAmount >= price - deposit, "fundAmount must satisfy outstanding amount of purchase price, minus deposit already received");
      require(_fundAmount <= msg.value, "Submit fundAmount");
      //require funds to come from party to transaction (likely buyer or financier)
      require(parties[msg.sender] == true, "Sender not approved party");
      require(!isExpired, "Deal has expired");
      emit FundsInEscrow(buyer);
  }
  
  //create new escrow contract within master structure, e.g. for split closings or separate deliveries
  function sendEscrow(string memory _description, uint256 _price, uint256 _deposit, address payable _recipient) public restricted {
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
  function approveClosing(uint256 _index) public {
      InEscrow storage escrow = escrows[_index];
      //require approver is a party
      require(parties[msg.sender], "Approver must be a party");
      require(!isExpired, "Escrow has expired");
      checkIfExpired(_index);
      escrow.approvalCount++;
      emit ReadyToClose(msg.sender);
  }
  
  //agent confirms conditions satisfied and finalizes transaction
  function closeDeal(uint256 _index) public restricted {
      InEscrow storage escrow = escrows[_index];
      require(escrowAddress.balance >= price, "Funds not yet received");
      //require approvalCount be greater than or equal to number of approvers
      require(escrow.approvalCount >= approversCount, "All parties must confirm approval of closing");
      require(!escrow.complete, "Deal already completed or terminated");
      checkIfExpired(_index);
      //NOTE: closeDeal transfers entire escrow balance to recipient (including deposit)
      recipient.transfer(escrowAddress.balance);
      escrow.complete = true;
      emit DealClosed();
  }
  
  //allows any party to check if expired (and if so, isExpired resolves true and will prevent closing)
  function checkIfExpired(uint256 _index) public returns(bool){
        if (expirationTime <= block.timestamp) {
            isExpired = true;
            terminateDeal(_index, "Deal has Expired");
        } else {
            isExpired = false;
        }
        return(isExpired);
    }
  
  //only agent may terminate deal, providing a reason for termination and will retain deposit
  function terminateDeal(uint256 _index, string memory _terminationReason) public restricted {
      InEscrow storage escrow = escrows[_index];
      require(!escrow.complete, "Deal already completed or terminated");
      //return funds to buyer (if a different address than agent as assigned via sendFunds()), otherwise return to agent (likely only deposit)
      //NOTE: if buyer has sent remainder of purchase price, if agent terminates escrow the entire balance (including deposit) is remitted to buyer
      if (parties[buyer] == true) {
          buyer.transfer(escrowAddress.balance);
      } else {
          agent.transfer(escrowAddress.balance);
      } 
      escrow.complete = true;
      terminationReason = _terminationReason;
      emit DealTerminated(terminationReason, isExpired);
  }
}
