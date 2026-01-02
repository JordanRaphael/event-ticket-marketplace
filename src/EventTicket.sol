// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.33;

import { ERC721, IERC721Metadata, IERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { AccessControl, IAccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import { IEventTicket } from "./interfaces/IEventTicket.sol";

contract EventTicket is IEventTicket, ERC721, AccessControl, Initializable {

    bytes32 public constant PROTOCOL = keccak256("PROTOCOL");

    uint256 public totalSupply;
    
    string public baseURI;
    string public ticketName;
    string public ticketSymbol;

    constructor() ERC721("NA", "NA") {
        _disableInitializers();
    }

    function initialize(EventTicketInitParams memory initParams) external initializer {
        baseURI = initParams.baseURI;
        ticketName = initParams.name;
        ticketSymbol = initParams.symbol;
        _grantRole(DEFAULT_ADMIN_ROLE, initParams.organizer); //@todo consider other access control method
        _grantRole(PROTOCOL, initParams.ticketSale);
        _grantRole(PROTOCOL, initParams.ticketMarketplace);
    }

    function mint(address to, uint256 tokenId) external onlyRole(PROTOCOL) {
        totalSupply += 1;
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external onlyRole(PROTOCOL) {
        totalSupply -= 1;
        _burn(tokenId);
    }


    function transferFrom(address from, address to, uint256 tokenId) public override onlyRole(PROTOCOL) {
        super.transferFrom(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return 
            interfaceId == type(IAccessControl).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function name() public view override returns (string memory) {
        return ticketName;
    }

    function symbol() public view override returns (string memory) {
        return ticketSymbol;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}