const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
require("@nomicfoundation/hardhat-chai-matchers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

let currencyDeployer,
  accessDeployer,
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

const serviceProviderSignature = async (
  accessFactoryAddress,
  _contentId,
  _validity,
  _subscriber,
  _royaltyInPercentage,
  _accessFee,
  _serviceProvider
) => {
  const message = ethers.utils.solidityKeccak256(
    ["address", "uint256", "uint256", "uint256", "uint256", "address"],
    [
      accessFactoryAddress,
      _contentId,
      _validity,
      _royaltyInPercentage,
      _accessFee,
      _serviceProvider,
    ]
  );
  const arrayifyMessage = ethers.utils.arrayify(message);
  // 2 for serviceProvider1, change for other service providers
  const flatSignature = await new ethers.Wallet(findPrivateKey(2)).signMessage(
    arrayifyMessage
  );
  return flatSignature;
};

describe("PositiveTestCases", () => {
  const deployAccessFixture = async () => {
    [currencyDeployer, accessDeployer, serviceProvider1, subscriber1] =
      await ethers.getSigners();

    const Currency = await ethers.getContractFactory(
      "Currency",
      currencyDeployer
    );
    const currency = await Currency.deploy();

    const AccessFactory = await ethers.getContractFactory(
      "AcceSsup",
      accessDeployer
    );
    const accessFactory = await AccessFactory.deploy(currency.address);

    return {
      currency,
      accessFactory,
    };
  };

  const deployAndMintFixture = async () => {
    [deployer, accessDeployer, serviceProvider1, subscriber1, subscriber2] =
      await ethers.getSigners();

    const Currency = await ethers.getContractFactory(
      "Currency",
      currencyDeployer
    );
    const currency = await Currency.deploy();

    const AccessFactory = await ethers.getContractFactory(
      "AcceSsup",
      accessDeployer
    );
    const accessFactory = await AccessFactory.deploy(currency.address);
    // @audit increase id and mint, try putting not minted latest id to mint
    await currency
      .connect(currencyDeployer)
      .transfer(subscriber1.address, ethers.utils.parseEther("1000"));
    await currency
      .connect(subscriber1)
      .approve(accessFactory.address, ethers.utils.parseEther("100"));

    const mintArgs = [
      0,
      5000,
      subscriber1.address,
      10,
      ethers.utils.parseEther("100"),
      serviceProvider1.address,
    ];

    const sign = await serviceProviderSignature(
      accessFactory.address,
      "0",
      "5000",
      subscriber1.address,
      "10",
      ethers.utils.parseEther("100"),
      serviceProvider1.address
    );

    await accessFactory.connect(subscriber1).mint(mintArgs, sign);

    return {
      currency,
      accessFactory,
    };
  };

  describe("SetupCheck", () => {
    it("Checks Currency Deployer's Balance", async () => {
      const { currency } = await loadFixture(deployAccessFixture);
      expect(await currency.balanceOf(currencyDeployer.address)).to.equal(
        ethers.utils.parseEther("10000")
      );
    });
  });

  describe("mint Accesss", () => {
    it("mints a access for new content", async () => {
      const { currency, accessFactory } = await loadFixture(
        deployAccessFixture
      );

      await currency
        .connect(currencyDeployer)
        .transfer(subscriber1.address, ethers.utils.parseEther("100"));
      expect(await currency.balanceOf(subscriber1.address)).to.equal(
        ethers.utils.parseEther("100")
      );
      expect(await currency.balanceOf(accessFactory.address)).to.equal(0);
      await currency
        .connect(subscriber1)
        .approve(accessFactory.address, ethers.utils.parseEther("100"));
      expect(
        await currency.allowance(subscriber1.address, accessFactory.address)
      ).to.equal(ethers.utils.parseEther("100"));

      const mintArgs = [
        0,
        5000,
        subscriber1.address,
        10,
        ethers.utils.parseEther("100"),
        serviceProvider1.address,
      ];

      const sign = await serviceProviderSignature(
        accessFactory.address,
        "0",
        "5000",
        subscriber1.address,
        "10",
        ethers.utils.parseEther("100"),
        serviceProvider1.address
      );

      expect(await accessFactory.connect(subscriber1).mint(mintArgs, sign))
        .to.emit(accessFactory, "NewAccess")
        .withArgs(
          0,
          serviceProvider1.address,
          5000,
          ethers.utils.parseEther("100"),
          subscriber1.address,
          10
        );

      expect(await currency.balanceOf(subscriber1.address)).to.equal(0);
      expect(await currency.balanceOf(accessFactory.address)).to.equal(
        ethers.utils.parseEther("100")
      );

      expect(
        await accessFactory.checkValidityLeft(subscriber1.address, 0)
      ).to.be.equal(5000);

      time.increase(1000);

      expect(
        await accessFactory.checkValidityLeft(subscriber1.address, 0)
      ).to.be.equal(4000);
    });
  });

  describe("transfer access", () => {
    it("transfers a access", async () => {
      const { currency, accessFactory } = await loadFixture(
        deployAndMintFixture
      );

      //   Validity before transfer
      expect(
        await accessFactory.checkValidityLeft(subscriber1.address, 0)
      ).to.be.closeTo(5000, 2);
      expect(
        await accessFactory.checkValidityLeft(subscriber2.address, 0)
      ).to.equal(0);

      // transfer the nft after 1000 seconds
      time.increase(1000);

      // caller of the safeTransfer has to pay the royalty, giving approval for it here
      const royaltyAmt = await accessFactory.checkNetRoyalty(
        subscriber1.address,
        0
      );
      expect(
        await currency
          .connect(subscriber1)
          .approve(accessFactory.address, royaltyAmt)
      );

      expect(
        await accessFactory
          .connect(subscriber1)
          .safeTransferFrom(subscriber1.address, subscriber2.address, 0, 1, [])
      )
        .to.emit(accessFactory, "TransferSingle")
        .withArgs(
          subscriber1.address,
          subscriber1.address,
          subscriber2.address,
          0,
          1
        );

      // Validity after the transfer

      expect(
        await accessFactory.checkValidityLeft(subscriber1.address, 0)
      ).to.equal(0);
      expect(
        await accessFactory.checkValidityLeft(subscriber2.address, 0)
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

      await accessFactory
        .connect(serviceProvider1)
        .withdrawFee(serviceProvider1.address);

      console.log(await currency.balanceOf(serviceProvider1.address));
      console.log(TotalFee);

      expect(await currency.balanceOf(serviceProvider1.address)).to.be.closeTo(
        TotalFee,
        ethers.BigNumber.from(10).pow(15)
      );
    });
  });

  describe("service provider sets Uri for a minted token", () => {
    it("sets uri", async () => {
      const { currency, accessFactory } = await loadFixture(
        deployAndMintFixture
      );
      await accessFactory.connect(serviceProvider1).setURI(0, "google.com");
      expect(await accessFactory.uri(0)).to.equal("google.com");
    });
  });

  describe("non service provider can't sets Uri for a minted token", () => {
    it("subscriber can't set uri", async () => {
      const { accessFactory } = await loadFixture(deployAndMintFixture);
      await expect(
        accessFactory.connect(subscriber1).setURI(0, "yahoo.com")
      ).to.be.revertedWith("serviceProvider mismatch");
    });
    it("can't set uri of a non existent id", async () => {
      const { accessFactory } = await loadFixture(deployAndMintFixture);
      await expect(
        accessFactory.connect(serviceProvider1).setURI(1, "yahoo.com")
      ).to.be.revertedWith("setURI: Content doesn't exist");
    });
  });
});
