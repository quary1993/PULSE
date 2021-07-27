async function main() {
  const [deployer] = await ethers.getSigners();
  const Minter = await ethers.getContractFactory("PulseManager");
  minter = await Minter.deploy();
  const Pulse = await ethers.getContractFactory("Pulse");
  pulse = await Pulse.deploy(1, minter.address);
  await pulse.deployed();
  minter.setTokenAddress(pulse.address);
  minter.setTokenPrice(1);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });