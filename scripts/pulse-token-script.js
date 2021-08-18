async function main() {
  const [deployer] = await ethers.getSigners();
  const Minter = await ethers.getContractFactory("PulseManager");
  minter = await Minter.deploy("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
  const Pulse = await ethers.getContractFactory("Pulse");
  pulse = await Pulse.deploy(1, minter.address, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
  await pulse.deployed();
  minter.setTokenAddress(pulse.address);
  minter.setTokenPrice(1);
  console.log('pulse manager: ' + minter.address);
  console.log('pulse: ' + pulse.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });