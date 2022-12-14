# Todo

- serviceProvider abstraction such that the platform does not have to save the private-key at their backend or such that they can save it at the backend securely:
  - can use an owner tag to which the withdrawal amount is sent instead of sending it to the serviceProvider address.
  - sign a message with serviceProvider, owner address by serviceProvider. owner sends the message and sign as a parameter to set himself as owner.
- add an after-mint/before-mint hook that sends the mint details to external contract
- switch to newer form of errors ie. revert()
- implement renting logic
- Implement batchMint logic

## after deploying the contract, mint the 0th nft yourself
