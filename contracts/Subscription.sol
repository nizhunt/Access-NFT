// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SubscriptionFactory is Ownable, ERC1155 {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    // Qn: Why is royaltyPerUnitValidity a part of Subscription struct and not Content struct?
    // Ans: We don't want the ServiceProvider to have the access to change a subscription's terms once the subscription is minted.

    struct Subscription {
        uint256 expiry;
        uint256 fee;
        uint256 royaltyPerUnitValidity;
    }

    struct Content {
        address serviceProvider;
        string uri;
        uint256 fees;
    }

    struct mintArgs {
        uint256 _contentIdTemporary;
        uint256 _validity;
        address _subscriber;
        uint256 _royalty;
        uint256 _subscriptionFee;
        address _serviceProvider;
    }

    // contentId-->subscriber-->subscription
    mapping(uint256 => mapping(address => Subscription)) public subscription;
    mapping(uint256 => Content) public contentIdToContent;
    mapping(address => address) serviceProviderToSPOwner;

    Counters.Counter private contentIdCounter;
    IERC20 public immutable CURRENCY;

    constructor(address _tokenAddress) ERC1155("") {
        CURRENCY = IERC20(_tokenAddress);
    }

    function setURI(uint256 _contentId, string memory _newuri) public {
        require(
            _contentId < contentIdCounter.current(),
            "setURI: Content doesn't exist"
        );
        require(
            contentIdToContent[_contentId].serviceProvider == msg.sender,
            "serviceProvider mismatch"
        );
        contentIdToContent[_contentId].uri = _newuri;
    }

    function uri(
        uint256 _contentId
    ) public view override returns (string memory) {
        require(
            _contentId < contentIdCounter.current(),
            "URI: Content doesn't exist"
        );
        return contentIdToContent[_contentId].uri;
    }

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
            serviceProviderToSPOwner[_serviceProvider] == address(0),
            "Owner already set"
        );
        serviceProviderToSPOwner[_serviceProvider] = msg.sender;

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
                _mintArgs._validity,
                _mintArgs._royalty,
                _mintArgs._subscriptionFee,
                _mintArgs._serviceProvider
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
        address _serviceProvider
    ) internal {
        emit NewContent(_serviceProvider, _contentId);
        contentIdToContent[_contentId].serviceProvider = _serviceProvider;
    }

    // function check how much time in seconds is left in the subscription
    function checkValidityLeft(
        address _subscriber,
        uint256 _contentId
    ) public view returns (uint256 validityLeft) {
        uint256 _expiry = subscription[_contentId][_subscriber].expiry;
        // check time left in subscription
        _expiry <= block.timestamp ? validityLeft = 0 : validityLeft =
            _expiry -
            block.timestamp;
    }

    function updateSubscription(
        uint256 _contentId,
        address _subscriber,
        uint256 _validity,
        uint256 _royalty,
        uint256 _subscriptionFee
    ) internal {
        subscription[_contentId][_subscriber] = Subscription({
            expiry: block.timestamp +
                _validity +
                checkValidityLeft(_subscriber, _contentId),
            fee: _subscriptionFee,
            // Scaling: we take royalty input divided by 10^3 ie.
            // if serviceProvider needs royalty to be 0.5% ie. 0.005*fee
            // they put input: 5
            royaltyPerUnitValidity: (
                _validity == 0
                    ? 0
                    : (_royalty * _subscriptionFee) / 10 ** 3 / _validity
            )
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
                _mintArgs._subscriptionFee
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
            setServiceProvider(_contentId, _mintArgs._serviceProvider);
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

        updateSubscription(
            _contentId,
            _mintArgs._subscriber,
            _mintArgs._validity,
            _mintArgs._royalty,
            _mintArgs._subscriptionFee
        );

        emit NewAccess(
            _contentId,
            _mintArgs._serviceProvider,
            _mintArgs._validity,
            _mintArgs._subscriptionFee,
            _mintArgs._subscriber,
            _mintArgs._royalty
        );
        // Track the payment received  for the serviceProvider
        contentIdToContent[_contentId].fees += _mintArgs._subscriptionFee;

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
            subscription[_contentId][_subscriber].royaltyPerUnitValidity);
    }

    // Before Transferring Ownership, change the storage of subscription details:
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0)) {
            uint256 netRoyalty;

            for (uint256 i = 0; i < ids.length; ++i) {
                subscription[ids[i]][to] = Subscription({
                    expiry: subscription[ids[i]][from].expiry +
                        checkValidityLeft(to, ids[i]),
                    fee: subscription[ids[i]][from].fee,
                    royaltyPerUnitValidity: subscription[ids[i]][from]
                        .royaltyPerUnitValidity
                });

                uint256 royalty = checkNetRoyalty(from, ids[i]);
                emit royaltyPaidDuringTransfer(ids[i], royalty);
                netRoyalty += royalty;

                subscription[ids[i]][from] = Subscription({
                    expiry: 0,
                    fee: 0,
                    royaltyPerUnitValidity: 0
                });

                contentIdToContent[ids[i]].fees += netRoyalty;
            }

            require(
                CURRENCY.transferFrom(msg.sender, address(this), netRoyalty),
                "Pay Royalty Fee"
            );
        }
    }

    function collectFee(
        address _serviceProvider
    ) internal returns (uint256 payout) {
        for (uint256 i = 0; i < contentIdCounter.current(); i++) {
            if (contentIdToContent[i].serviceProvider == _serviceProvider) {
                payout += contentIdToContent[i].fees;
                contentIdToContent[i].fees = 0;
            }
        }
    }

    // enable the service-provider to withdraw all their fee:
    function withdrawFee(address _serviceProvider) public {
        // address receiver;
        address spOwner = serviceProviderToSPOwner[_serviceProvider];

        if (spOwner != address(0)) {
            require(msg.sender == spOwner, "Only owner can call withdraw");
        } else {
            require(
                msg.sender == _serviceProvider,
                "only serviceProvider can withdrw"
            );
        }

        uint256 payout = collectFee(_serviceProvider);
        require(payout != 0, "you are yet to collect any fee");
        emit FeeWithdrawn(msg.sender, payout);
        CURRENCY.transfer(msg.sender, payout);
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

    event FeeWithdrawn(address serviceProvider, uint256 fee);

    event SPOwnerSet(address serviceProvider, address SPOwner);

    event royaltyPaidDuringTransfer(uint256 contentId, uint256 royaltyPaid);
}
