pragma solidity ^0.4.13;

import {NameRegistry} from './NameRegistry.sol';

library Lib {

	event LogProjectCreated(address initiator, string project_name);
	event LogInitialConfirmation(uint8 member_index, uint8 confirmation);

	event LogProjectConfirmed();
	event LogProjectSuspended();
	event LogProjectRejected();
	event LogProjectTerminated();

	event LogResolutionChange(uint32 id, uint8 status);
	event LogResolutionVote(uint32 id, uint8 member_index, uint8 vote);

	enum Status {
		None,
		Confirmed, // this is the main Active status
		Rejected,  // this is the terminal state when initially rejected
		Suspended, // this only happens when the gold account pauses the project
		Terminated // this happens by passing a resolution
	}

	enum ResStatus {
		None,

		Created,
		Committed,

		Suspended,
		Cancelled,
		Expired,

		Passed,
		Rejected,

		Executing, // in the middle of transaction execution
		Executed   // all transactions have already been executed
	}

	enum TokenType {
		None,
		Silver,
		Copper,
		Sodium
	}

	enum Vote {
		None,
		Confirm,
		Reject
	}

	struct Resolution {
		uint8     initiator; // the member who initiated the resolution, or 0xFF in the case of the GOLD account
		uint32    created;
		uint32    expiry;
		ResStatus status;

		int32 silver_token_confirmations;
		int32 silver_token_rejections;
		int32 silver_token_total;

		uint8 majority_percentage;

		uint8 transaction_counter;
		mapping(uint8 => bytes) transactions;// an array of raw transactions that need to pass atomically as per the resolution
		mapping(uint8 => Vote) votes;
	}

	struct Checkpoint {
		uint32 timestamp;

		int32 silver;
		int32 copper;
		int32 sodium;
	}


	struct Project {
		bytes32 GOLD_ACCOUNT;
		uint8   NOT_A_MEMBER;

		NameRegistry registry;
		Status project_status;
		string project_name;
		address project_initiator;
		address[] project_members;

		int32 project_allocation_cap;

		int32 silver_token_counter;
		int32 copper_token_counter;
		int32 sodium_token_counter;

		// the different token holdings
		mapping (uint8 => Checkpoint[]) token_balances;
		mapping (uint8 => bool) is_member_suspended;

		// data about resolutions
		uint8 res_majority_percentage;
		Resolution[] resolutions;
	}

	function constructor(Project storage self,
			address _registry,
			uint8 _res_majority_percentage,
			string _name,
			address[] _members,
			int32 [] _silver,
			int32 [] _copper) {

		// make sure we don't go over the hard limit of sizeof(byte) for the number of members
		require(_members.length < 0xff);
		require(_res_majority_percentage > 0 && _res_majority_percentage <= 100);

		self.GOLD_ACCOUNT = "ac.gold";
		self.NOT_A_MEMBER = 0xff;

		self.registry = NameRegistry(_registry);
		self.project_status = Status.Confirmed;
		self.project_name = _name;
		self.project_initiator = msg.sender;
		self.res_majority_percentage = _res_majority_percentage;

		self.project_allocation_cap = 1000000;

		// store the membership details
		for (uint8 i = 0; i < _members.length; i += 1) {
			self.project_members.push(_members[i]);

			Checkpoint memory cp = Checkpoint({
				timestamp: uint32(now),
				silver: _silver[i],
				copper: _copper[i],
				sodium: 0
			});
			self.token_balances[i].push(cp);

			self.silver_token_counter += _silver[i];
			self.copper_token_counter += _copper[i];
		}

		LogProjectCreated(self.project_initiator, self.project_name);
	}

	//--------------------------------------- modifiers ---------------------------------------------------------------

	modifier only_project_initiator(Project storage self) {
		require(msg.sender == self.project_initiator);
		_;
	}

	modifier only_in_confirmed_status(Project storage self) {
		require(self.project_status == Status.Confirmed);
		_;
	}

	modifier only_gold_account(Project storage self) {
		require(msg.sender == self.registry.get(self.GOLD_ACCOUNT));
		_;
	}

	modifier only_silver_token_holders(Project storage self) {
		require(get_silver_tokens(self, msg.sender)>0);
		_;
	}

	modifier only_silver_and_gold_accounts(Project storage self) {
		require(
			msg.sender == self.registry.get(self.GOLD_ACCOUNT) ||
			get_silver_tokens(self, msg.sender)>0
		);
		_;
	}

	modifier only_active_members(Project storage self, uint8 member_index) {
		if(member_index == self.NOT_A_MEMBER) {
			require(msg.sender == self.registry.get(self.GOLD_ACCOUNT));
		} else {
			require(msg.sender == self.project_members[member_index]);
			require(self.is_member_suspended[member_index]==false);
		}
		_;
	}

	//--------------------------------------- constant methods --------------------------------------------------------

	function res_get_passed_or_rejected(Project storage self, uint32 res_id) public constant returns (ResStatus){

		Resolution storage res = self.resolutions[res_id];
		int32 quorum_token_count = res.majority_percentage * res.silver_token_total;

		if(res.silver_token_confirmations * 100 >= quorum_token_count) {
			return ResStatus.Passed;
		}

		if(res.silver_token_rejections * 100 >= quorum_token_count) {
			return ResStatus.Rejected;
		}

		return ResStatus.None;
	}

	function get_project_members_count(Project storage self) public constant returns (uint8 _counter) {
		return uint8(self.project_members.length);
	}

	function get_member_index(Project storage self, address _member) public constant returns (uint8 _index) {
		for(uint8 i=0; i<self.project_members.length; i += 1) {
			if (self.project_members[i] == _member) {
				return i;
			}
		}

		return uint8(self.NOT_A_MEMBER);
	}

	function get_is_member_suspended(Project storage self, uint8 member_index) public constant returns(bool suspended) {
		return self.is_member_suspended[member_index];
	}

	function get_project_status(Project storage self) public constant returns(uint8 _status) {
		return uint8(self.project_status);
	}

	function get_silver_tokens_at(Project storage self, address _member, uint32 timestamp) public constant returns (int32 _tokens) {
		return get_tokens(self, _member, TokenType.Silver, timestamp);
	}

	function get_silver_tokens(Project storage self, address _member) public constant returns (int32 _tokens) {
		return get_tokens(self, _member, TokenType.Silver, 0);
	}

	function get_copper_tokens(Project storage self, address _member) public constant returns (int32 _tokens) {
		return get_tokens(self, _member, TokenType.Copper, 0);
	}

	function get_sodium_tokens(Project storage self, address _member) public constant returns (int32 _tokens) {
		return get_tokens(self, _member, TokenType.Sodium, 0);
	}

	function get_tokens(Project storage self, address _member, TokenType _token_type, uint32 _timestamp)
	public constant returns (int32) {
		uint8 index = get_member_index(self, _member);
		require(index != self.NOT_A_MEMBER);

		if(_timestamp == 0) {
			_timestamp = uint32(now);
		}

		Checkpoint memory cp = get_checkpoint_at(self, index, _timestamp);

		if (_token_type == TokenType.Silver) {
			return cp.silver;
		}

		if (_token_type == TokenType.Copper) {
			return cp.copper;
		}

		if (_token_type == TokenType.Sodium) {
			return cp.sodium;
		}

		return 0;
	}

	function get_checkpoint_at(Project storage self, uint8 member_index, uint32 _timestamp)
	constant internal returns (Checkpoint) {
		require(member_index != self.NOT_A_MEMBER);
		Checkpoint[] storage checkpoints = self.token_balances[member_index];

		Checkpoint memory ret_cp = Checkpoint(0,0,0,0);

		if (checkpoints.length == 0) {
			return ret_cp;
		}


		// Shortcut for the actual value
		if (_timestamp >= checkpoints[checkpoints.length-1].timestamp) {
			ret_cp = checkpoints[checkpoints.length-1];
			return ret_cp;
		}

		if (_timestamp < checkpoints[0].timestamp) {
			return ret_cp;
		}

		// Binary search of the value in the array
		uint min = 0;
		uint max = checkpoints.length-1;
		while (max > min) {
			uint mid = (max + min + 1)/ 2;
			if (checkpoints[mid].timestamp <= _timestamp) {
				min = mid;
			} else {
				max = mid-1;
			}
		}
		return checkpoints[min];
	}

	function get_checkpoint_idx(Project storage self, uint8 member_index, uint32 cp_index) constant
	returns (uint32 _timestamp, int32 _silver, int32 _copper, int32 _sodium){
		Checkpoint[] storage checkpoints = self.token_balances[member_index];
		Checkpoint storage cp = checkpoints[cp_index];
		_timestamp = cp.timestamp;
		_silver = cp.silver;
		_copper = cp.copper;
		_sodium = cp.sodium;
	}

	function res_get_details(Project storage self, uint32 res_id) public constant returns(
		uint8 initiator,
		uint32 created,
		uint32 expiry,
		ResStatus status,
		int32 silver_token_confirmations,
		int32 silver_token_rejections,
		int32 silver_token_total,
		uint8 majority_percentage,
		uint8 transaction_counter) {

		require(res_id < self.resolutions.length);

		Resolution storage res = self.resolutions[res_id];
		initiator = res.initiator;
		created = res.created;
		expiry = res.expiry;
		status = res.status;
		silver_token_confirmations = res.silver_token_confirmations;
		silver_token_rejections = res.silver_token_rejections;
		silver_token_total = res.silver_token_total;
		majority_percentage = res.majority_percentage;
		transaction_counter = res.transaction_counter;
	}

	function res_get_transaction_hash(Project storage self, uint32 res_id, uint8 tx_id) public constant returns (bytes32) {
		require(res_id < self.resolutions.length);
		require(tx_id < self.resolutions[res_id].transaction_counter);
		return sha3(self.resolutions[res_id].transactions[tx_id]);
	}

	//--------------------------------------- gold  functions --------------------------------------------------------

	// this can be used by the GOLD account to pause and un-pause the project
	function gold_set_project_status(Project storage self, Status status)
	only_gold_account(self) {
		self.project_status = status;
	}

	function gold_set_member_status(Project storage self, uint8 member_index, bool suspended) public
	only_in_confirmed_status(self)
	only_gold_account(self) {
		require(member_index < self.project_members.length);
		self.is_member_suspended[member_index] = suspended;
	}

	// TODO:  should we have this function ?
	function gold_set_resolution_status(Project storage self, uint32 res_id, ResStatus status) public
	only_in_confirmed_status(self)
	only_gold_account(self) {
		require(res_id < self.resolutions.length);
		self.resolutions[res_id].status = status;
	}

	//--------------------------------------- resolution functions -----------------------------------------------------

	function res_create_resolution(Project storage self, uint8 sender_index) public
	only_active_members(self, sender_index)
	only_silver_and_gold_accounts(self)
	only_in_confirmed_status(self) {

		Resolution memory res = Resolution({
			initiator: sender_index,
			status: ResStatus.Created,
			created: uint32(now),
			expiry: 0,
			silver_token_total: self.silver_token_counter,
			silver_token_confirmations: 0,
			silver_token_rejections: 0,
			transaction_counter: 0,
			majority_percentage: self.res_majority_percentage
		});
		self.resolutions.push(res);

		LogResolutionChange(uint32(self.resolutions.length-1), uint8(ResStatus.Created));
	}

	// only the data part of the tx is needed, the 'to' part is 'this'
	function res_add_transaction(Project storage self, uint8 sender_index, uint32 res_id, bytes tx_data) public
	only_active_members(self, sender_index)
	only_silver_and_gold_accounts(self)
	only_in_confirmed_status(self) {

		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Created);

		Resolution storage res = self.resolutions[res_id];
		require(res.transaction_counter < 0xff);

		res.transactions[res.transaction_counter++] = tx_data;
	}

	function res_commit_resolution(Project storage self, uint8 sender_index, uint32 res_id) public
	only_active_members(self, sender_index)
	only_silver_and_gold_accounts(self)
	only_in_confirmed_status(self) {

		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Created);

		self.resolutions[res_id].expiry = uint32(now + 7 days);
		self.resolutions[res_id].status = ResStatus.Committed;

		LogResolutionChange(res_id, uint8(ResStatus.Committed));
	}

	function res_cancel_resolution(Project storage self, uint8 sender_index, uint32 res_id) public
	only_active_members(self, sender_index)
	only_silver_and_gold_accounts(self)
	only_in_confirmed_status(self) {

		require(res_id < self.resolutions.length);
		require(
			self.resolutions[res_id].expiry > 0 &&
			self.resolutions[res_id].expiry < now
		);

		self.resolutions[res_id].status = ResStatus.Cancelled;
		LogResolutionChange(res_id, uint8(ResStatus.Cancelled));
	}


	// only for the GOLD account to do
	function res_suspend_resolution(Project storage self, uint32 res_id) public
	only_in_confirmed_status(self)
	only_gold_account(self) {

		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Committed);
		require(
			self.resolutions[res_id].expiry > 0 &&
			self.resolutions[res_id].expiry < now
		);

		self.resolutions[res_id].status = ResStatus.Suspended;
		self.resolutions[res_id].expiry = 0;

		LogResolutionChange(res_id, uint8(ResStatus.Suspended));
	}

	// only for the GOLD account to do
	function res_resume_resolution(Project storage self, uint32 res_id, uint32 timestamp) public
	only_in_confirmed_status(self)
	only_gold_account(self) {

		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Suspended);
		require(self.resolutions[res_id].expiry == 0);

		self.resolutions[res_id].status = ResStatus.Committed;
		self.resolutions[res_id].expiry = timestamp;

		LogResolutionChange(res_id, uint8(ResStatus.Committed));
	}

	function res_vote_resolution(Project storage self, uint8 sender_index, uint32 res_id, Vote vote) public
	only_active_members(self, sender_index)
	only_in_confirmed_status(self)
	only_silver_token_holders(self) {

		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Committed);
		require(
			0 < self.resolutions[res_id].expiry &&
			self.resolutions[res_id].expiry > now
		);

		Resolution storage res = self.resolutions[res_id];

		require(msg.sender == self.project_members[sender_index]);
		require(res.votes[sender_index] == Vote.None);
		require(
			vote == Vote.Confirm ||
			vote == Vote.Reject
		);

		// record the vote
		res.votes[sender_index] = vote;

		Checkpoint memory cp = get_checkpoint_at(self, sender_index, res.created);
		if(vote == Vote.Confirm) {
			res.silver_token_confirmations += cp.silver;
		}

		if(vote == Vote.Reject) {
			res.silver_token_rejections += cp.silver;
		}

		LogResolutionVote(res_id, sender_index, uint8(vote));

		ResStatus result = res_get_passed_or_rejected(self, res_id);

		if(result == ResStatus.Passed || result == ResStatus.Rejected) {
			res.status = result;
			LogResolutionChange(res_id, uint8(result));
		}
	}

	function res_execute_resolution(Project storage self, uint8 sender_index, uint32 res_id) public
	only_active_members(self, sender_index)
	only_silver_and_gold_accounts(self)
	only_in_confirmed_status(self) {

		require(res_id < uint32(self.resolutions.length));
		require(self.resolutions[res_id].status == ResStatus.Passed);

		Resolution storage res = self.resolutions[res_id];

		// this is a guard that can be checked by resolution transactions as a Green signal
		res.status = ResStatus.Executing;

		for(uint8 index=0; index < uint8(res.transaction_counter); index += 1) {
			require(
				this.call(res.transactions[index])
			);
		}

		res.status = ResStatus.Executed;
		LogResolutionChange(res_id, uint8(res.status));
	}

	//--------------------------------------- Resolution executed functions -------------------------------------------

	modifier only_executing_resolution(Project storage self, uint32 res_id) {
		require(res_id < self.resolutions.length);
		require(self.resolutions[res_id].status == ResStatus.Executing);
		_;
	}

	function res_set_token_value(
			Project storage self,
			uint32 res_id,
			uint8 member_index,
			TokenType token_type,
			int32 tokens_number)

		only_in_confirmed_status(self)
		only_executing_resolution(self, res_id) public { // this is only 'public' so we can get the data to add to the resolution

		require(member_index >= 0);
		require(member_index < self.project_members.length);
		require(tokens_number >= 0);

		Checkpoint[] storage checkpoints = self.token_balances[member_index];
		Checkpoint memory cp = Checkpoint(0,0,0,0);

		if (checkpoints.length > 0) {
			cp = checkpoints[checkpoints.length-1];
		}

		cp.timestamp = uint32(now);

		if(token_type == TokenType.Silver) {
			self.silver_token_counter += (tokens_number - cp.silver);
			cp.silver = tokens_number;
		}
		if(token_type == TokenType.Copper) {
			self.copper_token_counter += (tokens_number - cp.copper);
			cp.copper = tokens_number;
		}
		if(token_type == TokenType.Sodium) {
			self.sodium_token_counter += (tokens_number - cp.sodium);
			cp.sodium = tokens_number;
		}

		require(self.silver_token_counter + self.copper_token_counter <= self.project_allocation_cap);
		checkpoints.push(cp);
	}

	function res_convert_tokens(
		Project storage self,
		uint32 res_id,
		uint8 member_index,
		int32 tokens_number,
		TokenType from_type,
		TokenType to_type)

	only_in_confirmed_status(self)
	only_executing_resolution(self, res_id) public {

		require(member_index != self.NOT_A_MEMBER);
		require(member_index >= 0);
		require(member_index < self.project_members.length);

		require(from_type == TokenType.Silver || from_type == TokenType.Copper);
		require(from_type != to_type);

		Checkpoint[] storage checkpoints = self.token_balances[member_index];
		require(checkpoints.length > 0);

		Checkpoint memory cp = checkpoints[checkpoints.length-1];
		cp.timestamp = uint32(now);

		if(from_type == TokenType.Silver) {
			self.silver_token_counter -= tokens_number;
			cp.silver -= tokens_number;
		}
		else {
			self.copper_token_counter -= tokens_number;
			cp.copper -= tokens_number;
		}


		if(to_type == TokenType.Silver) {
			self.silver_token_counter += tokens_number;
			cp.silver += tokens_number;
		}
		else if(to_type == TokenType.Copper) {
			self.copper_token_counter += tokens_number;
			cp.copper += tokens_number;
		}
		else {
			self.sodium_token_counter += tokens_number;
			cp.sodium += tokens_number;
		}

		require(self.silver_token_counter + self.copper_token_counter <= self.project_allocation_cap);
		checkpoints.push(cp);
	}

	function res_change_majority_percentage(Project storage self, uint32 res_id, uint8 new_majority_percentage)
	only_in_confirmed_status(self)
	only_executing_resolution(self, res_id) public {
		require(new_majority_percentage > 0);
		require(new_majority_percentage <= 100);

		self.res_majority_percentage = new_majority_percentage;
	}
}

