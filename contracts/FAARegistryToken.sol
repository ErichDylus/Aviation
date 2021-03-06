// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

// **********WORK IN PROGRESS / DEMONSTRATION PURPOSES ONLY -- USE AT OWN RISK**********
// @dev: create an ERC721 standard NFT for an N-registered aircraft, for purposes of the FAA Registry
// contract owner would theoretically be the FAA, who could burn NFTs upon deregistration/N-number change/owner change, etc.
// currently, anyone may create an NFT for demonstration purposes (for >= 0.01 ETH), but adding onlyOwner modifier would restrict minting to the contract owner (FAA)

contract FAARegistryToken is ERC721, Ownable {

  using SafeMath for uint256;
  
  event CreateAircraft(
      address aircraftOwner, 
      string model, 
      string nNumber, 
      uint256 regId, 
      uint256 msn, 
      bool lien, 
      bool fractionalOwner);

  struct Aircraft {
    address aircraftOwner;
    string model;
    string nNumber;
    uint256 regId;
    uint256 msn;
    bool lien; 
    bool fractionalOwner;
  }

  Aircraft[] public aircraft;
  uint256 i = 0;
  
  // @dev Initializing an ERC-721 standard token named 'FAA Registry Aircraft Token' with a symbol 'FAA'
  constructor() ERC721("FAA Registry Token", "FAA") public {
  }

  // fallback function
  receive() external payable {
  }

    function _createAircraft(
        address _aircraftOwner, 
        string memory _model, 
        string memory _nNumber, 
        uint256 _regId, 
        uint256 _msn, 
        bool _lien, 
        bool _fractionalOwner
        ) internal returns (uint256, uint256) {
    
    Aircraft memory newAircraft = Aircraft({
        aircraftOwner: _aircraftOwner,
        model: _model,
        nNumber: _nNumber,
        regId: _regId,
        msn: _msn,
        lien: _lien,
        fractionalOwner: _fractionalOwner
    });
    
    // @dev create unique aircraft identifier based on owner reg ID, i number and MSN
    // see: https://ethereum.stackexchange.com/questions/9965/how-to-generate-a-unique-identifier-in-solidity
    uint256 newAircraftId = uint256(keccak256(abi.encodePacked(_regId + i + _msn)));
    aircraft.push(Aircraft(_aircraftOwner, _model, _nNumber,  _regId, _msn, _lien, _fractionalOwner));
    i++;
    super._mint(_aircraftOwner, newAircraftId);
    emit CreateAircraft(
        newAircraft.aircraftOwner, 
        newAircraft.model, 
        newAircraft.nNumber, 
        newAircraft.regId, 
        newAircraft.msn, 
        newAircraft.lien, 
        newAircraft.fractionalOwner
        );
    return(newAircraftId, i);
  }
  
  // @dev return aircraft details based on i number (must be inputted by searcher and remains viewable after corresponding token burned, for now)
  function aircraftDetails(uint256 _i) public view returns(address, string memory, string memory, uint256, bool, bool) {
    Aircraft storage regToken = aircraft[_i];
    return (
        regToken.aircraftOwner, 
        regToken.model, 
        regToken.nNumber, 
        regToken.msn, 
        regToken.lien, 
        regToken.fractionalOwner
        );
  }
  
  // @dev buy a new FAA NFT for at least .01 ether (calls createAircraft() with given details)
  // may be purchased by any address for demonstration purposes, but could include onlyOwner to permit only the registry to create tokens, or require(whitelisted address)
  // if onlyOwner is used in future:
  // (1) change address in _createAircraft call from msg.sender to aircraft owner's address, (Registry would be msg.sender), and (2) could remove payment requirement
  function buyRegToken(
        string calldata _model, 
        string calldata _nNumber, 
        uint256 _regId, 
        uint256 _msn, 
        bool _lien, 
        bool _fractionalOwner
        ) external payable returns(uint) {
    require(msg.value >= 0.01 ether, "Please submit .01 ETH for a Registry Token");
    _createAircraft(msg.sender, _model, _nNumber, _regId, _msn, _lien, _fractionalOwner);
    }
    
    // @dev allow onlyOwner (presumably the Registry) to burn a registry token, for example if the aircraft is deregistered
    function burnToken(uint _tokenId) public onlyOwner {
        _burn(_tokenId);
    }
}
