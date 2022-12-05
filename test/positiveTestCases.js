const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

let currencyDeployer,
  subscriptionDeployer,
  serviceProvider1,
  subscriber1,
  subscriber2;

// take out the privateKey of any account on Hardhat

const findPrivateKey = (index) => {
  const accounts = config.networks.hardhat.accounts;
  const wallet = ethers.Wallet.fromMnemonic(
    accounts.mnemonic,
    accounts.path + `/${index}`
  );
  return wallet.privateKey;
};

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

describe("PositiveTestCases", () => {
  const deploySubscriptionFixture = async () => {
    [currencyDeployer, subscriptionDeployer, serviceProvider1, subscriber1] =
      await ethers.getSigners();

    const Currency = await ethers.getContractFactory(
      "Currency",
      currencyDeployer
    );
    const currency = await Currency.deploy();

    const SubscriptionFactory = await ethers.getContractFactory(
      "SubscriptionFactory",
      subscriptionDeployer
    );
    const subscriptionFactory = await SubscriptionFactory.deploy(
      currency.address
    );

    return {
      currency,
      subscriptionFactory,
    };
  };

  const deployAndMintFixture = async () => {
    [
      deployer,
      subscriptionDeployer,
      serviceProvider1,
      subscriber1,
      subscriber2,
    ] = await ethers.getSigners();

    const Currency = await ethers.getContractFactory(
      "Currency",
      currencyDeployer
    );
    const currency = await Currency.deploy();

    const SubscriptionFactory = await ethers.getContractFactory(
      "SubscriptionFactory",
      subscriptionDeployer
    );
    const subscriptionFactory = await SubscriptionFactory.deploy(
      currency.address
    );

    await currency
      .connect(currencyDeployer)
      .transfer(subscriber1.address, ethers.utils.parseEther("1000"));
    await currency
      .connect(subscriber1)
      .approve(subscriptionFactory.address, ethers.utils.parseEther("100"));

    const contentId = await subscriptionFactory.getNextContentIdCount();
    const totalSupplyOfContentID = await subscriptionFactory.totalSupply(
      contentId
    );
    const mintArgs = [
      contentId,
      5000,
      subscriber1.address,
      10,
      ethers.utils.parseEther("100"),
      serviceProvider1.address,
    ];
    const sign = await serviceProviderSignature(
      subscriptionFactory.address,
      contentId,
      totalSupplyOfContentID
    );
    const contentName = "notflix";

    await subscriptionFactory
      .connect(subscriber1)
      .mint(mintArgs, contentName, sign);

    return {
      currency,
      subscriptionFactory,
      contentId,
    };
  };

  describe("SetupCheck", () => {
    it("Checks Currency Deployer's Balance", async () => {
      const { currency } = await loadFixture(deploySubscriptionFixture);
      expect(await currency.balanceOf(currencyDeployer.address)).to.equal(
        ethers.utils.parseEther("10000")
      );
    });

    it("Checks getNextContentIdCount() method", async () => {
      const { subscriptionFactory } = await loadFixture(
        deploySubscriptionFixture
      );
      const cid = await subscriptionFactory.getNextContentIdCount();
      expect(cid).to.equal(0);
    });
  });

  describe("mint Subscriptions", () => {
    it("mints a subscription for new content", async () => {
      const { currency, subscriptionFactory } = await loadFixture(
        deploySubscriptionFixture
      );

      await currency
        .connect(currencyDeployer)
        .transfer(subscriber1.address, ethers.utils.parseEther("100"));
      expect(await currency.balanceOf(subscriber1.address)).to.equal(
        ethers.utils.parseEther("100")
      );
      expect(await currency.balanceOf(subscriptionFactory.address)).to.equal(0);
      await currency
        .connect(subscriber1)
        .approve(subscriptionFactory.address, ethers.utils.parseEther("100"));
      expect(
        await currency.allowance(
          subscriber1.address,
          subscriptionFactory.address
        )
      ).to.equal(ethers.utils.parseEther("100"));

      const contentId = await subscriptionFactory.getNextContentIdCount();
      const totalSupplyOfContentID = await subscriptionFactory.totalSupply(
        contentId
      );
      const mintArgs = [
        contentId,
        5000,
        subscriber1.address,
        10,
        ethers.utils.parseEther("100"),
        serviceProvider1.address,
      ];
      const sign = await serviceProviderSignature(
        subscriptionFactory.address,
        contentId,
        totalSupplyOfContentID
      );
      const contentName = "notflix";

      expect(
        await subscriptionFactory
          .connect(subscriber1)
          .mint(mintArgs, contentName, sign)
      )
        .to.emit(subscriptionFactory, "NewAccess")
        .withArgs(
          contentId,
          serviceProvider1.address,
          5000,
          ethers.utils.parseEther("100"),
          subscriber1.address,
          10,
          contentName
        );

      expect(await currency.balanceOf(subscriber1.address)).to.equal(0);
      expect(await currency.balanceOf(subscriptionFactory.address)).to.equal(
        ethers.utils.parseEther("100")
      );

      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber1.address,
          contentId
        )
      ).to.be.equal(5000);

      time.increase(1000);

      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber1.address,
          contentId
        )
      ).to.be.equal(4000);
    });
  });

  describe("transfer subscription", () => {
    it("transfers a subscription", async () => {
      const { currency, subscriptionFactory, contentId } = await loadFixture(
        deployAndMintFixture
      );

      //   Validity before transfer
      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber1.address,
          contentId
        )
      ).to.be.closeTo(5000, 2);
      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber2.address,
          contentId
        )
      ).to.equal(0);

      // transfer the nft after 1000 seconds
      time.increase(1000);

      // caller of the safeTransfer has to pay the royalty, giving approval for it here
      const royaltyAmt = await subscriptionFactory.checkNetRoyalty(
        subscriber1.address,
        contentId
      );
      expect(
        await currency
          .connect(subscriber1)
          .approve(subscriptionFactory.address, royaltyAmt)
      );

      expect(
        await subscriptionFactory
          .connect(subscriber1)
          .safeTransferFrom(
            subscriber1.address,
            subscriber2.address,
            contentId,
            1,
            []
          )
      )
        .to.emit(subscriptionFactory, "TransferSingle")
        .withArgs(
          subscriber1.address,
          subscriber1.address,
          subscriber2.address,
          contentId,
          1
        );

      // Validity after the transfer

      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber1.address,
          contentId
        )
      ).to.equal(0);
      expect(
        await subscriptionFactory.checkValidityLeft(
          subscriber2.address,
          contentId
        )
      ).to.be.closeTo(4000, 2);

      // check if the fee collected by the serviceProvider is correctly calculated
      // TotalFee = FeeAtMint + RoyaltyAtTransfer
      // FeeAtMint = 100 ether
      // RoyaltyAtTransfer = (10 * 100 ether / 5000 / 10*3) * 3999
      DECIMALS = ethers.BigNumber.from(10).pow(18);
      // const totalFee = 100 * 10e18 + ((10 * 100 * 1e18) / 5000 / 10e3) * 3999;
      const FeeAtMint = ethers.BigNumber.from(100).mul(DECIMALS);
      const RoyaltyAtTransferNum = ethers.BigNumber.from(4000000).mul(DECIMALS);
      const RoyaltyAtTransferDen = ethers.BigNumber.from(5000000);
      const RoyaltyAtTransfer = RoyaltyAtTransferNum.div(RoyaltyAtTransferDen);
      const TotalFee = FeeAtMint.add(RoyaltyAtTransfer);

      await subscriptionFactory.connect(serviceProvider1).withdrawFee();

      expect(await currency.balanceOf(serviceProvider1.address)).to.be.closeTo(
        TotalFee,
        ethers.BigNumber.from(10).pow(15)
      );
    });
  });
});
