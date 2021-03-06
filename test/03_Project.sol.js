
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

contract('03: Create and Pass resolution that executes: token conversion function ', function(rpc_accounts) {

	let ac = accounts(rpc_accounts);

	let registry;
	let project;
	let VOTING_MAJ_PERCENTAGE = 60;

	it('should make the initial setup with no exception thrown', async () => {

		registry = await NameRegistry.new({from: ac.admin});
		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let members = [ac.member1, ac.member2, ac.member3, ac.member4];
		let silver = [11, 2, 0, 7];
		let copper = [4, 5, 23, 9];

		project = await ProjectWrapper.new(registry.address, VOTING_MAJ_PERCENTAGE, 'project2', members, silver, copper, {from: ac.member1})
	})

	it('should create, pass and execute resolution - success case', async () => {

		let res0_tokens_number = 5;
		let res0_tt_from = TokenType.Silver;
		let res0_tt_to = TokenType.Copper;

		let m1_idx = await project.get_member_index(ac.member1);
		let m2_idx = await project.get_member_index(ac.member2);
		let m4_idx = await project.get_member_index(ac.member4);

		await project.res_create_resolution(m1_idx, {from: ac.member1});

		let tx1 = project.contract.res_convert_tokens.getData(0, m1_idx, res0_tokens_number, res0_tt_from, res0_tt_to);
		await project.res_add_transaction(0, 0, tx1, {from: ac.member1});
		await project.res_commit_resolution(0, 0, {from: ac.member1});

		await project.res_vote_resolution(m1_idx.toNumber(), 0, Vote.Confirm, {from: ac.member1});
		await project.res_vote_resolution(m2_idx.toNumber(), 0, Vote.Confirm, {from: ac.member2});

		let silver_before = await project.silver_token_counter();
		let copper_before = await project.copper_token_counter();

		await project.res_execute_resolution(m4_idx.toNumber(), 0, {from: ac.member4});

		let m1_s = await project.get_tokens(ac.member1, TokenType.Silver, 0);
		let m1_c = await project.get_tokens(ac.member1, TokenType.Copper, 0);

		assert.equal(m1_s.toNumber(), 11 - res0_tokens_number);
		assert.equal(m1_c.toNumber(), 4 + res0_tokens_number);

		let silver_after= await project.silver_token_counter();
		let copper_after = await project.copper_token_counter();

		assert.equal(silver_after.toNumber(), silver_before.toNumber() - res0_tokens_number);
		assert.equal(copper_after.toNumber(), copper_before.toNumber() + res0_tokens_number);
	})

	it('should create, pass and execute resolution - failure case', async () => {

		let res0_tokens_number = 12;
		let res0_tt_from = TokenType.Silver;
		let res0_tt_to = TokenType.Copper;

		let m1_idx = await project.get_member_index(ac.member1);
		let m2_idx = await project.get_member_index(ac.member2);
		let m4_idx = await project.get_member_index(ac.member4);

		await project.res_create_resolution(m1_idx, {from: ac.member1});

		let tx1 = project.contract.res_convert_tokens.getData(0, m1_idx, res0_tokens_number, res0_tt_from, res0_tt_to);
		await project.res_add_transaction(0, 1, tx1, {from: ac.member1});
		await project.res_commit_resolution(0, 1, {from: ac.member1});

		await project.res_vote_resolution(m1_idx.toNumber(), 1, Vote.Confirm, {from: ac.member1});
		let rec3 = await project.res_vote_resolution(m4_idx.toNumber(), 1, Vote.Confirm, {from: ac.member4});

		let log1 = rec3.logs[1];
		assert.equal(log1.event, 'LogResolutionChange');
		assert.equal(log1.args['id'], '1');
		assert.equal(log1.args['status'], ResStatus.Passed);

		await expectThrow(project.res_execute_resolution(m4_idx.toNumber(), 0, {from: ac.member4}));
	})

});
