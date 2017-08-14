
const hex2str = require('./helpers/hex2string');
import expectThrow from './helpers/expectThrow';

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

		// querying for an un-existing member should throw
		await expectThrow(project.get_silver_tokens(ac.member4));
	})
	
	it('should be in the Status.Confirmed as all members confirmed through the app', async () => {

		let project_status = await project.get_project_status();
		assert.equal(project_status.toNumber(), Status.Confirmed);
	})

});
