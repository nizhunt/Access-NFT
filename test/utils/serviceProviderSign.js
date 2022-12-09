// sign message as a subscription provider to use in calling mint
const serviceProviderSignature = async (
  subscriptionFactoryAddress,
  contentId,
  totalSupplyOfContentID
) => {
  const message = ethers.utils.solidityKeccak256(
    ["address", "uint256", "uint256"],
    [subscriptionFactoryAddress, contentId, totalSupplyOfContentID]
  );
  const arrayifyMessage = ethers.utils.arrayify(message);
  // 2 for serviceProvider1, change for other service providers
  const flatSignature = await new ethers.Wallet(findPrivateKey(2)).signMessage(
    arrayifyMessage
  );
  return flatSignature;
};
