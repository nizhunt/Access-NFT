Summary

- [unchecked-transfer](#unchecked-transfer) (1 results) (High)
- [uninitialized-local](#uninitialized-local) (4 results) (Medium)
- [unused-return](#unused-return) (2 results) (Medium)
- [variable-scope](#variable-scope) (5 results) (Low)
- [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
- [reentrancy-events](#reentrancy-events) (2 results) (Low)
- [timestamp](#timestamp) (1 results) (Low)
- [assembly](#assembly) (2 results) (Informational)
- [pragma](#pragma) (1 results) (Informational)
- [dead-code](#dead-code) (23 results) (Informational)
- [solc-version](#solc-version) (15 results) (Informational)
- [low-level-calls](#low-level-calls) (4 results) (Informational)
- [naming-convention](#naming-convention) (19 results) (Informational)

## unchecked-transfer

Impact: High
Confidence: Medium

- [ ] ID-0
      [SubscriptionFactory.withdrawFee()](contracts/SubscriptionFlattened.sol#L1926-L1932) ignores return value by [CURRENCY.transfer(msg.sender,payout)](contracts/SubscriptionFlattened.sol#L1931)

contracts/SubscriptionFlattened.sol#L1926-L1932

## uninitialized-local

Impact: Medium
Confidence: Medium

- [ ] ID-1
      [ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes).response](contracts/SubscriptionFlattened.sol#L1528) is a local variable never initialized

contracts/SubscriptionFlattened.sol#L1528

- [ ] ID-2
      [ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes).reason](contracts/SubscriptionFlattened.sol#L1510) is a local variable never initialized

contracts/SubscriptionFlattened.sol#L1510

- [ ] ID-3
      [ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes).reason](contracts/SubscriptionFlattened.sol#L1533) is a local variable never initialized

contracts/SubscriptionFlattened.sol#L1533

- [ ] ID-4
      [ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes).response](contracts/SubscriptionFlattened.sol#L1506) is a local variable never initialized

contracts/SubscriptionFlattened.sol#L1506

## unused-return

Impact: Medium
Confidence: Medium

- [ ] ID-5
      [ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes)](contracts/SubscriptionFlattened.sol#L1497-L1516) ignores return value by [IERC1155Receiver(to).onERC1155Received(operator,from,id,amount,data)](contracts/SubscriptionFlattened.sol#L1506-L1514)

contracts/SubscriptionFlattened.sol#L1497-L1516

- [ ] ID-6
      [ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes)](contracts/SubscriptionFlattened.sol#L1518-L1539) ignores return value by [IERC1155Receiver(to).onERC1155BatchReceived(operator,from,ids,amounts,data)](contracts/SubscriptionFlattened.sol#L1527-L1537)

contracts/SubscriptionFlattened.sol#L1518-L1539

## variable-scope

Impact: Low
Confidence: High

- [ ] ID-7
      Variable '[ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes).response](contracts/SubscriptionFlattened.sol#L1528)' in [ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes)](contracts/SubscriptionFlattened.sol#L1518-L1539) potentially used before declaration: [response != IERC1155Receiver.onERC1155BatchReceived.selector](contracts/SubscriptionFlattened.sol#L1530)

contracts/SubscriptionFlattened.sol#L1528

- [ ] ID-8
      Variable '[ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes).reason](contracts/SubscriptionFlattened.sol#L1510)' in [ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes)](contracts/SubscriptionFlattened.sol#L1497-L1516) potentially used before declaration: [revert(string)(reason)](contracts/SubscriptionFlattened.sol#L1511)

contracts/SubscriptionFlattened.sol#L1510

- [ ] ID-9
      Variable '[ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes).reason](contracts/SubscriptionFlattened.sol#L1533)' in [ERC1155.\_doSafeBatchTransferAcceptanceCheck(address,address,address,uint256[],uint256[],bytes)](contracts/SubscriptionFlattened.sol#L1518-L1539) potentially used before declaration: [revert(string)(reason)](contracts/SubscriptionFlattened.sol#L1534)

contracts/SubscriptionFlattened.sol#L1533

- [ ] ID-10
      Variable '[ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes).response](contracts/SubscriptionFlattened.sol#L1506)' in [ERC1155.\_doSafeTransferAcceptanceCheck(address,address,address,uint256,uint256,bytes)](contracts/SubscriptionFlattened.sol#L1497-L1516) potentially used before declaration: [response != IERC1155Receiver.onERC1155Received.selector](contracts/SubscriptionFlattened.sol#L1507)

contracts/SubscriptionFlattened.sol#L1506

- [ ] ID-11
      Variable '[ECDSA.tryRecover(bytes32,bytes).r](contracts/SubscriptionFlattened.sol#L711)' in [ECDSA.tryRecover(bytes32,bytes)](contracts/SubscriptionFlattened.sol#L706-L737) potentially used before declaration: [r = mload(uint256)(signature + 0x20)](contracts/SubscriptionFlattened.sol#L730)

contracts/SubscriptionFlattened.sol#L711

## reentrancy-benign

Impact: Low
Confidence: Medium

- [ ] ID-12
      Reentrancy in [SubscriptionFactory.mint(SubscriptionFactory.mintArgs,bytes)](contracts/SubscriptionFlattened.sol#L1782-L1840):
      External calls: - [require(bool,string)(CURRENCY.transferFrom(msg.sender,address(this),\_mintArgs.\_subscriptionFee),Fee Transfer Failed)](contracts/SubscriptionFlattened.sol#L1786-L1793)
      State variables written after the call(s): - [setServiceProvider(\_contentId,\_mintArgs.\_serviceProvider)](contracts/SubscriptionFlattened.sol#L1805) - [contentIdToContent[\_contentId].serviceProvider = \_serviceProvider](contracts/SubscriptionFlattened.sol#L1742) - [contentIdToContent[\_contentId].fees += \_mintArgs.\_subscriptionFee](contracts/SubscriptionFlattened.sol#L1836) - [updateSubscription(\_contentId,\_mintArgs.\_subscriber,\_mintArgs.\_validity,\_mintArgs.\_royaltyInPercentage,\_mintArgs.\_subscriptionFee)](contracts/SubscriptionFlattened.sol#L1817-L1823) - [subscription[\_contentId][\_subscriber] = Subscription(block.timestamp + \_validity + checkValidityLeft(\_subscriber,\_contentId),\_subscriptionFee,(0))](contracts/SubscriptionFlattened.sol#L1764-L1777) - [subscription[\_contentId][\_subscriber] = Subscription(block.timestamp + \_validity + checkValidityLeft(\_subscriber,\_contentId),\_subscriptionFee,((\_royaltyInPercentage \* \_subscriptionFee) / 10 \*\* 3 / \_validity))](contracts/SubscriptionFlattened.sol#L1764-L1777)

contracts/SubscriptionFlattened.sol#L1782-L1840

## reentrancy-events

Impact: Low
Confidence: Medium

- [ ] ID-13
      Reentrancy in [SubscriptionFactory.mint(SubscriptionFactory.mintArgs,bytes)](contracts/SubscriptionFlattened.sol#L1782-L1840):
      External calls: - [require(bool,string)(CURRENCY.transferFrom(msg.sender,address(this),\_mintArgs.\_subscriptionFee),Fee Transfer Failed)](contracts/SubscriptionFlattened.sol#L1786-L1793)
      Event emitted after the call(s): - [NewAccess(\_contentId,\_mintArgs.\_serviceProvider,\_mintArgs.\_validity,\_mintArgs.\_subscriptionFee,\_mintArgs.\_subscriber,\_mintArgs.\_royaltyInPercentage)](contracts/SubscriptionFlattened.sol#L1827-L1834) - [NewContent(\_serviceProvider,\_contentId)](contracts/SubscriptionFlattened.sol#L1741) - [setServiceProvider(\_contentId,\_mintArgs.\_serviceProvider)](contracts/SubscriptionFlattened.sol#L1805)

contracts/SubscriptionFlattened.sol#L1782-L1840

- [ ] ID-14
      Reentrancy in [SubscriptionFactory.mint(SubscriptionFactory.mintArgs,bytes)](contracts/SubscriptionFlattened.sol#L1782-L1840):
      External calls: - [require(bool,string)(CURRENCY.transferFrom(msg.sender,address(this),\_mintArgs.\_subscriptionFee),Fee Transfer Failed)](contracts/SubscriptionFlattened.sol#L1786-L1793) - [\_mint(\_mintArgs.\_subscriber,\_contentId,1,)](contracts/SubscriptionFlattened.sol#L1839) - [IERC1155Receiver(to).onERC1155Received(operator,from,id,amount,data)](contracts/SubscriptionFlattened.sol#L1506-L1514) - [require(bool,string)(CURRENCY.transferFrom(msg.sender,address(this),netRoyalty),Pay Royalty Fee)](contracts/SubscriptionFlattened.sol#L1909-L1912)
      Event emitted after the call(s): - [TransferSingle(operator,address(0),to,id,amount)](contracts/SubscriptionFlattened.sol#L1311) - [\_mint(\_mintArgs.\_subscriber,\_contentId,1,)](contracts/SubscriptionFlattened.sol#L1839)

contracts/SubscriptionFlattened.sol#L1782-L1840

## timestamp

Impact: Low
Confidence: Medium

- [ ] ID-15
      [SubscriptionFactory.checkValidityLeft(address,uint256)](contracts/SubscriptionFlattened.sol#L1746-L1755) uses timestamp for comparisons
      Dangerous comparisons: - [\_expiry <= block.timestamp](contracts/SubscriptionFlattened.sol#L1752-L1754)

contracts/SubscriptionFlattened.sol#L1746-L1755

## assembly

Impact: Informational
Confidence: High

- [ ] ID-16
      [Address.verifyCallResult(bool,bytes,string)](contracts/SubscriptionFlattened.sol#L524-L544) uses assembly - [INLINE ASM](contracts/SubscriptionFlattened.sol#L536-L539)

contracts/SubscriptionFlattened.sol#L524-L544

- [ ] ID-17
      [ECDSA.tryRecover(bytes32,bytes)](contracts/SubscriptionFlattened.sol#L706-L737) uses assembly - [INLINE ASM](contracts/SubscriptionFlattened.sol#L717-L721) - [INLINE ASM](contracts/SubscriptionFlattened.sol#L729-L732)

contracts/SubscriptionFlattened.sol#L706-L737

## pragma

Impact: Informational
Confidence: High

- [ ] ID-18
      Different versions of Solidity are used: - Version used: ['0.8.15', '^0.8.0', '^0.8.1'] - [^0.8.0](contracts/SubscriptionFlattened.sol#L9) - [^0.8.0](contracts/SubscriptionFlattened.sol#L92) - [^0.8.0](contracts/SubscriptionFlattened.sol#L125) - [^0.8.0](contracts/SubscriptionFlattened.sol#L258) - [^0.8.0](contracts/SubscriptionFlattened.sol#L295) - [^0.8.1](contracts/SubscriptionFlattened.sol#L327) - [^0.8.0](contracts/SubscriptionFlattened.sol#L557) - [^0.8.0](contracts/SubscriptionFlattened.sol#L587) - [^0.8.0](contracts/SubscriptionFlattened.sol#L653) - [^0.8.0](contracts/SubscriptionFlattened.sol#L893) - [^0.8.0](contracts/SubscriptionFlattened.sol#L944) - [^0.8.0](contracts/SubscriptionFlattened.sol#L1034) - [^0.8.0](contracts/SubscriptionFlattened.sol#L1559) - [0.8.15](contracts/SubscriptionFlattened.sol#L1646)

contracts/SubscriptionFlattened.sol#L9

## dead-code

Impact: Informational
Confidence: Medium

- [ ] ID-19
      [Address.verifyCallResult(bool,bytes,string)](contracts/SubscriptionFlattened.sol#L524-L544) is never used and should be removed

contracts/SubscriptionFlattened.sol#L524-L544

- [ ] ID-20
      [Strings.toHexString(uint256,uint256)](contracts/SubscriptionFlattened.sol#L62-L72) is never used and should be removed

contracts/SubscriptionFlattened.sol#L62-L72

- [ ] ID-21
      [Address.sendValue(address,uint256)](contracts/SubscriptionFlattened.sol#L383-L388) is never used and should be removed

contracts/SubscriptionFlattened.sol#L383-L388

- [ ] ID-22
      [ERC1155.\_burn(address,uint256,uint256)](contracts/SubscriptionFlattened.sol#L1363-L1385) is never used and should be removed

contracts/SubscriptionFlattened.sol#L1363-L1385

- [ ] ID-23
      [Address.functionCallWithValue(address,bytes,uint256)](contracts/SubscriptionFlattened.sol#L437-L443) is never used and should be removed

contracts/SubscriptionFlattened.sol#L437-L443

- [ ] ID-24
      [Address.functionDelegateCall(address,bytes,string)](contracts/SubscriptionFlattened.sol#L507-L516) is never used and should be removed

contracts/SubscriptionFlattened.sol#L507-L516

- [ ] ID-25
      [Strings.toHexString(uint256)](contracts/SubscriptionFlattened.sol#L46-L57) is never used and should be removed

contracts/SubscriptionFlattened.sol#L46-L57

- [ ] ID-26
      [Address.functionDelegateCall(address,bytes)](contracts/SubscriptionFlattened.sol#L497-L499) is never used and should be removed

contracts/SubscriptionFlattened.sol#L497-L499

- [ ] ID-27
      [Strings.toString(uint256)](contracts/SubscriptionFlattened.sol#L21-L41) is never used and should be removed

contracts/SubscriptionFlattened.sol#L21-L41

- [ ] ID-28
      [Counters.reset(Counters.Counter)](contracts/SubscriptionFlattened.sol#L929-L931) is never used and should be removed

contracts/SubscriptionFlattened.sol#L929-L931

- [ ] ID-29
      [Address.functionCallWithValue(address,bytes,uint256,string)](contracts/SubscriptionFlattened.sol#L451-L462) is never used and should be removed

contracts/SubscriptionFlattened.sol#L451-L462

- [ ] ID-30
      [ECDSA.toEthSignedMessageHash(bytes)](contracts/SubscriptionFlattened.sol#L865-L867) is never used and should be removed

contracts/SubscriptionFlattened.sol#L865-L867

- [ ] ID-31
      [Counters.decrement(Counters.Counter)](contracts/SubscriptionFlattened.sol#L921-L927) is never used and should be removed

contracts/SubscriptionFlattened.sol#L921-L927

- [ ] ID-32
      [ECDSA.toTypedDataHash(bytes32,bytes32)](contracts/SubscriptionFlattened.sol#L878-L880) is never used and should be removed

contracts/SubscriptionFlattened.sol#L878-L880

- [ ] ID-33
      [Context.\_msgData()](contracts/SubscriptionFlattened.sol#L312-L314) is never used and should be removed

contracts/SubscriptionFlattened.sol#L312-L314

- [ ] ID-34
      [Address.functionStaticCall(address,bytes)](contracts/SubscriptionFlattened.sol#L470-L472) is never used and should be removed

contracts/SubscriptionFlattened.sol#L470-L472

- [ ] ID-35
      [ERC1155.\_burnBatch(address,uint256[],uint256[])](contracts/SubscriptionFlattened.sol#L1396-L1422) is never used and should be removed

contracts/SubscriptionFlattened.sol#L1396-L1422

- [ ] ID-36
      [Strings.toHexString(address)](contracts/SubscriptionFlattened.sol#L77-L79) is never used and should be removed

contracts/SubscriptionFlattened.sol#L77-L79

- [ ] ID-37
      [Address.functionCall(address,bytes,string)](contracts/SubscriptionFlattened.sol#L418-L424) is never used and should be removed

contracts/SubscriptionFlattened.sol#L418-L424

- [ ] ID-38
      [ECDSA.recover(bytes32,uint8,bytes32,bytes32)](contracts/SubscriptionFlattened.sol#L832-L841) is never used and should be removed

contracts/SubscriptionFlattened.sol#L832-L841

- [ ] ID-39
      [Address.functionStaticCall(address,bytes,string)](contracts/SubscriptionFlattened.sol#L480-L489) is never used and should be removed

contracts/SubscriptionFlattened.sol#L480-L489

- [ ] ID-40
      [ECDSA.recover(bytes32,bytes32,bytes32)](contracts/SubscriptionFlattened.sol#L781-L789) is never used and should be removed

contracts/SubscriptionFlattened.sol#L781-L789

- [ ] ID-41
      [Address.functionCall(address,bytes)](contracts/SubscriptionFlattened.sol#L408-L410) is never used and should be removed

contracts/SubscriptionFlattened.sol#L408-L410

## solc-version

Impact: Informational
Confidence: High

- [ ] ID-42
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L944) allows old versions

contracts/SubscriptionFlattened.sol#L944

- [ ] ID-43
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L258) allows old versions

contracts/SubscriptionFlattened.sol#L258

- [ ] ID-44
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L295) allows old versions

contracts/SubscriptionFlattened.sol#L295

- [ ] ID-45
      Pragma version[^0.8.1](contracts/SubscriptionFlattened.sol#L327) allows old versions

contracts/SubscriptionFlattened.sol#L327

- [ ] ID-46
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L1559) allows old versions

contracts/SubscriptionFlattened.sol#L1559

- [ ] ID-47
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L92) allows old versions

contracts/SubscriptionFlattened.sol#L92

- [ ] ID-48
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L557) allows old versions

contracts/SubscriptionFlattened.sol#L557

- [ ] ID-49
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L653) allows old versions

contracts/SubscriptionFlattened.sol#L653

- [ ] ID-50
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L125) allows old versions

contracts/SubscriptionFlattened.sol#L125

- [ ] ID-51
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L893) allows old versions

contracts/SubscriptionFlattened.sol#L893

- [ ] ID-52
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L1034) allows old versions

contracts/SubscriptionFlattened.sol#L1034

- [ ] ID-53
      solc-0.8.15 is not recommended for deployment

- [ ] ID-54
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L9) allows old versions

contracts/SubscriptionFlattened.sol#L9

- [ ] ID-55
      Pragma version[^0.8.0](contracts/SubscriptionFlattened.sol#L587) allows old versions

contracts/SubscriptionFlattened.sol#L587

- [ ] ID-56
      Pragma version[0.8.15](contracts/SubscriptionFlattened.sol#L1646) allows old versions

contracts/SubscriptionFlattened.sol#L1646

## low-level-calls

Impact: Informational
Confidence: High

- [ ] ID-57
      Low level call in [Address.sendValue(address,uint256)](contracts/SubscriptionFlattened.sol#L383-L388): - [(success) = recipient.call{value: amount}()](contracts/SubscriptionFlattened.sol#L386)

contracts/SubscriptionFlattened.sol#L383-L388

- [ ] ID-58
      Low level call in [Address.functionCallWithValue(address,bytes,uint256,string)](contracts/SubscriptionFlattened.sol#L451-L462): - [(success,returndata) = target.call{value: value}(data)](contracts/SubscriptionFlattened.sol#L460)

contracts/SubscriptionFlattened.sol#L451-L462

- [ ] ID-59
      Low level call in [Address.functionDelegateCall(address,bytes,string)](contracts/SubscriptionFlattened.sol#L507-L516): - [(success,returndata) = target.delegatecall(data)](contracts/SubscriptionFlattened.sol#L514)

contracts/SubscriptionFlattened.sol#L507-L516

- [ ] ID-60
      Low level call in [Address.functionStaticCall(address,bytes,string)](contracts/SubscriptionFlattened.sol#L480-L489): - [(success,returndata) = target.staticcall(data)](contracts/SubscriptionFlattened.sol#L487)

contracts/SubscriptionFlattened.sol#L480-L489

## naming-convention

Impact: Informational
Confidence: High

- [ ] ID-61
      Parameter [SubscriptionFactory.checkNetRoyalty(address,uint256).\_contentId](contracts/SubscriptionFlattened.sol#L1866) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1866

- [ ] ID-62
      Parameter [SubscriptionFactory.setURI(uint256,string).\_contentId](contracts/SubscriptionFlattened.sol#L1691) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1691

- [ ] ID-63
      Parameter [SubscriptionFactory.setServiceProvider(uint256,address).\_contentId](contracts/SubscriptionFlattened.sol#L1738) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1738

- [ ] ID-64
      Parameter [SubscriptionFactory.setURI(uint256,string).\_newuri](contracts/SubscriptionFlattened.sol#L1691) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1691

- [ ] ID-65
      Parameter [SubscriptionFactory.updateSubscription(uint256,address,uint256,uint256,uint256).\_validity](contracts/SubscriptionFlattened.sol#L1760) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1760

- [ ] ID-66
      Parameter [SubscriptionFactory.checkNetRoyalty(address,uint256).\_subscriber](contracts/SubscriptionFlattened.sol#L1865) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1865

- [ ] ID-67
      Parameter [SubscriptionFactory.mint(SubscriptionFactory.mintArgs,bytes).\_serviceProviderSignature](contracts/SubscriptionFlattened.sol#L1784) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1784

- [ ] ID-68
      Parameter [SubscriptionFactory.updateSubscription(uint256,address,uint256,uint256,uint256).\_royaltyInPercentage](contracts/SubscriptionFlattened.sol#L1761) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1761

- [ ] ID-69
      Parameter [SubscriptionFactory.checkValidityLeft(address,uint256).\_contentId](contracts/SubscriptionFlattened.sol#L1748) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1748

- [ ] ID-70
      Parameter [SubscriptionFactory.updateSubscription(uint256,address,uint256,uint256,uint256).\_subscriptionFee](contracts/SubscriptionFlattened.sol#L1762) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1762

- [ ] ID-71
      Struct [SubscriptionFactory.mintArgs](contracts/SubscriptionFlattened.sol#L1672-L1679) is not in CapWords

contracts/SubscriptionFlattened.sol#L1672-L1679

- [ ] ID-72
      Parameter [SubscriptionFactory.mint(SubscriptionFactory.mintArgs,bytes).\_mintArgs](contracts/SubscriptionFlattened.sol#L1783) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1783

- [ ] ID-73
      Parameter [SubscriptionFactory.checkValidityLeft(address,uint256).\_subscriber](contracts/SubscriptionFlattened.sol#L1747) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1747

- [ ] ID-74
      Parameter [SubscriptionFactory.uri(uint256).\_contentId](contracts/SubscriptionFlattened.sol#L1704) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1704

- [ ] ID-75
      Modifier [SubscriptionFactory.VerifiedServiceProvider(SubscriptionFactory.mintArgs,bytes)](contracts/SubscriptionFlattened.sol#L1714-L1735) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1714-L1735

- [ ] ID-76
      Parameter [SubscriptionFactory.updateSubscription(uint256,address,uint256,uint256,uint256).\_subscriber](contracts/SubscriptionFlattened.sol#L1759) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1759

- [ ] ID-77
      Parameter [SubscriptionFactory.setServiceProvider(uint256,address).\_serviceProvider](contracts/SubscriptionFlattened.sol#L1739) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1739

- [ ] ID-78
      Parameter [SubscriptionFactory.updateSubscription(uint256,address,uint256,uint256,uint256).\_contentId](contracts/SubscriptionFlattened.sol#L1758) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1758

- [ ] ID-79
      Variable [SubscriptionFactory.CURRENCY](contracts/SubscriptionFlattened.sol#L1685) is not in mixedCase

contracts/SubscriptionFlattened.sol#L1685
