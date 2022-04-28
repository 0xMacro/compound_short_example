import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre, { ethers, network } from "hardhat";
import { CompoundShort, IERC20, CErc20, FakePriceFeed } from "../typechain";
import { BigNumberish } from "ethers";
const BigNumber = ethers.BigNumber;

const cUNIAddress = "0x35a18000230da775cac24873d00ff85bccded550";
const cUSDCAddress = "0x39aa39c021dfbae8fac545936693ac917d5e7563";

const uniAddress = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984";
const usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

const bigUNIHolder = "0x2ec96c9af82ddd650c0776cb0da93beaa7ce2a10"; // this address has a ton of UNI as of block 14667344

const decimals = 18; // decimals of the token we're borrowing, which is UNI

const FIVE_HUNDRED_USDC = 500 * 1e6;
const eighteenZeros = BigNumber.from(10).pow(18);

const priceFeedAddress = "0x65c816077C29b557BEE980ae3cC2dCE80204A0C5";
let fakePriceFeed: FakePriceFeed;

let compoundShort: CompoundShort;
let cUNI: CErc20;
let usdc: IERC20;
let uni: IERC20;
let alice: SignerWithAddress;

let ethBalanceAtConstruction = BigNumber.from(0);
describe("Compound ETH Short", function () {
  this.beforeEach(async () => {
    [alice] = await ethers.getSigners();
    const shortFactory = await ethers.getContractFactory("CompoundShort");
    compoundShort = await shortFactory.deploy(
      cUSDCAddress,
      cUNIAddress,
      usdcAddress,
      uniAddress,
      decimals
    );

    cUNI = await ethers.getContractAt("CErc20", cUNIAddress);
    usdc = await ethers.getContractAt("IERC20", usdcAddress);
    uni = await ethers.getContractAt("IERC20", uniAddress);
    fakePriceFeed = await ethers.getContractAt(
      "FakePriceFeed",
      priceFeedAddress
    );
    ethBalanceAtConstruction = await alice.getBalance();
  });
  it("Should short UNI", async function () {
    // first mint ourselves 500 USDC
    await mintUSDC(FIVE_HUNDRED_USDC);

    // supply USDC
    await usdc.approve(compoundShort.address, FIVE_HUNDRED_USDC);
    await compoundShort.supply(FIVE_HUNDRED_USDC);

    // short ETH
    const borrowAmount = await compoundShort.getBorrowAmount();
    await compoundShort.short(borrowAmount);

    // fake the decrease the price of UNI, so we can profit from the short.
    // We do this by getting a bunch of UNI from a large holder, and then selling it
    const fiftyUNI = BigNumber.from(50).mul(eighteenZeros);
    await sendUNI(alice.address, fiftyUNI);
    await uni.approve(compoundShort.address, fiftyUNI);
    await compoundShort.lowerUNIPriceOnUniswap(fiftyUNI);
    console.log(
      `new Compound UNI Price: ${await await fakePriceFeed.getUnderlyingPrice(
        cUNI.address
      )}`
    );
    console.log(
      `new Compound UNI Price: ${await (
        await fakePriceFeed.getUnderlyingPrice(cUNI.address)
      )
        .div(eighteenZeros)
        .toString()}`
    );

    // note, this doesn't actually work, because after updating the code I'm unable to
    // call Compound's `.redeem` function. in CompoundShort.sol .redeem fails silently,
    // but we know how much underlying USDC it should return, so I'll leave it as a problem
    // for another day
    await lowerUNIPriceOnChainlink(BigNumber.from(7).mul(eighteenZeros));

    console.log(
      `new Compound UNI Price: ${await (
        await fakePriceFeed.getUnderlyingPrice(cUNI.address)
      )
        .div(eighteenZeros)
        .toString()}`
    );

    await compoundShort.repayBorrow();

    console.log(
      "Total ETH used for gas: ",
      (ethBalanceAtConstruction
        .sub(await alice.getBalance())
        .div(BigNumber.from("1000000000000000000")))
        .toString()
    );
  });
});

// mints USDC (in base units) to the first Hardhat signer
const mintUSDC = async (amountOfUSDC: number) => {
  // all of the addresses we'll need
  const usdcMasterMinter = "0xe982615d461dd5cd06575bbea87624fda4e3de17";
  const usdcContractAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const ownerOfMasterMinter = "0xc1d9fe41d19dd52cb3ae5d1d3b0030b5d498c704";

  // Impersonate as the owner of the master USDC minter contract
  // so we can mint some USDC for Alice
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [ownerOfMasterMinter],
  });

  // setup all the contract state we'll need
  const impersonatedSigner: SignerWithAddress = await ethers.getSigner(
    ownerOfMasterMinter
  );
  const [alice] = await ethers.getSigners();

  const usdcContractFactory = await ethers.getContractFactory("FiatTokenV2_1");
  const masterMinterFactory = await ethers.getContractFactory("MasterMinter");

  const masterMinter = await masterMinterFactory.attach(usdcMasterMinter);
  const usdc = await usdcContractFactory.attach(usdcContractAddress);

  // The owner of the MasterMinter doesn't have enough ETH on mainnet
  // to execute the transactions we need, so let's give the owner some ETH
  await alice.sendTransaction({
    to: impersonatedSigner.address,
    value: ethers.utils.parseEther("10.0"),
  });

  // now all the contract state is setup, and we can have an arbitrary address (Alice)
  // make herself a minter and mint 1_000_000 USDC

  // only owner of MasterMinter can call this, and this will allow the owner
  // to call configureMinter
  await masterMinter
    .connect(impersonatedSigner)
    .configureController(ownerOfMasterMinter, ownerOfMasterMinter);

  // allow the owner to mint USDC
  await masterMinter.connect(impersonatedSigner).configureMinter(amountOfUSDC);

  // finally, mint the USDC to Alice
  await usdc.connect(impersonatedSigner).mint(alice.address, amountOfUSDC);
};

const sendUNI = async (recipient: string, amount: BigNumberish) => {
  // Impersonate the UNI Holder so we can send their funds to the recipient
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [bigUNIHolder],
  });

  // setup all the contract state we'll need
  const impersonatedSigner: SignerWithAddress = await ethers.getSigner(
    bigUNIHolder
  );

  await uni.connect(impersonatedSigner).transfer(recipient, amount);
};

const lowerUNIPriceOnChainlink = async (newAmount: BigNumberish) => {
  const artifact = await hre.artifacts.readArtifact("FakePriceFeed");
  await network.provider.send("hardhat_setCode", [
    priceFeedAddress,
    artifact.deployedBytecode,
    // COMPOUND_PRICEFEED_CONTRACT
  ]);

  await fakePriceFeed.setUnderlyingPrice(cUNI.address, newAmount);
};
