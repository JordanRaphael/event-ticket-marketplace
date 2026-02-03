// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC721, IERC721Metadata, IERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import {IEventTicket} from "./interfaces/IEventTicket.sol";

contract EventTicket is IEventTicket, ERC721, Initializable {
    address public ticketSale;
    address public ticketMarketplace;

    uint256 public totalSupply;

    string public baseURI;
    string public ticketName;
    string public ticketSymbol;

    constructor() ERC721("NA", "NA") {
        _disableInitializers();
    }

    modifier onlyProtocol() {
        _onlyProtocol();
        _;
    }

    function initialize(EventTicketInitParams memory initParams) external initializer {
        baseURI = initParams.baseURI;
        ticketName = initParams.name;
        ticketSymbol = initParams.symbol;
        ticketSale = initParams.ticketSale;
        ticketMarketplace = initParams.ticketMarketplace;
    }

    function mint(address to, uint256 tokenId) external onlyProtocol {
        totalSupply += 1;
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external onlyProtocol {
        totalSupply -= 1;
        _burn(tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyProtocol {
        super.transferFrom(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || super.supportsInterface(interfaceId);
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

    function _onlyProtocol() internal view {
        require(msg.sender == ticketSale || msg.sender == ticketMarketplace, "Callable only by protocol addresses");
    }
}
