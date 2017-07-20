const assertJump = require('./helpers/assertJump');
const timer = require('./helpers/timer');
const hex2str = require('./helpers/hex2string');

import {
	accounts, log,
	CONST,
}  from './common/common';

let NameRegistry = artifacts.require('../contracts/NameRegistry.sol');

let chai = require('chai');
let assert = chai.assert;

contract('00_NameRegistry.sol', function(rpc_accounts) {

	let ac = accounts(rpc_accounts);

	let registry;

	it("should be able to deploy the name registry and set initial state", async () => {
		registry = await NameRegistry.new({from: ac.admin});

		assert.notEqual(registry.address, "");

		await registry.set(CONST.GOLD_ACCOUNT, ac.gold, {from:ac.admin});

		let goldAccountName = hex2str(await registry.getNameByAddress(ac.gold));
		assert.equal(goldAccountName, CONST.GOLD_ACCOUNT);
	})


});
