
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

		let silver_member_counter = await project.silver_member_counter();
		assert.equal(silver_member_counter.toNumber(), 2);

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
	
	it('should still be in the Status.Created', async () => {

		let project_status = await project.get_project_status();
		assert.equal(project_status.toNumber(), Status.Created);
	})

	it('should be able to record membership confirmation ONLY from the Silver token holders', async () => {

		let id1 = await project.get_member_index(ac.member1)
		let id2 = await project.get_member_index(ac.member2)
		let id3 = await project.get_member_index(ac.member3)
		let id4 = await project.get_member_index(ac.member4)

		// member4 is not a member of this project, this should be reflected by querying his index
		assert.equal(id4.toNumber(), CONST.NOT_A_MEMBER);

		await expectThrow(project.member_initial_response(id3.toNumber(), Vote.Confirm), {from: ac.member3});
		await expectThrow(project.member_initial_response(id3.toNumber(), Vote.Reject), {from: ac.member3});

		// member_index = 4 doesn't exist and it should not be allowed to send a transaction
		await expectThrow(project.member_initial_response(4, Vote.Confirm), {from: ac.member4})
		let counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 0);

		// member_index = 4 doesn't exist; an existing member should not be allowed to accept a different index
		await expectThrow(project.member_initial_response(4, Vote.Confirm, {from: ac.member1}))
		counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 0);

		// member1 has index 0, it should not be able to call with index = 1
		await expectThrow(project.member_initial_response(1, Vote.Confirm, {from: ac.member1}))
		counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 0);

		let rec1 = await project.member_initial_response(id1.toNumber(), Vote.Confirm, {from: ac.member1})
		let log1 = rec1.logs
		assert.equal(log1[0].event, 'LogInitialConfirmation');
		assert.equal(log1[0].args.member_index, '0');
		assert.equal(log1[0].args.confirmation, Vote.Confirm);

		counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 1);

		let rec2 = await project.member_initial_response(id2.toNumber(), Vote.Confirm, {from: ac.member2})
		let log2 = rec2.logs
		assert.equal(log2[0].event, 'LogInitialConfirmation');
		assert.equal(log2[0].args.member_index, '1');
		assert.equal(log2[0].args.confirmation, Vote.Confirm);

		assert.equal(log2[1].event, 'LogProjectConfirmed');

		counter = await project.member_confirmation_counter()
		assert.equal(counter.toNumber(), 2);

		let project_status = await project.get_project_status();
		assert.equal(project_status.toNumber(), Status.Confirmed);
	})

	it('should be able to compute the needed quorum to achieve resolution passing without using float data-type', async () => {

		// we have 2 Silver token holders and the majority percentage is set to 60%

		let res = await project.res_is_quorum_achieved(1);
		assert.equal(res, false);

		res = await project.res_is_quorum_achieved(2);
		assert.equal(res, true);

		let maj = await project.get_res_majority_member_count();
		assert.equal(maj.toNumber(), 120);
	})


});
