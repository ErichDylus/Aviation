//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//FOR DEMONSTRATION ONLY, not recommended to be used on mainnet
//@dev create a simple smart escrow contract for testing purposes, with ETH as payment and expiration denominated in seconds
//should be deployed by buyer (as funds are placed in escrow upon deployment, and returned to deployer if expired)

contract EthEscrow {
    
  //escrow struct to contain basic description of underlying deal, purchase price, ultimate recipient of funds
  struct InEscrow {
      string description;
      uint256 deposit;
      address payable seller;
  }
  
  InEscrow[] public escrows;
  address escrowAddress = address(this);
  address payable buyer;
  address payable seller;
  uint256 deposit;
  uint256 effectiveTime;
  uint256 expirationTime;
  bool sellerApproved;
  bool buyerApproved;
  bool isExpired;
  bool isClosed;
  string description;
  //map whether an address is a party to the transaction and has authority 
  mapping(address => bool) public parties;
  
  event DealExpired();
  event DealClosed();
  
  //restricts to agent (creator of escrow contract) or internal calls
  modifier restricted() {
    require(parties[msg.sender], "This may only be called by a party to the deal or the escrow contract itself");
    _;
  }
  
  //creator of escrow contract is buyer and contributes deposit
  //initiate escrow with description, deposit, and designate recipient seller
  constructor(string memory _description, uint256 _deposit, address payable _seller, uint256 _secsUntilExpiration) payable {
      require(msg.value >= deposit, "Submit deposit amount");
      buyer = payable(address(msg.sender));
      deposit = _deposit;
      description = _description;
      seller = _seller;
      parties[msg.sender] = true;
      parties[escrowAddress] = true;
      effectiveTime = uint256(block.timestamp);
      expirationTime = effectiveTime + _secsUntilExpiration;
      isExpired = false;
      sellerApproved = false;
      buyerApproved = false;
      sendEscrow(description, deposit, seller);
  }
  
  //buyer confirms seller's recipient oddress of escrowed funds as extra security measure
  function designateSeller(address payable _seller) public restricted {
      require(_seller != seller, "Party already designated as seller");
      require(!isExpired, "Too late to change seller");
      parties[_seller] = true;
      seller = _seller;
  }
  
  //create new escrow contract within master structure
  function sendEscrow(string memory _description, uint256 _deposit, address payable _seller) private restricted {
      InEscrow memory newRequest = InEscrow({
         description: _description,
         deposit: _deposit,
         seller: _seller
      });
      escrows.push(newRequest);
  }
  
  //check if expired, and if so, return balance to buyer
  function checkIfExpired() public returns(bool){
        if (expirationTime <= uint256(block.timestamp)) {
            isExpired = true;
            buyer.transfer(escrowAddress.balance);
            emit DealExpired();
        } else {
            isExpired = false;
        }
        return(isExpired);
    }

  function readyToClose() public restricted returns(string memory){
         if (msg.sender == seller) {
            sellerApproved = true;
            return("Seller is ready to close.");
        } else if (msg.sender == buyer) {
            buyerApproved = true;
            return("Buyer is ready to close.");
        } else {
            return("You are neither buyer nor seller.");
        }
  }
    
  // check if both buyer and seller are ready to close and expiration has not been met; if so, close deal and pay seller
  function closeDeal() public returns(bool){
      require(sellerApproved && buyerApproved, "Parties are not ready to close.");
      if (expirationTime <= uint256(block.timestamp)) {
            isExpired = true;
            buyer.transfer(escrowAddress.balance);
            emit DealExpired();
        } else {
            isClosed = true;
            seller.transfer(escrowAddress.balance);
            emit DealClosed();
        }
        return(isClosed);
  }
}
