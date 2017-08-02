
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

	let pGetBlock = Promise.promisify(web3.eth.getBlock);

	async function pGetLatestTimestamp() {
		let _block = await pGetBlock('latest')
		return Promise.resolve(parseInt(_block.timestamp));
	}

	it('should make the initial setup with no exception thrown', async () => {
		registry = await NameRegistry.new({from: ac.admin});
		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let members = [ac.member1, ac.member2];
		let silver = [11, 2];
		let copper = [4, 5];

		project = await Project.new(registry.address, 'project2', members, silver, copper, {from: ac.member1})
	})


	it('should be able to record membership confirmation ONLY from the added members', async () => {

		let id1 = await project.get_member_index(ac.member1)
		let id2 = await project.get_member_index(ac.member2)

		let rec1 = await project.member_initial_response(id1.toNumber(), Vote.Confirm, {from: ac.member1})
		let log1 = rec1.logs
		assert.equal(log1[0].event, 'LogInitialConfirmation');
		assert.equal(log1[0].args.member_index, '0');
		assert.equal(log1[0].args.confirmation, Vote.Confirm);

		let counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 1);

		let rec2 = await project.member_initial_response(id2.toNumber(), Vote.Reject, {from: ac.member2})
		let log2 = rec2.logs
		assert.equal(log2[0].event, 'LogInitialConfirmation');
		assert.equal(log2[0].args.member_index, '1');
		assert.equal(log2[0].args.confirmation, Vote.Reject);

		assert.equal(log2[1].event, 'LogProjectRejected');

		counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 1);

		let project_status = await project.get_project_status();
		assert.equal(project_status.toNumber(), Status.Rejected);
	})

	it('should be able to test setting token value using the \'test_set_token_value_now\' function', async () => {

		let id1 = await project.get_member_index(ac.member1);
		let ts1 = await pGetLatestTimestamp();

		await sleep(1000);
		await project.test_set_token_value_now(id1, TokenType.Silver, 32);

		let silver1 = await project.get_silver_tokens(ac.member1);
		assert.equal(silver1.toNumber(), 32);

		// let's now check if we can get the old value back
		silver1 = await project.get_tokens(ac.member1, TokenType.Silver, ts1);
		assert.equal(silver1.toNumber(), 11);

		// now explicitly query at ts2
		let ts2 = await pGetLatestTimestamp();
		silver1 = await project.get_tokens(ac.member1, TokenType.Silver, ts2);
		assert.equal(silver1.toNumber(), 32);
	})

	it('should be able to test setting token value multiple times - testing binary search', async () => {
		let id1 = await project.get_member_index(ac.member1);

		let tss = [];
		for(let i=0; i<5; i++) {
			await project.test_set_token_value_now(id1, TokenType.Silver, i*100);
			let ts1 = await pGetLatestTimestamp();
			await project.test_set_token_value_now(id1, TokenType.Copper, i*200);
			let ts2 = await pGetLatestTimestamp();
			await project.test_set_token_value_now(id1, TokenType.Sodium, i*300);
			let ts3 = await pGetLatestTimestamp();
			tss.push([ts1,ts2,ts3]);
			await sleep(1000);
		}

		for(let i=0; i<5; i++) {
			let value1 = await project.get_tokens(ac.member1, TokenType.Silver, tss[i][0]);
			let value2 = await project.get_tokens(ac.member1, TokenType.Copper, tss[i][1]);
			let value3 = await project.get_tokens(ac.member1, TokenType.Sodium, tss[i][2]);
			assert.equal(value1.toNumber(), i*100);
			assert.equal(value2.toNumber(), i*200);
			assert.equal(value3.toNumber(), i*300);
		}
	})


});
