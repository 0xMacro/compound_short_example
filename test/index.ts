import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre, { ethers } from "hardhat";
import { CompoundShort, IERC20, CErc20, CEth } from "../typechain"

const cETHAddress = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5'
const cUSDCAddress = '0x39aa39c021dfbae8fac545936693ac917d5e7563'

const wethAddress = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'

const decimals = 18; // decimals of the token we're borrowing, which is UNI

describe("Compound UNI Short", function () {
  let compoundShort: CompoundShort;
  it("Should short UNI", async function () {
    const shortFactory = await ethers.getContractFactory("CompoundShort")
    compoundShort = await shortFactory.deploy(cUSDCAddress, cETHAddress, wethAddress, decimals)

    // first mint ourselves a bunch of USDC
    await mintUSDC(1_000_000 * 10e6)
    // supply USDC
    const usdc = await ethers.getContractAt("IERC20", usdcAddress)
    
    

  });
});

// mints USDC (in base units) to the first Hardhat signer
const mintUSDC = async (amountOfUSDC: number) => {
  // all of the addresses we'll need
  const usdcMasterMinter = '0xe982615d461dd5cd06575bbea87624fda4e3de17'
  const usdcContractAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
  const ownerOfMasterMinter = '0xc1d9fe41d19dd52cb3ae5d1d3b0030b5d498c704'

  // Impersonate as the owner of the master USDC minter contract
  // so we can mint some USDC for Alice
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [ownerOfMasterMinter],
  });

  // setup all the contract state we'll need
  const impersonatedSigner: SignerWithAddress = await ethers.getSigner(ownerOfMasterMinter);
  const [alice] = await ethers.getSigners();

  const usdcContractFactory = await ethers.getContractFactory("FiatTokenV2_1");
  const masterMinterFactory = await ethers.getContractFactory("MasterMinter");

  const masterMinter = await masterMinterFactory.attach(usdcMasterMinter)
  const usdc = await usdcContractFactory.attach(usdcContractAddress)

  // The owner of the MasterMinter doesn't have enough ETH on mainnet
  // to execute the transactions we need, so let's give the owner some ETH
  await alice.sendTransaction({
    to: impersonatedSigner.address,
    value: ethers.utils.parseEther("10.0")
  })

  // now all the contract state is setup, and we can have an arbitrary address (Alice)
  // make herself a minter and mint 1_000_000 USDC

  // only owner of MasterMinter can call this, and this will allow the owner
  // to call configureMinter
  await masterMinter.connect(impersonatedSigner).configureController(ownerOfMasterMinter, ownerOfMasterMinter);

  // allow the owner to mint 1_000_000 USDC
  await masterMinter.connect(impersonatedSigner).configureMinter(amountOfUSDC);

  // finally, mint the 1 million USDC to Alice
  await usdc.connect(impersonatedSigner).mint(alice.address, amountOfUSDC);
}
