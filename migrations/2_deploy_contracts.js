
let NameRegistry = artifacts.require("../contracts/NameRegistry.sol");
let Lib = artifacts.require("../contracts/Lib.sol");
let ProjectWrapper = artifacts.require("../contracts/ProjectWrapper.sol");

module.exports = async function(deployer) {
	await deployer.deploy([Lib]);
	await deployer.link(Lib,[ProjectWrapper]);
};
