let Migrations = artifacts.require("../zeppelin/contracts/lifecycle/Migrations.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
