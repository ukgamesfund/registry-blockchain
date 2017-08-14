
const hex2str = require('./helpers/hex2string');
import expectThrow from './helpers/expectThrow';

let Promise = require('bluebird');

import {
	accounts, log,
	CONST,
	Status,
	Vote,
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

	it('should be able to deploy the name registry and set initial state', async () => {
		registry = await NameRegistry.new({from: ac.admin});

		assert.notEqual(registry.address, '');

		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let gold_account_name = hex2str(await registry.get_name_by_address(ac.gold));
		assert.equal(gold_account_name, CONST.GOLD_ACCOUNT);

		let gold_address = await registry.get_address_by_name(CONST.GOLD_ACCOUNT);
		assert.equal(gold_address, ac.gold);
	})

	it('should be able to deploy a project contract with 3 members - 2 Silver token holders', async () => {

		let members = [ac.member1, ac.member2, ac.member3];
		let silver = [11, 2, 0];
		let copper = [4, 5, 23];

		project = await Project.new(registry.address, VOTING_MAJ_PERCENTAGE, 'project1', members, silver, copper, {from: ac.member1})

		let project_name = await project.project_name();
		assert.equal(project_name, 'project1');

		let counter = await project.get_project_members_count();
		assert.equal(counter.toNumber(), 3);

		let silver_token_counter = await project.silver_token_counter();
		assert.equal(silver_token_counter.toNumber(), 13);

		let initiator = await project.project_initiator();
		assert.equal(initiator, ac.member1);

		let m1_s = await project.get_silver_tokens(ac.member1);
		let m1_c = await project.get_copper_tokens(ac.member1);
		let m1_n = await project.get_sodium_tokens(ac.member1);

		assert.equal(m1_s.toNumber(), 11);
		assert.equal(m1_c.toNumber(), 4);
		assert.equal(m1_n.toNumber(), 0);

		let m2_s = await project.get_silver_tokens(ac.member2);
		let m2_c = await project.get_copper_tokens(ac.member2);
		let m2_n = await project.get_sodium_tokens(ac.member2);

		assert.equal(m2_s.toNumber(), 2);
		assert.equal(m2_c.toNumber(), 5);
		assert.equal(m2_n.toNumber(), 0);

		let res_majority_percentage = await project.res_majority_percentage();
		assert.equal(res_majority_percentage.toNumber(), 60);

		// querying for an un-existing member should throw
		await expectThrow(project.get_silver_tokens(ac.member4));
	})

	it('should properly record member indexes', async () => {
		let m1 = await project.get_member_index(ac.member1);
		let m2 = await project.get_member_index(ac.member2);
		let m3 = await project.get_member_index(ac.member3);
		let m4 = await project.get_member_index(ac.member4);

		assert.equal(m1.toNumber(), 0);
		assert.equal(m2.toNumber(), 1);
		assert.equal(m3.toNumber(), 2);
		assert.equal(m4.toNumber(), CONST.NOT_A_MEMBER);
	})
	
	it('should be in the Status.Confirmed as all members confirmed through the app', async () => {

		let project_status = await project.get_project_status();
		assert.equal(project_status.toNumber(), Status.Confirmed);
	})

	it('should have recorded initial balances as checkpoints', async () => {

		let ts = await pGetLatestTimestamp();
		let ck0 = await project.get_checkpoint_idx(0, 0);
		let ck1 = await project.get_checkpoint_idx(1, 0);
		let ck2 = await project.get_checkpoint_idx(2, 0);

		assert.equal(ck0[0].toNumber(), ts);
		assert.equal(ck1[0].toNumber(), ts);
		assert.equal(ck2[0].toNumber(), ts);

		assert.equal(ck0[1].toNumber(), 11);
		assert.equal(ck1[1].toNumber(), 2);
		assert.equal(ck2[1].toNumber(), 0);

		assert.equal(ck0[2].toNumber(), 4);
		assert.equal(ck1[2].toNumber(), 5);
		assert.equal(ck2[2].toNumber(), 23);

		assert.equal(ck0[3].toNumber(), 0);
		assert.equal(ck1[3].toNumber(), 0);
		assert.equal(ck2[3].toNumber(), 0);
	})

});
