// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//FOR DEMONSTRATION ONLY, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//buyer or agent (likely party to handle any meatspace filings) creates contract with submitted deposit, total purchase price, description, recipient of funds (seller or financier), days until expiry
//other terms may be determined in offchain negotiations/documentation and memorialized by hash to IPFS or other decentralized file storage

interface IERC20 { 
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool); 
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract Escrow {
    
  //escrow struct to contain description of underlying asset/deal (or IPFS hash to documents), purchase price, ultimate recipient of funds, whether complete, number of parties
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
  uint256 expirationTime;
  uint32 constant DAY_IN_SECONDS = 86400;
  bool isExpired;
  string description;
  string terminationReason;
  IERC20 public ierc20;
  mapping(address => bool) public parties; //map whether an address is a party to the transaction and has authority for restricted modifier
  mapping(address => bool) registeredAddresses;
  
  //events for when party approves closing, purchase price received in escrow, deal closes, deal terminated
  event ReadyToClose(address approver);
  event FundsInEscrow(address buyer);
  event DealClosed(uint256 indexed index, uint256 effectiveTime);
  event DealTerminated(string terminationReason, bool isExpired);
  
  //restricts to agent (creator of escrow contract) or internal calls
  modifier restricted() {
    require(registeredAddresses[msg.sender], "This may only be called by the Agent or the escrow contract itself");
    _;
  }
  
  //creator of escrow contract is agent and contributes deposit-- could be third party agent/title co. or simply the buyer
  //initiate escrow with description, USD deposit amount, USD purchase price, unique deal index number, assign creator as agent, designate recipient (likely seller or financier), and term length
  //agent for purposes of this contract could be the entity handling meatspace filings (could be party to transaction or filing agent)
  //CREATOR MUST SEPARATELY APPROVE (by interacting with the ERC20 contract in question's approve()) this contract address for the full price amount (keep decimals in mind)
  constructor(string memory _description, uint256 _deposit, uint256 _price, uint256 _index, address _token, address payable _creator, address payable _recipient, uint8 _daysUntilExpiration) payable {
      ierc20 = IERC20(_token);
      agent = _creator;
      deposit = _deposit;
      price = _price;
      description = _description;
      recipient = _recipient;
      parties[agent] = true;
      registeredAddresses[agent] = true;
      registeredAddresses[escrowAddress] = true;
      approversCount = 1;
      index = _index;
      expirationTime = block.timestamp + uint256(DAY_IN_SECONDS * uint32(_daysUntilExpiration));
      isExpired = false;
      ierc20.allowance(escrowAddress, recipient);
      ierc20.approve(recipient, price);
      ierc20.approve(msg.sender, price);
  }
  
  function sendDeposit() public restricted returns(bool, uint256) {
      ierc20.transferFrom(agent, escrowAddress, deposit);
      sendEscrow(description, price, deposit, recipient);
      return (true, ierc20.balanceOf(escrowAddress));
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
      require(parties[msg.sender], "Sender not approved party"); //require funds to come from party to transaction (likely buyer or financier)
      require(!isExpired, "Deal has expired");
      ierc20.transferFrom(msg.sender, escrowAddress, _fundAmount); //transfer funds to escrow
      emit FundsInEscrow(agent);
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
      require(ierc20.balanceOf(escrowAddress) >= price, "Funds not yet received"); //require escrow to hold at least as much as the price in order to close
      require(escrow.approvalCount >= approversCount, "All parties must confirm approval of closing"); //require approvalCount be greater than or equal to number of approvers
      require(!escrow.complete, "Deal already completed or terminated");
      checkIfExpired(_index);
      ierc20.transferFrom(escrowAddress, recipient, ierc20.balanceOf(escrowAddress)); //transfer entire escrowed balance to recipient
      escrow.complete = true;
      emit DealClosed(index, block.timestamp);
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
      if (parties[buyer]) {
          buyer.transfer(escrowAddress.balance);
          ierc20.transferFrom(escrowAddress, buyer, ierc20.balanceOf(escrowAddress));
      } else {
          agent.transfer(escrowAddress.balance);
          ierc20.transferFrom(escrowAddress, agent, ierc20.balanceOf(escrowAddress));
      } 
      escrow.complete = true;
      terminationReason = _terminationReason;
      emit DealTerminated(terminationReason, isExpired);
  }
}
