// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC721, IERC721Metadata, IERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ERC2771Context} from "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {ITicket} from "./interfaces/ITicket.sol";

/// @notice ERC721 ticket contract for a single event.
/// @dev Minting, burning, and transfers are restricted to protocol contracts.
contract Ticket is ITicket, ERC721, Initializable, ERC2771Context {
    address public ticketSale;
    address public ticketMarketplace;

    uint256 public totalSupply;

    string public baseURI;
    string public name_;
    string public symbol_;

    /// @notice Disables initializers on the implementation contract.
    /// @dev Constructor runs only on the implementation used for clones.
    /// @param trustedForwarder_ ERC2771 trusted forwarder.
    constructor(address trustedForwarder_) ERC721("NA", "NA") ERC2771Context(trustedForwarder_) {
        _disableInitializers();
    }

    modifier onlySaleOrMarketplace() {
        _onlySaleOrMarketplace();
        _;
    }

    /// @notice Initializes the ticket contract.
    /// @dev Can only be called once.
    /// @param params Initialization parameters for the event ticket.
    function initialize(TicketInitParams memory params) external initializer {
        baseURI = params.baseURI;
        name_ = params.name;
        symbol_ = params.symbol;
        ticketSale = params.ticketSale;
        ticketMarketplace = params.ticketMarketplace;
    }

    /// @notice Mints a ticket to a recipient.
    /// @dev Only callable by the ticket sale or marketplace.
    /// @param to Recipient address.
    /// @param ticketId Ticket id to mint.
    function mint(address to, uint256 ticketId) external onlySaleOrMarketplace {
        totalSupply += 1;
        _mint(to, ticketId);
    }

    /// @notice Burns a ticket.
    /// @dev Callable by the holder (or forwarder), used to redeem real-world ticket.
    /// @param ticketId Token id to burn.
    function burn(uint256 ticketId) external {
        address owner = _ownerOf(ticketId);
        if (owner != _msgSender()) {
            revert ERC721IncorrectOwner(_msgSender(), ticketId, owner);
        }
        totalSupply -= 1;
        _burn(ticketId);

        emit TicketRedeemed(_msgSender(), ticketId);
    }

    /// @notice Transfers a ticket.
    /// @dev Only callable by the ticket sale or marketplace.
    /// @param from Current owner.
    /// @param to New owner.
    /// @param ticketId Token id to transfer.
    function transferFrom(address from, address to, uint256 ticketId) public override onlySaleOrMarketplace {
        super.transferFrom(from, to, ticketId);
    }

    /// @notice Checks interface support.
    /// @param interfaceId Interface id to check.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the configured ticket name.
    /// @return Ticket name.
    function name() public view override returns (string memory) {
        return name_;
    }

    /// @notice Returns the configured ticket symbol.
    /// @return Ticket symbol.
    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    /// @notice Returns the base URI for token metadata.
    /// @return Base URI string.
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _onlySaleOrMarketplace() internal view {
        require(_msgSender() == ticketSale || _msgSender() == ticketMarketplace, "Callable only by protocol addresses");
    }

    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
