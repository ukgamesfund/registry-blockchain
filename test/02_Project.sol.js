
let Promise = require('bluebird');
import sleep from 'sleep-promise';


import {
	accounts, log,
	CONST,
	Status,Vote,TokenType,
}  from './common/common';

let NameRegistry = artifacts.require('../contracts/NameRegistry.sol');
let Project = artifacts.require('../contracts/Project.sol');

let chai = require('chai');
let assert = chai.assert;

contract('01_Project.sol', function(rpc_accounts) {

	let ac = accounts(rpc_accounts);

	let registry;
	let project;
	let VOTING_MAJ_PERCENTAGE = 60;

	let pGetBlock = Promise.promisify(web3.eth.getBlock);

	async function pGetLatestTimestamp() {
		let _block = await pGetBlock('latest')
		return Promise.resolve(parseInt(_block.timestamp));
	}

	it('should make the initial setup with no exception thrown', async () => {
		registry = await NameRegistry.new({from: ac.admin});
		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let members = [ac.member1, ac.member2, ac.member3];
		let silver = [11, 2, 0];
		let copper = [4, 5, 23];

		project = await Project.new(registry.address, VOTING_MAJ_PERCENTAGE, 'project2', members, silver, copper, {from: ac.member1})
	})


});
