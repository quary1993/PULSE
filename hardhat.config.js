const { version } = require("chai");

require("@nomiclabs/hardhat-waffle");
 
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers:[
      {
        version: "0.6.6",
      },
      {
        version: "0.6.12"
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/pU5x91s0MtTMxAn9Ml7uh_lE9j4JDHvG",
        blockNumber: 12651413
      }
    }, 
  }
};

