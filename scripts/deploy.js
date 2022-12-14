// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const Currency = await hre.ethers.getContractFactory("Currency");
  const currency = await Currency.deploy();
  await currency.deployed();
  console.log("Currency deployed to:", currency.address);

  const SubscriptionFactory = await hre.ethers.getContractFactory("Accessup");
  const subscriptionFactory = await SubscriptionFactory.deploy(
    currency.address
  );
  await subscriptionFactory.deployed();
  console.log("Accessup deployed to:", subscriptionFactory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
