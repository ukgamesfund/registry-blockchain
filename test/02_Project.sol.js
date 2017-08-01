const assertJump = require('./helpers/assertJump');
const timer = require('./helpers/timer');
const hex2str = require('./helpers/hex2string');

import expectThrow from './helpers/expectThrow';

import {
	accounts, log,
	CONST,
	ProjectStatus,
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
		assert.equal(project_status.toNumber(), ProjectStatus.Rejected);
	})


});
