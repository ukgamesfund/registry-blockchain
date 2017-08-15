
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

contract('04: Resolution0: decrease VOTING_MAJ_PERCENTAGE; Resolution1 raise silver token allocation to member 1', function(rpc_accounts) {
	let ac = accounts(rpc_accounts);

	let registry;
	let project;
	let VOTING_MAJ_PERCENTAGE = 60;
	let new_voting_maj_percentage = 10;

	it('should make the initial setup with no exception thrown', async () => {

		registry = await NameRegistry.new({from: ac.admin});
		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let members = [ac.member1, ac.member2, ac.member3, ac.member4];
		let silver = [11, 2, 0, 7];
		let copper = [4, 5, 23, 9];

		project = await ProjectWrapper.new(registry.address, VOTING_MAJ_PERCENTAGE, 'project2', members, silver, copper, {from: ac.member1})
	})

	it('should raise no exception passing the resolution to lower voting majority percentage', async () => {

		let m1_idx = await project.get_member_index(ac.member1);
		let m2_idx = await project.get_member_index(ac.member2);
		let m4_idx = await project.get_member_index(ac.member4);

		await project.res_create_resolution(m1_idx, {from: ac.member1});

		let tx1 = project.contract.res_change_majority_percentage.getData(0, new_voting_maj_percentage);
		await project.res_add_transaction(0, 0, tx1, {from: ac.member1});
		await project.res_commit_resolution(0, 0, {from: ac.member1});

		await project.res_vote_resolution(m1_idx.toNumber(), 0, Vote.Confirm, {from: ac.member1});
		await project.res_vote_resolution(m2_idx.toNumber(), 0, Vote.Confirm, {from: ac.member2});

		let maj_percentage_before = await project.res_majority_percentage();
		assert.equal(maj_percentage_before.toNumber(), VOTING_MAJ_PERCENTAGE);

		await project.res_execute_resolution(m4_idx.toNumber(), 0, {from: ac.member4});

		let maj_percentage_after = await project.res_majority_percentage();
		assert.equal(maj_percentage_after.toNumber(), new_voting_maj_percentage);
	})

	it('should raise no exception passing a resolution with just one vote thanks to the new voting majority percentage', async () => {

		let m1_idx = await project.get_member_index(ac.member1);

		await project.res_create_resolution(m1_idx, {from: ac.member1});

		let tx1 = project.contract.res_set_token_value.getData(1, m1_idx, TokenType.Silver, 999);
		await project.res_add_transaction(0, 1, tx1, {from: ac.member1});
		await project.res_commit_resolution(0, 1, {from: ac.member1});

		let rec3 = await project.res_vote_resolution(m1_idx.toNumber(), 1, Vote.Confirm, {from: ac.member1});

		let log1 = rec3.logs[1];
		assert.equal(log1.event, 'LogResolutionChange');
		assert.equal(log1.args['id'], '1');
		assert.equal(log1.args['status'], ResStatus.Passed);

		await project.res_execute_resolution(m1_idx.toNumber(), 1, {from: ac.member1});

		let m1_s = await project.get_tokens(ac.member1, TokenType.Silver, 0);
		assert.equal(m1_s.toNumber(), 999);
	})

});
