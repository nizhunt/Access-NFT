const { ethers } = require("hardhat");
const currencyAbi = require("abi/currency.json");
const { serviceProviderSignature } = require("utils/signer.js");
const subscriptionAbi = require("abi/subscription.json");
require("dotenv").config();

const ACCOUNT1 = process.env.PRIVATE_KEY1;
const ACCOUNT2 = process.env.PRIVATE_KEY2;
const ACCOUNT3 = process.env.PRIVATE_KEY3;
const ACCOUNT4 = process.env.PRIVATE_KEY4;

const ADDRESS1 = 0x0b950d128f6a33651257f95cbaf59c02b7f6019f;
const ADDRESS2 = 0x2b9cc1db0cf684f43a623990ae21213cc9f7460d;
const ADDRESS3 = 0xc75fbf7cd0b58e1fff9b91a2d5b0682ef0880b22;
const ADDRESS4 = 0xcc892330481f9089912bacdc34dee90c0e56800c;

const CurrencyAddress = "0x160664d77f4e67e53fb010a2f2b3f9cf9fb8ed98";
const SubscriptionAddress = "0x3ebac880caf0e76231837d19fba3b4119137aae1";

const mint = async (
  SUBSCRIBER,
  SERVICEPROVIDER,
  id,
  Validity,
  subscriber,
  royalty,
  fee,
  serviceProvider
) => {
  const signer = ethers.Wallet(SUBSCRIBER);

  const currencyContract = new ethers.Contract(
    CurrencyAddress,
    currencyAbi,
    signer
  );

  const subscriptionContract = new ethers.Contract(
    SubscriptionAddress,
    subscriptionAbi,
    signer
  );

  //   Mint and approve currency:

  currencyContract.mint(ethers.utils.parseEther(fee));
  currencyContract.approve(SubscriptionAddress, ethers.utils.parseEther(fee));

  const mintArgs = [id, Validity, subscriber, royalty, fee, serviceProvider];

  const sign = await serviceProviderSignature(
    SERVICEPROVIDER,
    SubscriptionAddress,
    id,
    Validity,
    subscriber,
    royalty,
    fee,
    serviceProvider
  );

  await subscriptionContract.mint(mintArgs, sign);
};

var SUBSCRIBER = ACCOUNT2;
var SERVICEPROVIDER = ACCOUNT1;
var id = "0";
var Validity = "15778476";
var subscriber = ADDRESS2;
var royalty = "100";
var fee = "100";
var serviceProvider = ADDRESS1;

async function main() {
  mint(
    SUBSCRIBER,
    SERVICEPROVIDER,
    id,
    Validity,
    subscriber,
    royalty,
    fee,
    serviceProvider
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
