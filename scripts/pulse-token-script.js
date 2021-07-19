async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
        const Minter = await ethers.getContractFactory("PulseManager");
        minter = await Minter.deploy();
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(1, minter.address);
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(1);
    console.log("Minter:", minter.address);
    console.log("Pulse:", pulse.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });