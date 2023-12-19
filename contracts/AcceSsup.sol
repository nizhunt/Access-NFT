// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title AcceSsup: An access management protocol with royalty and renting feature
/// @author Nishant Singh
/// @notice Implements a system for access management with royalty and renting
contract AcceSsup is Ownable, ERC1155 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    // Custom Errors
    error AcceSsup_ServiceProviderMismatch();
    error AcceSsup_ContentDoesNotExist();
    error AcceSsup_ServiceProviderNotValid();
    error AcceSsup_FeeTransferFailed();
    error AcceSsup_InvalidContentId();
    error AcceSsup_PayRoyaltyFeeFailed();
    error AcceSsup_NoFeeToWithdraw();
    error AcceSsup_Unauthorized();

    // Events:
    event NewAccess(
        uint256 indexed contentId,
        address indexed serviceProvider,
        uint256 validity,
        uint256 fee,
        address indexed subscriber,
        uint256 royalty
    );
    event NewContent(address indexed serviceProvider, uint256 indexed contentId);
    event FeeWithdrawn(address indexed serviceProvider, address indexed owner, uint256 fee);
    event SPOwnerSet(address indexed serviceProvider, address indexed SPOwner);
    event NewBaseUri(string baseUri);
    event NewServiceProviderUri(address indexed serviceProvider, string serviceProviderUri);
    event NewContentUri(uint256 indexed contentId, string contentUri);
    event RoyaltyPaidDuringTransfer(uint256 indexed contentId, uint256 royaltyPaid);

    struct Access {
        uint256 expiry;
        uint256 fee;
        uint256 royaltyPerUnitValidity;
    }

    struct ServiceProvider {
        address SPOwnerAddress;
        uint256 feesCollected;
        string serviceProviderUri;
    }

    struct Content {
        address serviceProvider;
        string contentUri;
    }

    struct mintArgs {
        uint256 _contentIdTemporary;
        uint256 _validity;
        address _subscriber;
        uint256 _royaltyInPercentage;
        uint256 _accessFee;
        address _serviceProvider;
        string _serviceProviderUri;
        string _contentUri;
    }

    // contentId-->subscriber-->access
    mapping(uint256 => mapping(address => Access)) private access;
    mapping(uint256 => Content) private content;
    mapping(address => ServiceProvider) private serviceProviderInfo;

    Counters.Counter private contentIdCounter;
    IERC20 private immutable CURRENCY;

    /// @notice Initializes the contract with the specified token address and base URI
    /// @param _tokenAddress ERC20 token address for handling payments
    /// @param _baseUri Base URI for ERC1155 token metadata
    constructor(address _tokenAddress, string memory _baseUri) ERC1155(_baseUri) {
        CURRENCY = IERC20(_tokenAddress);
    }

    ////////////////////////////////////////////////////////////
    /////////// Public Functions //////////////////////////////
    ///////////////////////////////////////////////////////////

    /// @notice Sets the base URI for all tokens
    /// @param _baseUri The new base URI to be set
    function setBaseUri(string calldata _baseUri) public onlyOwner {
        _setURI(_baseUri);
        emit NewBaseUri(_baseUri);
    }

    /// @notice Allows the serviceProvider to reset the URI for all contents from them
    /// @param _newServiceProviderUri The new URI to be set for the content
    /// @param _serviceProvider The address of the serviceProvider
    function setServiceProviderUri(address _serviceProvider, string calldata _newServiceProviderUri)
        public
        onlyServiceProviderOrSPOwner(_serviceProvider)
    {
        serviceProviderInfo[_serviceProvider].serviceProviderUri = _newServiceProviderUri;
        emit NewServiceProviderUri(_serviceProvider, _newServiceProviderUri);
    }

    /// @notice Allows the serviceProvider to reset the URI for a specific content
    /// @param _contentId The ID of the content
    /// @param _newContentUri The new URI to be set for the content
    /// @param _serviceProvider The address of the serviceProvider
    function setContentUri(address _serviceProvider, uint256 _contentId, string calldata _newContentUri)
        public
        onlyServiceProviderOrSPOwner(_serviceProvider)
    {
        if (_contentId >= contentIdCounter.current()) revert AcceSsup_ContentDoesNotExist();
        if (content[_contentId].serviceProvider != _serviceProvider) {
            revert AcceSsup_ServiceProviderMismatch();
        }

        content[_contentId].contentUri = _newContentUri;
        emit NewContentUri(_contentId, _newContentUri);
    }

    /// @notice Retrieves the URI for a given content ID
    /// @param contentId The ID of the content to fetch URI for
    /// @return The URI of the specified content
    function uri(uint256 contentId) public view override returns (string memory) {
        string memory _contentUri = content[contentId].contentUri;
        address _serviceProvider = content[contentId].serviceProvider;
        string memory _serviceProviderUri = serviceProviderInfo[_serviceProvider].serviceProviderUri;

        if (bytes(_serviceProviderUri).length == 0) {
            return super.uri(contentId);
        } else {
            return bytes(_contentUri).length > 0
                ? string(abi.encodePacked(_serviceProviderUri, _contentUri))
                : _serviceProviderUri;
        }
    }

    /// @notice Sets the Owner for a specific serviceProvider
    /// @param _signature The signature from the serviceProvider
    /// @param _serviceProvider The serviceProvider address
    function setSPOwner(bytes calldata _signature, address _serviceProvider) public {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, _serviceProvider));

        if (_serviceProvider != messageHash.toEthSignedMessageHash().recover(_signature)) {
            revert AcceSsup_ServiceProviderNotValid();
        }

        emit SPOwnerSet(_serviceProvider, msg.sender);

        serviceProviderInfo[_serviceProvider].SPOwnerAddress = msg.sender;
    }

    /// @notice Mints a new access token
    /// @param _mintArgs Arguments required for minting
    /// @param _serviceProviderSignature Signature of the service provider for verification
    function mint(mintArgs calldata _mintArgs, bytes calldata _serviceProviderSignature)
        public
        VerifiedServiceProvider(_mintArgs, _serviceProviderSignature)
    {
        if (!CURRENCY.transferFrom(msg.sender, address(this), _mintArgs._accessFee)) {
            revert AcceSsup_FeeTransferFailed();
        }

        uint256 _contentId;
        uint256 _contentIdCurrent = contentIdCounter.current();
        if (_mintArgs._contentIdTemporary >= _contentIdCurrent) revert AcceSsup_InvalidContentId();

        if (_mintArgs._contentIdTemporary == 0) {
            _contentId = _contentIdCurrent;
            setServiceProvider(
                _contentId, _mintArgs._serviceProviderUri, _mintArgs._contentUri, _mintArgs._serviceProvider
            );
            contentIdCounter.increment();
        } else {
            if (content[_mintArgs._contentIdTemporary].serviceProvider != _mintArgs._serviceProvider) {
                revert AcceSsup_ServiceProviderMismatch();
            }
            _contentId = _mintArgs._contentIdTemporary;
        }

        updateAccess(
            _contentId, _mintArgs._subscriber, _mintArgs._validity, _mintArgs._royaltyInPercentage, _mintArgs._accessFee
        );

        emit NewAccess(
            _contentId,
            _mintArgs._serviceProvider,
            _mintArgs._validity,
            _mintArgs._accessFee,
            _mintArgs._subscriber,
            _mintArgs._royaltyInPercentage
        );

        serviceProviderInfo[_mintArgs._serviceProvider].feesCollected += _mintArgs._accessFee;

        _mint(_mintArgs._subscriber, _contentId, 1, "");
    }

    /// @notice Retrieves the next content ID count
    /// @return _nextContentIdCount The next available content ID count
    function getNextContentIdCount() public view returns (uint256 _nextContentIdCount) {
        _nextContentIdCount = contentIdCounter.current();
    }

    /// @notice Calculates the net royalty for a given content ID and subscriber
    /// @param _subscriber The address of the subscriber
    /// @param _contentId The ID of the content
    /// @return netRoyalty The calculated net royalty
    function checkNetRoyalty(address _subscriber, uint256 _contentId) public view returns (uint256 netRoyalty) {
        // Remove the scaling we introduced at the time of saving the royalty
        netRoyalty =
            (checkValidityLeft(_subscriber, _contentId) * access[_contentId][_subscriber].royaltyPerUnitValidity);
    }

    /// @notice Allows the service provider to withdraw collected fees
    /// @param _serviceProvider The address of the service provider
    function withdrawFee(address _serviceProvider) public onlyServiceProviderOrSPOwner(_serviceProvider) {
        uint256 payout = serviceProviderInfo[_serviceProvider].feesCollected;

        serviceProviderInfo[_serviceProvider].feesCollected = 0;
        if (payout == 0) revert AcceSsup_NoFeeToWithdraw();
        emit FeeWithdrawn(_serviceProvider, msg.sender, payout);
        CURRENCY.transfer(msg.sender, payout);
    }

    function checkValidityLeft(address _subscriber, uint256 _contentId) public view returns (uint256 validityLeft) {
        uint256 _expiry = access[_contentId][_subscriber].expiry;
        // check time left in access
        _expiry <= block.timestamp ? validityLeft = 0 : validityLeft = _expiry - block.timestamp;
    }

    //////////////////////////////////////////////
    ////// Internal Functions ///////////////////
    //////////////////////////////////////////////

    /// @notice Logic to execute before token transfer
    /// @param operator The address performing the transfer
    /// @param from The address transferring the token
    /// @param to The recipient address
    /// @param ids Array of token IDs
    /// @param amounts Array of token amounts
    /// @param data Additional data with no specified format
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0) && from != to) {
            uint256 netRoyalty;

            for (uint256 i = 0; i < ids.length; ++i) {
                access[ids[i]][to] = Access({
                    expiry: access[ids[i]][from].expiry + checkValidityLeft(to, ids[i]),
                    fee: access[ids[i]][from].fee,
                    royaltyPerUnitValidity: access[ids[i]][from].royaltyPerUnitValidity
                });

                uint256 royalty = checkNetRoyalty(from, ids[i]);
                emit RoyaltyPaidDuringTransfer(ids[i], royalty);
                netRoyalty += royalty;

                access[ids[i]][from] = Access({expiry: 0, fee: 0, royaltyPerUnitValidity: 0});
                address serviceProvider = content[ids[i]].serviceProvider;
                serviceProviderInfo[serviceProvider].feesCollected += netRoyalty;
            }

            if (!CURRENCY.transferFrom(msg.sender, address(this), netRoyalty)) revert AcceSsup_PayRoyaltyFeeFailed();
        }
    }
    /// @notice Updates access details for a given content and subscriber
    /// @param _contentId The ID of the content for which access is being updated
    /// @param _subscriber The address of the subscriber whose access is being updated
    /// @param _validity The validity period for the access
    /// @param _royaltyInPercentage The royalty percentage to be applied
    /// @param _accessFee The fee associated with the access
    /// @dev This function updates the access expiry, fee, and royalty per unit validity for a given content and subscriber

    function updateAccess(
        uint256 _contentId,
        address _subscriber,
        uint256 _validity,
        uint256 _royaltyInPercentage,
        uint256 _accessFee
    ) internal {
        access[_contentId][_subscriber] = Access({
            expiry: block.timestamp + _validity + checkValidityLeft(_subscriber, _contentId),
            fee: _accessFee,
            royaltyPerUnitValidity: (_validity == 0 ? 0 : (_royaltyInPercentage * _accessFee) / 10 ** 3 / _validity)
        });
    }

    /// @notice Sets the service provider and updates URI information for a given content
    /// @param _contentId The ID of the content for which the service provider is being set
    /// @param _serviceProviderUri The URI of the service provider
    /// @param _contentUri The URI of the content
    /// @param _serviceProvider The address of the service provider
    /// @dev This function updates the service provider's URI and content URI, and logs these changes via events
    function setServiceProvider(
        uint256 _contentId,
        string memory _serviceProviderUri,
        string memory _contentUri,
        address _serviceProvider
    ) internal {
        if (
            bytes(serviceProviderInfo[_serviceProvider].serviceProviderUri).length == 0
                && bytes(_serviceProviderUri).length != 0
        ) {
            serviceProviderInfo[_serviceProvider].serviceProviderUri = _serviceProviderUri;
            emit NewServiceProviderUri(_serviceProvider, _serviceProviderUri);
        }

        if (
            bytes(serviceProviderInfo[_serviceProvider].serviceProviderUri).length != 0
                && bytes(_contentUri).length != 0
        ) {
            content[_contentId].contentUri = _contentUri;
            emit NewContentUri(_contentId, _contentUri);
        }

        content[_contentId].serviceProvider = _serviceProvider;
        emit NewContent(_serviceProvider, _contentId);
    }

    // Modifiers:

    /// @notice Verifies the signature of a service provider for minting operations
    /// @dev This modifier is used to ensure that the mint operation is initiated by a valid service provider
    /// @param _mintArgs The minting arguments including details like content ID, validity, royalty, fee, and service provider information
    /// @param _signature The digital signature provided by the service provider
    modifier VerifiedServiceProvider(mintArgs calldata _mintArgs, bytes calldata _signature) {
        // Hash the concatenation of contract address and mintArgs
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                address(this),
                _mintArgs._contentIdTemporary,
                _mintArgs._validity,
                _mintArgs._royaltyInPercentage,
                _mintArgs._accessFee,
                _mintArgs._serviceProvider,
                _mintArgs._serviceProviderUri,
                _mintArgs._contentUri
            )
        );

        // Verify that the message hash was signed by the service provider
        if (_mintArgs._serviceProvider != messageHash.toEthSignedMessageHash().recover(_signature)) {
            revert AcceSsup_ServiceProviderNotValid();
        }

        _; // Continue execution
    }

    /// @notice Ensures that the caller is either the service provider or the owner of the service provider
    /// @param _serviceProvider The address of the service provider
    modifier onlyServiceProviderOrSPOwner(address _serviceProvider) {
        address spOwner = serviceProviderInfo[_serviceProvider].SPOwnerAddress;
        if (spOwner != address(0)) {
            if (msg.sender != spOwner) revert AcceSsup_Unauthorized();
        } else {
            if (msg.sender != _serviceProvider) revert AcceSsup_Unauthorized();
        }
        _;
    }
}
