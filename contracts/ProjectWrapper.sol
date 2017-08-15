pragma solidity ^0.4.13;

import {Ownable} from '../zeppelin/contracts/ownership/Ownable.sol';
import {NameRegistry} from './NameRegistry.sol';
import {Lib} from './Lib.sol';

contract ProjectWrapper is Ownable {

	using Lib for Lib.Project;
	Lib.Project project;

	event LogProjectCreated(address initiator, string project_name);
	event LogInitialConfirmation(uint8 member_index, uint8 confirmation);

	event LogProjectConfirmed();
	event LogProjectSuspended();
	event LogProjectRejected();
	event LogProjectTerminated();

	event LogResolutionChange(uint32 id, uint8 status);
	event LogResolutionVote(uint32 id, uint8 member_index, uint8 vote);

	function ProjectWrapper(
		address _registry,
		uint8 _res_majority_percentage,
		string _name,
		address[] _members,
		int32 [] _silver,
		int32 [] _copper) {

		project.constructor(
			_registry,
			_res_majority_percentage,
			_name,
			_members,
			_silver,
			_copper
		);

		transferOwnership(project.registry.get(project.GOLD_ACCOUNT));
	}

	// block the direct ETH transfer to this contract
	function() {
		revert();
	}

	// members of the project structure

	function project_name() public constant returns (string) {
		return project.project_name;
	}

	function silver_token_counter() public constant returns (int32) {
		return project.silver_token_counter;
	}

	function copper_token_counter() public constant returns (int32) {
		return project.copper_token_counter;
	}

	function project_initiator() public constant returns (address) {
		return project.project_initiator;
	}

	// constant methods

	function get_project_members_count() public constant returns (uint8) {
		return project.get_project_members_count();
	}

	function get_member_index(address _member) public constant returns (uint8) {
		return project.get_member_index(_member);
	}

	function get_project_status() public constant returns(Lib.Status) {
		return project.project_status;
	}

	function get_checkpoint_idx(uint8 member_index, uint32 cp_index) constant
		returns (uint32 _timestamp, int32 _silver, int32 _copper, int32 _sodium){

		return project.get_checkpoint_idx(member_index, cp_index);
	}

	function get_tokens(address member, Lib.TokenType token_type, uint32 timestamp) public constant returns (int32) {
		return project.get_tokens(member, token_type, timestamp);
	}

	function res_majority_percentage() public constant returns (uint8) {
		return project.res_majority_percentage;
	}

	function res_get_details(uint32 res_id) public constant returns(
		uint8 initiator,
		uint32 created,
		uint32 expiry,
		Lib.ResStatus status,
		int32 silver_token_confirmations,
		int32 silver_token_rejections,
		int32 silver_token_total,
		uint8 majority_percentage,
		uint8 transaction_counter) {

		return project.res_get_details(res_id);
	}

	function res_get_transaction_hash(uint32 res_id, uint8 tx_id) public constant returns (bytes32) {
		return project.res_get_transaction_hash(res_id, tx_id);
	}


	// state changing methods

	function res_create_resolution(uint8 sender_index) public {
		return project.res_create_resolution(sender_index);
	}

	function res_commit_resolution(uint8 sender_index, uint32 res_id) public {
		return project.res_commit_resolution(sender_index, res_id);
	}

	function res_set_token_value(uint32 res_id, uint8 member_index, Lib.TokenType token_type, int32 tokens_number) public {
		return project.res_set_token_value(res_id, member_index, token_type, tokens_number);
	}

	function res_add_transaction(uint8 sender_index, uint32 res_id, bytes tx_data) public {
		return project.res_add_transaction(sender_index, res_id, tx_data);
	}

	function res_vote_resolution(uint8 sender_index, uint32 res_id, Lib.Vote vote) public {
		return project.res_vote_resolution(sender_index, res_id,  vote);
	}

	function res_execute_resolution(uint8 sender_index, uint32 res_id) public {
		return project.res_execute_resolution(sender_index, res_id);
	}
}