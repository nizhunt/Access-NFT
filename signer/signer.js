const { ethers, config } = require("hardhat");
const findPrivateKey = (index) => {
  const accounts = config.networks.hardhat.accounts;
  const wallet = ethers.Wallet.fromMnemonic(
    accounts.mnemonic,
    accounts.path + `/${index}`
  );
  return wallet.privateKey;
  console.log("privateKey:", privateKey);
};

// sign message as a subscription provider to use in calling mint
const serviceProviderSignature = async () => {
  const message = ethers.utils.solidityKeccak256(
    ["uint256", "string"],
    [5, "hello"]
  );
  const arrayifyMessage = ethers.utils.arrayify(message);
  // 4 for serviceProvider1, change for other service providers
  const flatSignature = await new ethers.Wallet(findPrivateKey(4)).signMessage(
    arrayifyMessage
  );
  console.log("SIGNATURE:", flatSignature);
  return flatSignature;
};
serviceProviderSignature();
