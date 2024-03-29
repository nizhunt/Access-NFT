// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title AcceSsup: An access management protocol
/// @author Nishant Singh github:nizhunt twitter:@nizhunt ens:nizhunt.eth
/// @notice Access management protocol with royalty and renting feature

contract AcceSsup is Ownable, ERC1155 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    // Qn: Why is royaltyPerUnitValidity a part of Access struct and not Content struct?
    // Ans: We don't want the ServiceProvider to have the access to change a access' terms once the access is minted.

    // Custom Errors
    error AcceSsup_ServiceProviderMismatch();
    error AcceSsup_ContentDoesNotExist();
    error AcceSsup_ServiceProviderNotValid();
    error AcceSsup_FeeTransferFailed();
    error AcceSsup_InvalidContentId();
    error AcceSsup_PayRoyaltyFeeFailed();
    error AcceSsup_NoFeeToWithdraw();
    error AcceSsup_Unauthorized();

    // events:

    // to fire when a new subscriber is added
    event NewAccess(
        uint256 indexed contentId,
        address indexed serviceProvider,
        uint256 validity,
        uint256 fee,
        address indexed subscriber,
        uint256 royalty
    );

    // to fire when a new content is added
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
    mapping(uint256 contentId => mapping(address subscriber => Access)) private access;
    mapping(uint256 contentId => Content) private content;
    mapping(address => ServiceProvider) private serviceProviderInfo;

    Counters.Counter private contentIdCounter;
    IERC20 private immutable CURRENCY;

    constructor(address _tokenAddress, string memory _baseUri) ERC1155(_baseUri) {
        CURRENCY = IERC20(_tokenAddress);
    }

    function setBaseUri(string calldata _baseUri) public onlyOwner {
        _setURI(_baseUri);
        emit NewBaseUri(_baseUri);
    }

    /// @notice Enables the serviceProvider to reset the URI for all contents from them
    /// @dev This function can only be called by the serviceProvider of the content
    /// @param _newServiceProviderUri The new URI to be set for the content
    function setServiceProviderUri(address _serviceProvider, string calldata _newServiceProviderUri)
        public
        onlyServiceProviderOrSPOwner(_serviceProvider)
    {
        serviceProviderInfo[_serviceProvider].serviceProviderUri = _newServiceProviderUri;
        emit NewServiceProviderUri(_serviceProvider, _newServiceProviderUri);
    }

    /// @notice Enables the serviceProvider to reset the URI for their content
    /// @dev This function can only be called by the serviceProvider of the content
    /// @param _contentId contentId of the content
    /// @param _newContentUri The new URI to be set for the content
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

    function uri(uint256 contentId) public view override returns (string memory) {
        string memory _contentUri = content[contentId].contentUri;
        address _serviceProvider = content[contentId].serviceProvider;
        string memory _serviceProviderUri = serviceProviderInfo[_serviceProvider].serviceProviderUri;

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        if (bytes(_serviceProviderUri).length == 0) {
            return super.uri(contentId);
        } else {
            return bytes(_contentUri).length > 0
                ? string(abi.encodePacked(_serviceProviderUri, _contentUri))
                : _serviceProviderUri;
        }
    }

    /// @notice Sets the Owner for required serviceProvider
    /// @dev The signature from the serviceProvider will consist of the address of the owner followed by the address of the serviceProvider
    /// @param _signature The signature from the serviceProvider. The message of this signature should consist of the address of the owner followed by the address of the serviceProvider
    /// @param _serviceProvider The serviceProvider address the caller of this function wants ownership of.
    function setSPOwner(bytes calldata _signature, address _serviceProvider) public {
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, _serviceProvider));

        if (_serviceProvider != messageHash.toEthSignedMessageHash().recover(_signature)) {
            revert AcceSsup_ServiceProviderNotValid();
        }

        emit SPOwnerSet(_serviceProvider, msg.sender);

        serviceProviderInfo[_serviceProvider].SPOwnerAddress = msg.sender;
    }

    // extracts serviceProvider Address from the signature
    modifier VerifiedServiceProvider(mintArgs calldata _mintArgs, bytes calldata _signature) {
        bytes32 messageHash = keccak256(
            // these are the payloads to be hashed into the service-provider's signature
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

        if (_mintArgs._serviceProvider != messageHash.toEthSignedMessageHash().recover(_signature)) {
            revert AcceSsup_ServiceProviderNotValid();
        }

        _;
    }

    function setServiceProvider(
        uint256 _contentId,
        string memory _serviceProviderUri,
        string memory _contentUri,
        address _serviceProvider
    ) internal {
        /* Setting the ServiceProviderUri */
        if (
            bytes(serviceProviderInfo[_serviceProvider].serviceProviderUri).length == 0
                && bytes(_serviceProviderUri).length != 0
        ) {
            serviceProviderInfo[_serviceProvider].serviceProviderUri = _serviceProviderUri;
            emit NewServiceProviderUri(_serviceProvider, _serviceProviderUri);
        }

        /* Setting the contentUri */
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

    function checkValidityLeft(address _subscriber, uint256 _contentId) public view returns (uint256 validityLeft) {
        uint256 _expiry = access[_contentId][_subscriber].expiry;
        // check time left in access
        _expiry <= block.timestamp ? validityLeft = 0 : validityLeft = _expiry - block.timestamp;
    }

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
            // Scaling: we take royalty input divided by 10^3 ie.
            // if serviceProvider needs royalty to be 0.5% ie. 0.005*fee
            // they put input: 5
            royaltyPerUnitValidity: (_validity == 0 ? 0 : (_royaltyInPercentage * _accessFee) / 10 ** 3 / _validity)
        });
    }

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

    // function for the ServiceProvider Contracts to know what ContentId to put to new content mint.
    function getNextContentIdCount() public view returns (uint256 _nextContentIdCount) {
        _nextContentIdCount = contentIdCounter.current();
    }

    function checkNetRoyalty(address _subscriber, uint256 _contentId) public view returns (uint256 netRoyalty) {
        // Remove the scaling we introduced at at the time of saving the royalty
        netRoyalty =
            (checkValidityLeft(_subscriber, _contentId) * access[_contentId][_subscriber].royaltyPerUnitValidity);
    }

    // Before Transferring Ownership, change the storage of access details:
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

    // enable the service-provider to withdraw all their fee:
    function withdrawFee(address _serviceProvider) public onlyServiceProviderOrSPOwner(_serviceProvider) {
        uint256 payout = serviceProviderInfo[_serviceProvider].feesCollected;

        serviceProviderInfo[_serviceProvider].feesCollected = 0;
        if (payout == 0) revert AcceSsup_NoFeeToWithdraw();
        emit FeeWithdrawn(_serviceProvider, msg.sender, payout);
        CURRENCY.transfer(msg.sender, payout);
    }

    // modifiers:
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
