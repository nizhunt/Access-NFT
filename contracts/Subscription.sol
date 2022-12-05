// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract SubscriptionFactory is Ownable, ERC1155Supply {
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
        uint256 _contentId;
        uint256 _validity;
        address _subscriber;
        uint256 _royalty;
        uint256 _subscriptionFee;
        address _serviceProvider;
        }

    // contentId-->subscriber-->subscription
    mapping(uint256 => mapping(address => Subscription)) public subscription;
    mapping(uint256 => Content) public contentIdToContent;
    Counters.Counter private _contentIdCounter;
    IERC20 public immutable CURRENCY;

    constructor(address _tokenAddress) ERC1155("") {
        CURRENCY = IERC20(_tokenAddress);
    }

    function setURI(uint256 _contentId, string memory _newuri) public {
        require(exists(_contentId), "setURI: Content doesn't exist");
        require(
            contentIdToContent[_contentId].serviceProvider == msg.sender,
            "serviceProvider mismatch"
        );
        contentIdToContent[_contentId].uri = _newuri;
    }

    function uri(uint256 _contentId)
        public
        view
        override
        returns (string memory)
    {
        require(exists(_contentId), "URI: Content doesn't exist");
        return contentIdToContent[_contentId].uri;
    }


    // extracts serviceProvider Address from the signature
    // hash of 1. This contract's address 2. TotalSupply of the contentId
    modifier VerifiedServiceProvider(uint256 _contentId, address _serviceProvider, bytes calldata _signature)
    {
        bytes32 messageHash = keccak256(
            // these are the payloads to be hashed into the service-provider's signature
            abi.encodePacked(address(this), _contentId, totalSupply(_contentId))
        );
        require(_serviceProvider == messageHash.toEthSignedMessageHash().recover(
            _signature),"serviceProvider Not Valid");
        _;
    }

    function setServiceProvider(
        uint256 _contentId,
        address _serviceProvider,
        string memory _contentName
    ) internal {
        emit NewContent(_serviceProvider, _contentId, _contentName);
        contentIdToContent[_contentId].serviceProvider = _serviceProvider;
    }

    // function check how much time in seconds is left in the subscription
    function checkValidityLeft(address _subscriber, uint256 _contentId)
        public
        view
        returns (uint256 validityLeft)
    {
        uint256 _expiry = subscription[_contentId][_subscriber].expiry;
        // check time left in subscription
        _expiry <= block.timestamp ? validityLeft = 0 : validityLeft =
            _expiry -
            block.timestamp;
    }

    function serviceProviderSetup(uint256 _contentId,address  _serviceProvider, string calldata _contentName) internal {

        // Map serviceProvider to contentId in case of new Content
        if (!exists(_contentId)) {
            setServiceProvider(_contentId, _serviceProvider, _contentName);
            _contentIdCounter.increment();
        } else {
            // Restrict other minters once a contentID is mapped to a serviceProvider
            require(
                contentIdToContent[_contentId].serviceProvider == _serviceProvider,
                "serviceProvider mismatch"
            );
        }
    } 

    function updateSubscription(uint256 _contentId, address _subscriber, uint256 _validity, uint256 _royalty, uint256 _subscriptionFee) internal {
        subscription[_contentId][_subscriber] = Subscription({
        expiry: block.timestamp +
            _validity +
            checkValidityLeft(_subscriber, _contentId),
        fee: _subscriptionFee,
        
        // @audit change the comments
        // Scaling 1. royalty per unit second in validity scaled by 10^18:
        // Scaling 2. we take royalty input scaled 10^3 ie.
        // if serviceProvider needs royalty to be 0.5% ie. 0.005*fee
        // they put input: 5
        // factoring scaling no.1 & 2, we multiply 10^15 in below equation:
        royaltyPerUnitValidity: (_validity == 0 ? 0 : _royalty * _subscriptionFee / 10**3 / _validity)
        });
    }

    // emit _contentName along with contentId after mint for the ease of identifying contentIds.
    // the contract doesn't store the _contentName, only emits it.
    function mint(
        mintArgs calldata _mintArgs,
        string calldata _contentName,
        bytes calldata _serviceProviderSignature
    ) public  VerifiedServiceProvider(_mintArgs._contentId, _mintArgs._serviceProvider, _serviceProviderSignature) {

        require(
            CURRENCY.transferFrom(msg.sender,address(this),_mintArgs._subscriptionFee),
            "Fee Transfer Failed" );

        // Bound the caller to follow the contentIdCounter sequence:
        require(
            _mintArgs._contentId <= _contentIdCounter.current(),
            "check NextContentIdCount fn"
        );

        serviceProviderSetup(_mintArgs._contentId,_mintArgs._serviceProvider, _contentName);

        updateSubscription(_mintArgs._contentId,  _mintArgs._subscriber,  _mintArgs._validity,  _mintArgs._royalty,  _mintArgs._subscriptionFee);

        // @audit-ok add an after-mint/before-mint hook that sends the mint details to external contract
        // users can use _contentName to better identify the content
        emit NewAccess(
            _mintArgs._contentId,
            _mintArgs._serviceProvider,
            _mintArgs._validity,
            _mintArgs._subscriptionFee,
            _mintArgs._subscriber,
            _mintArgs._royalty,
            _contentName
        );
        // Track the payment received from the serviceProvider
        contentIdToContent[_mintArgs._contentId].fees += _mintArgs._subscriptionFee;

        // Finally Lets Mint Baby...
        _mint(_mintArgs._subscriber, _mintArgs._contentId, 1, "");
    }
    // @audit-ok write a batch-mint function
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
        _nextContentIdCount = _contentIdCounter.current();
    }

    function checkNetRoyalty(address _subscriber, uint256 _contentId)
        public
        view
        returns (uint256 netRoyalty)
    {
        // Remove the scaling we introduced at at the time of saving the royalty
        netRoyalty =(checkValidityLeft(_subscriber, _contentId) *
                    subscription[_contentId][_subscriber]
                        .royaltyPerUnitValidity);

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
                    royaltyPerUnitValidity: subscription[ids[i]][from].royaltyPerUnitValidity
                });

                netRoyalty += checkNetRoyalty(from, ids[i]);

                subscription[ids[i]][from] = Subscription({expiry: 0, fee: 0, royaltyPerUnitValidity: 0});

                contentIdToContent[ids[i]].fees += netRoyalty;
            }

                require(CURRENCY.transferFrom(msg.sender,address(this),netRoyalty), "Pay Royalty Fee" );

        }
    }

    function collectFee() internal returns (uint256 payout) {
        for (uint256 i = 0; i < _contentIdCounter.current(); i++) {
            if (contentIdToContent[i].serviceProvider == msg.sender) {
                payout += contentIdToContent[i].fees;
                contentIdToContent[i].fees = 0;
            }
        }
    }

    // enable the service-provider to withdraw all their fee:
    function withdrawFee() public {
        // following the check-effect-interaction pattern.
        uint256 payout = collectFee();
        require(payout != 0, "you are yet to collect any fee");
        emit FeeWithdrawn(payout);
        CURRENCY.transfer(msg.sender,payout);
    }

    // events:

    // to fire when a new subscriber is added
    event NewAccess(
        uint256 contentId,
        address serviceProvider,
        uint256 validity,
        uint256 fee,
        address subscriber,
        uint256 royalty,
        string contentName
    );
    // to fire when a new content is added
    event NewContent(
        address serviceProvider,
        uint256 contentId,
        string contentName
    );

    event FeeWithdrawn(uint256 fee);

}
