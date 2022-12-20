// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

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

    struct Access {
        uint256 starts;
        uint256 expires;
        uint256 fee;
        uint256 royaltyPerUnitValidity;
        uint256[] onRentFrom; // unix timestamp
        uint256[] onRentTill; // unix timestamp
    }

    struct ServiceProvider {
        address SPOwnerAddress;
        uint256 fees;
        string serviceProviderUri;
    }

    struct Content {
        address serviceProvider;
        string contentUri;
    }

    struct mintArgs {
        uint256 _contentIdTemporary;
        uint256 _starts;
        uint256 _expires;
        address _subscriber;
        uint256 _royaltyInPercentage;
        uint256 _accessFee;
        address _serviceProvider;
        string _serviceProviderUri;
        string _contentUri;
    }

    // contentId-->subscriber-->access
    mapping(uint256 => mapping(address => Access)) private access;
    mapping(uint256 => Content) private contentIdToContent;
    mapping(address => ServiceProvider)
        private serviceProviderAddressToServiceProvider;

    Counters.Counter private contentIdCounter;
    IERC20 private immutable CURRENCY;

    constructor(
        address _tokenAddress,
        string memory _baseUri
    ) ERC1155(_baseUri) {
        CURRENCY = IERC20(_tokenAddress);
    }

    function setBaseUri(string calldata _baseUri) public onlyOwner {
        _setURI(_baseUri);
        emit NewBaseUri(_baseUri);
    }

    /// @notice Enables the serviceProvider to reset the URI for all contents from them
    /// @dev This function can only be called by the serviceProvider of the content
    /// @param _newServiceProviderUri The new URI to be set for the content
    function setServiceProviderUri(
        address _serviceProvider,
        string calldata _newServiceProviderUri
    ) public onlyServiceProviderOrSPOwner(_serviceProvider) {
        serviceProviderAddressToServiceProvider[_serviceProvider]
            .serviceProviderUri = _newServiceProviderUri;
        emit NewServiceProviderUri(_serviceProvider, _newServiceProviderUri);
    }

    /// @notice Enables the serviceProvider to reset the URI for their content
    /// @dev This function can only be called by the serviceProvider of the content
    /// @param _contentId contentId of the content
    /// @param _newContentUri The new URI to be set for the content
    function setContentUri(
        address _serviceProvider,
        uint256 _contentId,
        string calldata _newContentUri
    ) public onlyServiceProviderOrSPOwner(_serviceProvider) {
        require(
            _contentId < contentIdCounter.current(),
            "Content doesn't exist"
        );
        require(
            contentIdToContent[_contentId].serviceProvider == _serviceProvider,
            "serviceProvider mismatch"
        );
        contentIdToContent[_contentId].contentUri = _newContentUri;
        emit NewContentUri(_contentId, _newContentUri);
    }

    function uri(
        uint256 contentId
    ) public view override returns (string memory) {
        string memory _contentUri = contentIdToContent[contentId].contentUri;
        address _serviceProvider = contentIdToContent[contentId]
            .serviceProvider;
        string
            memory _serviceProviderUri = serviceProviderAddressToServiceProvider[
                _serviceProvider
            ].serviceProviderUri;

        // If token URI is set, concatenate base URI and tokenURI (via abi.encodePacked).
        if (bytes(_serviceProviderUri).length == 0) {
            return super.uri(contentId);
        } else {
            return
                bytes(_contentUri).length > 0
                    ? string(abi.encodePacked(_serviceProviderUri, _contentUri))
                    : _serviceProviderUri;
        }
    }

    /// @notice Sets the Owner for required serviceProvider
    /// @dev The signature from the serviceProvider will consist of the address of the owner followed by the address of the serviceProvider
    /// @param _signature The signature from the serviceProvider. The message of this signature should consist of the address of the owner followed by the address of the serviceProvider
    /// @param _serviceProvider The serviceProvider address the caller of this function wants ownership of.
    function setSPOwner(
        bytes calldata _signature,
        address _serviceProvider
    ) public {
        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, _serviceProvider)
        );
        require(
            _serviceProvider ==
                messageHash.toEthSignedMessageHash().recover(_signature),
            "serviceProvider Not Valid"
        );
        require(
            serviceProviderAddressToServiceProvider[_serviceProvider]
                .SPOwnerAddress == address(0),
            "Owner already set"
        );
        serviceProviderAddressToServiceProvider[_serviceProvider]
            .SPOwnerAddress = msg.sender;

        emit SPOwnerSet(_serviceProvider, msg.sender);
    }

    // extracts serviceProvider Address from the signature
    modifier VerifiedServiceProvider(
        mintArgs calldata _mintArgs,
        bytes calldata _signature
    ) {
        bytes32 messageHash = keccak256(
            // these are the payloads to be hashed into the service-provider's signature
            abi.encodePacked(
                address(this),
                _mintArgs._contentIdTemporary,
                _mintArgs._starts,
                _mintArgs._expires,
                _mintArgs._royaltyInPercentage,
                _mintArgs._accessFee,
                _mintArgs._serviceProvider,
                _mintArgs._serviceProviderUri,
                _mintArgs._contentUri
            )
        );
        require(
            _mintArgs._serviceProvider ==
                messageHash.toEthSignedMessageHash().recover(_signature),
            "serviceProvider Not Valid"
        );
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
            bytes(
                serviceProviderAddressToServiceProvider[_serviceProvider]
                    .serviceProviderUri
            ).length ==
            0 &&
            bytes(_serviceProviderUri).length != 0
        ) {
            serviceProviderAddressToServiceProvider[_serviceProvider]
                .serviceProviderUri = _serviceProviderUri;
            emit NewServiceProviderUri(_serviceProvider, _serviceProviderUri);
        }

        /* Setting the contentUri */
        if (
            bytes(
                serviceProviderAddressToServiceProvider[_serviceProvider]
                    .serviceProviderUri
            ).length !=
            0 &&
            bytes(_contentUri).length != 0
        ) {
            contentIdToContent[_contentId].contentUri = _contentUri;
            emit NewContentUri(_contentId, _contentUri);
        }

        contentIdToContent[_contentId].serviceProvider = _serviceProvider;
        emit NewContent(_serviceProvider, _contentId);
    }

    function checkValidityLeft(
        address _subscriber,
        uint256 _contentId
    ) public view returns (uint256 validityLeft) {
        uint256 _expiry = access[_contentId][_subscriber].expires;
        // check time left in access
        _expiry <= block.timestamp ? validityLeft = 0 : validityLeft =
            _expiry -
            block.timestamp;
    }

    function updateAccess(
        uint256 _contentId,
        address _subscriber,
        uint256 _starts,
        uint256 _expires,
        uint256 _royaltyInPercentage,
        uint256 _accessFee
    ) internal {
        uint256 _validity = _expires - _starts;
        access[_contentId][_subscriber] = Access({
            starts: _starts,
            expires: _expires,
            fee: _accessFee,
            // Scaling: we take royalty input divided by 10^3 ie.
            // if serviceProvider needs royalty to be 0.5% ie. 0.005*fee
            // they put input: 5
            royaltyPerUnitValidity: (
                _validity == 0
                    ? 0
                    : (_royaltyInPercentage * _accessFee) / 10 ** 3 / _validity
            ),
            onRentFrom: 0,
            onRentTill: 0
        });
    }

    function mint(
        mintArgs calldata _mintArgs,
        bytes calldata _serviceProviderSignature
    ) public VerifiedServiceProvider(_mintArgs, _serviceProviderSignature) {
        require(
            CURRENCY.transferFrom(
                msg.sender,
                address(this),
                _mintArgs._accessFee
            ),
            "Fee Transfer Failed"
        );

        // Bound the caller to follow the contentIdCounter sequence:
        uint256 _contentId;
        uint256 _contentIdCurrent = contentIdCounter.current();
        require(
            _mintArgs._contentIdTemporary <= _contentIdCurrent,
            "Content Id doesn't exist"
        );

        if (_mintArgs._contentIdTemporary == 0) {
            _contentId = _contentIdCurrent;
            setServiceProvider(
                _contentId,
                _mintArgs._serviceProviderUri,
                _mintArgs._contentUri,
                _mintArgs._serviceProvider
            );
            contentIdCounter.increment();
        } else {
            // Restrict other minters once a contentID is mapped to a serviceProvider
            require(
                contentIdToContent[_mintArgs._contentIdTemporary]
                    .serviceProvider == _mintArgs._serviceProvider,
                "serviceProvider mismatch"
            );
            _contentId = _mintArgs._contentIdTemporary;
        }

        updateAccess(
            _contentId,
            _mintArgs._subscriber,
            _mintArgs._starts,
            _mintArgs._expires,
            _mintArgs._royaltyInPercentage,
            _mintArgs._accessFee
        );

        emit NewAccess(
            _contentId,
            _mintArgs._serviceProvider,
            _mintArgs._starts,
            _mintArgs._expires,
            _mintArgs._accessFee,
            _mintArgs._subscriber,
            _mintArgs._royaltyInPercentage
        );
        // Track the payment received  for the serviceProvider
        serviceProviderAddressToServiceProvider[_mintArgs._serviceProvider]
            .fees += _mintArgs._accessFee;

        // Finally Lets Mint Baby...
        _mint(_mintArgs._subscriber, _contentId, 1, "");
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function rentAccess(
        uint256 _contentId,
        address _accessLender,
        address _accessBorrower,
        uint64 _rentedFrom,
        uint64 _rentedTill
    ) public {
        require(
            _accessLender == _msgSender() ||
                isApprovedForAll(_accessLender, _msgSender()),
            "caller is not access owner nor approved"
        );
        uint256 lenderStarts = access[_contentId][_accessLender].starts;
        uint256 lenderExpires = access[_contentId][_accessLender].expires;

        uint256 borrowerStarts = access[_contentId][_accessLender].starts;
        uint256 borrowerExpires = access[_contentId][_accessLender].expires;

        require(
            lenderStarts <= _rentedFrom &&
                _rentedFrom <= _rentedTill &&
                _rentedTill <= lenderExpires,
            "Lender Timeline dispute"
        );

        require(
            borrowerExpires <= _rentedFrom || _rentedTill <= borrowerStarts,
            "Borrower Timeline dispute"
        );

        uint256 royaltyPerUnitValidity = access[_contentId][_accessLender]
            .royaltyPerUnitValidity;

        uint256 netRoyalty = (_rentedTill - _rentedFrom) *
            royaltyPerUnitValidity;

        require(
            CURRENCY.transferFrom(msg.sender, address(this), netRoyalty),
            "Pay Royalty Fee"
        );

        address serviceProvider = contentIdToContent[_contentId]
            .serviceProvider;
        serviceProviderAddressToServiceProvider[serviceProvider]
            .fees += netRoyalty;

        access[_contentId][_accessBorrower] = Access({
            starts: _rentedFrom,
            expires: _rentedTill,
            fee: 0,
            royaltyPerUnitValidity: royaltyPerUnitValidity,
            onRentFrom: 0, // unix timestamp
            onRentTill: 0 // unix timestamp})
        });
    }

    // function for the ServiceProvider Contracts to know what ContentId to put to new content mint.
    function getNextContentIdCount()
        public
        view
        returns (uint256 _nextContentIdCount)
    {
        _nextContentIdCount = contentIdCounter.current();
    }

    function checkNetRoyalty(
        address _subscriber,
        uint256 _contentId
    ) public view returns (uint256 netRoyalty) {
        // Remove the scaling we introduced at at the time of saving the royalty
        netRoyalty = (checkValidityLeft(_subscriber, _contentId) *
            access[_contentId][_subscriber].royaltyPerUnitValidity);
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
                require(
                    access[ids[i]][from].onRentTill < block.timestamp,
                    "Access on rent!"
                );

                access[ids[i]][to] = Access({
                    starts: access[ids[i]][from]. +
                        checkValidityLeft(to, ids[i]),
                    expires: 
                    fee: access[ids[i]][from].fee,
                    royaltyPerUnitValidity: access[ids[i]][from]
                        .royaltyPerUnitValidity,
                    onRentFrom: 0,
                    onRentTill: 0
                });

                uint256 royalty = checkNetRoyalty(from, ids[i]);
                emit royaltyPaidDuringTransfer(ids[i], royalty);
                netRoyalty += royalty;

                access[ids[i]][from] = Access({
                    expiry: 0,
                    fee: 0,
                    royaltyPerUnitValidity: 0,
                    rentedFrom: 0,
                    rentedTill: 0
                });
                address serviceProvider = contentIdToContent[ids[i]]
                    .serviceProvider;
                serviceProviderAddressToServiceProvider[serviceProvider]
                    .fees += netRoyalty;
            }

            require(
                CURRENCY.transferFrom(msg.sender, address(this), netRoyalty),
                "Pay Royalty Fee"
            );
        }
    }

    // enable the service-provider to withdraw all their fee:
    function withdrawFee(
        address _serviceProvider
    ) public onlyServiceProviderOrSPOwner(_serviceProvider) {
        uint256 payout = serviceProviderAddressToServiceProvider[
            _serviceProvider
        ].fees;

        serviceProviderAddressToServiceProvider[_serviceProvider].fees = 0;
        require(payout != 0, "you are yet to collect any fee");
        emit FeeWithdrawn(_serviceProvider, msg.sender, payout);
        CURRENCY.transfer(msg.sender, payout);
    }

    // modifiers:

    modifier onlyServiceProviderOrSPOwner(address _serviceProvider) {
        address spOwner = serviceProviderAddressToServiceProvider[
            _serviceProvider
        ].SPOwnerAddress;

        if (spOwner != address(0)) {
            require(msg.sender == spOwner, "Only owner can call withdraw");
        } else {
            require(
                msg.sender == _serviceProvider,
                "only serviceProvider can withdraw"
            );
        }

        _;
    }

    // events:

    // to fire when a new subscriber is added
    event NewAccess(
        uint256 contentId,
        address serviceProvider,
        uint256 validity,
        uint256 fee,
        address subscriber,
        uint256 royalty
    );

    // to fire when a new content is added
    event NewContent(address serviceProvider, uint256 contentId);

    event FeeWithdrawn(address serviceProvider, address owner, uint256 fee);

    event SPOwnerSet(address serviceProvider, address SPOwner);

    event NewBaseUri(string baseUri);

    event NewServiceProviderUri(
        address serviceProvider,
        string serviceProviderUri
    );

    event NewContentUri(uint256 contentId, string contentUri);

    event royaltyPaidDuringTransfer(uint256 contentId, uint256 royaltyPaid);
}
