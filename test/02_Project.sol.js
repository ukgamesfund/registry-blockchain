
let Promise = require('bluebird');
import sleep from 'sleep-promise';
import expectThrow from './helpers/expectThrow';

import {
	accounts, log,
	CONST,
	Status,Vote,TokenType,ResStatus
}  from './common/common';

let NameRegistry = artifacts.require('../contracts/NameRegistry.sol');
let ProjectWrapper = artifacts.require('../contracts/ProjectWrapper.sol');

let chai = require('chai');
let assert = chai.assert;

contract('02_Project.sol', function(rpc_accounts) {

	let ac = accounts(rpc_accounts);

	let registry;
	let project;
	let VOTING_MAJ_PERCENTAGE = 60;

	let pGetBlock = Promise.promisify(web3.eth.getBlock);
	let pSendTransaction = Promise.promisify(web3.eth.sendTransaction);
	let pGetTransactionReceipt = Promise.promisify(web3.eth.getTransactionReceipt);
	let pGetTransaction = Promise.promisify(web3.eth.getTransaction);

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

		project = await ProjectWrapper.new(registry.address, VOTING_MAJ_PERCENTAGE, 'project2', members, silver, copper, {from: ac.member1})
	})

	it('should not allow a member that doesn\'t hold Silver tokens to create a resolution', async () => {

		let m3_idx = await project.get_member_index(ac.member3);
		await expectThrow(project.res_create_resolution(m3_idx, {from: ac.member1}));

		let not_a_member = await project.get_member_index(ac.member4);
		await expectThrow(project.res_create_resolution(not_a_member, {from: ac.member1}));
	})

	it('should allow a Silver Token holder to create a resolution', async () => {

		let m1_idx = await project.get_member_index(ac.member1);
		let receipt = await project.res_create_resolution(m1_idx, {from: ac.member1});

		let log0 = receipt.logs[0];

		assert.equal(log0.event, 'LogResolutionChange');
		assert.equal(log0.args['id'], '0');
		assert.equal(log0.args['status'], ResStatus.Created);

		let details = await project.res_get_details(0);
		let silver_token_counter = await project.silver_token_counter();
		let res_majority_percentage = await project.res_majority_percentage();

		let timestamp = await pGetLatestTimestamp();
		//["0","1502725883","0","1","0","0","13","60","0"]
		assert.equal(details[0].toNumber(), m1_idx.toNumber()); // initiator member index
		assert.equal(details[1].toNumber(), timestamp); // created
		assert.equal(details[2].toNumber(), 0); // expiry
		assert.equal(details[3].toNumber(), ResStatus.Created);
		assert.equal(details[4].toNumber(), 0); // silver_token_confirmations
		assert.equal(details[5].toNumber(), 0); // silver_token_rejections
		assert.equal(details[6].toNumber(), silver_token_counter.toNumber()); // silver_token_total
		assert.equal(details[7].toNumber(), res_majority_percentage.toNumber()); // majority_percentage
		assert.equal(details[8].toNumber(), 0); // transaction_counter
	})

	it('should allow the initiator of the resolution to add transactions', async () => {

		let tx1 = project.contract.res_set_token_value.getData(0, 0, TokenType.Silver, 20);
		await project.res_add_transaction(0, 0, tx1, {from: ac.member1});

		let details = await project.res_get_details(0);
		assert.equal(details[8].toNumber(), 1); // transaction_counter

		let tx_bytes = await project.res_get_transaction_hash(0, 0);
		let tx1_hash = web3.sha3(tx1, {encoding: 'hex'});
		assert.equal(tx1_hash, tx_bytes);
	})

	it('should allow the initiator the Commit the resolution to voting', async () => {
		let receipt = await project.res_commit_resolution(0, 0, {from: ac.member1});
		let timestamp = await pGetLatestTimestamp();

		let log0 = receipt.logs[0];
		assert.equal(log0.event, 'LogResolutionChange');
		assert.equal(log0.args['id'], '0');
		assert.equal(log0.args['status'], ResStatus.Committed);

		let details = await project.res_get_details(0);
		//["0","1502727870","1503332671","2","0","0","13","60","1"]
		assert.equal(details[2].toNumber(), timestamp+CONST.SECONDS_7D); // expiry
		assert.equal(details[3].toNumber(), ResStatus.Committed);
		assert.equal(details[8].toNumber(), 1); // transaction_counter
	})
});
