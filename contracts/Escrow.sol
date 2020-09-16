pragma solidity ^0.6.0;

//FOR DEMONSTRATION ONLY, not recommended to be used for any purpose
//@dev create a smart escrow contract for purposes of an aircraft sale transaction
//buyer or escrow agent creates contract with submitted deposit, total purchase price, description, recipient of funds (seller or financier)
//other terms may be determined in offchain negotiations/documentation

interface AggregatorV3Interface {
  function latestAnswer() external view returns (int256);
  function latestTimestamp() external view returns (uint256);
  function latestRound() external view returns (uint256);
  function getAnswer(uint256 roundId) external view returns (int256);
  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

//@dev use Chainlink ETH/USD price feed aggregator on Kovan to convert price
contract USDConvert {

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Kovan
     * Aggregator: ETH/USD
     * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    constructor() public payable {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
    }
  
    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int256) {
        return priceFeed.latestAnswer();
    }

    /**
     * Returns the timestamp of the latest price update
     */
    function getLatestPriceTimestamp() public view returns (uint256) {
        return priceFeed.latestTimestamp();
    }
}

contract Escrow is USDConvert {
    
  //escrow struct to contain basic description of underlying asset/deal, purchase price, ultimate recipient of funds, whether complete, number of parties
  struct InEscrow {
      string description;
      uint256 price;
      uint256 deposit;
      address payable recipient;
      bool complete;
      uint256 approvalCount;
      mapping(address => bool) approvals;
  }
  
  InEscrow[] public escrows;
  address escrowAddress = address(this);
  address payable agent;
  address payable buyer;
  address payable recipient;
  uint256 ethPrice;
  uint256 price;
  uint256 deposit;
  uint256 approversCount;
  uint256 index;
  string description;
  string terminationReason;
  //map whether an address is a party to the transaction
  mapping(address => bool) public parties;
  
  //events for when party approves closing, purchase price received in escrow, deal closes, deal terminated
  event ReadyToClose(address approver);
  event FundsInEscrow(address buyer);
  event DealClosed();
  event DealTerminated(string terminationReason);
  
  //restricts to agent (creator of escrow contract)
  modifier restricted() {
    require(msg.sender == agent, "This may only be called by the Agent");
    _;
  }
  
  //creator of escrow contract is agent and contributes deposit-- could be third party agent/title co. or simply the buyer
  //initiate escrow with escription, deposit amount in USD, purchase price in USD, assign creator as agent, and recipient (likely seller or financier)
  constructor(string memory _description, uint256 _deposit, uint256 _price, address payable _creator, address payable _recipient) public payable {
      priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
      //get price of ETH in dollars, rounded to nearest dollar, when escrow constructed/value sent
      ethPrice = uint256((getLatestPrice()));
      require(msg.value >= deposit, "Submit deposit amount");
      agent = _creator;
      //convert deposit and purchase price to wei from USD
      deposit = ((_deposit*10000000000)/ethPrice) * 10000000000000000;
      price = ((_price*10000000000)/ethPrice) * 10000000000000000;
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
  
  
  //check ETH price in dollars, rounded to nearest dollar
  function checkPrice() public view returns (uint256) {
        return ethPrice;
  }
  
  //amount sent needs to >= total purchase price - deposit, either in one transfer or in chunks larger than deposit
  //buyer must be cleared by agent first via approveParty(), to prevent unknown senders
  //in practice, sending total purchase amount would likely happen immediately before closeDeal()
  function sendFunds(uint256 _fundAmount) public payable {
      //funds must be sent in one transaction, and must be greater than or equal to the purchase price - deposit
      require(_fundAmount >= price - deposit, "fundAmount must satisfy outstanding amount of purchase price, minus deposit already received");
      require(_fundAmount <= msg.value, "Submit fundAmount");
      //require funds to come from party to transaction (likely buyer or financier)
      require(parties[msg.sender] == true, "Sender not approved party");
      buyer = msg.sender;
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
      require(!escrow.approvals[msg.sender], "Already approved by this party");
      escrow.approvals[msg.sender] = true;
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
      //NOTE: closeDeal transfers entire escrow balance to recipient (including deposit)
      recipient.transfer(escrowAddress.balance);
      escrow.complete = true;
      emit DealClosed();
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
      emit DealTerminated(terminationReason);
  }
}

/*** to be revisited as escrow factory variant
contract EscrowFactory {
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
}***/
