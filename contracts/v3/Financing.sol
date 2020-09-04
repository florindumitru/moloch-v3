pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import './ModuleRegistry.sol';
import './Proposal.sol';
import './Voting.sol';
import './Bank.sol';
import '../SafeMath.sol';
import '../ReentrancyGuard.sol';

interface IFinancingContract {
    function createFinancingRequest(address daoAddress, address applicant, uint256 amount, bytes32 details) external returns (uint256);    
    function processProposal(uint256 proposalId) external;
}

contract FinancingContract is IFinancingContract {
    using SafeMath for uint256;

    struct ProposalDetails {
        address applicant;
        uint256 amount;
        bytes32 details;
        bool processed;
    }

    mapping(uint256 => ProposalDetails) public proposals;

    bytes32 constant BANK_MODULE = keccak256("bank");
    bytes32 constant VOTING_MODULE = keccak256("voting");
    bytes32 constant MEMBER_MODULE = keccak256("member");
    bytes32 constant PROPOSAL_MODULE = keccak256("proposal");

    ModuleRegistry dao;

    constructor (address _dao) {
        dao = ModuleRegistry(_dao);
    }

    /* 
     * default fallback function to prevent from sending ether to the contract
     */
    receive() external payable {
        revert();
    }

    function createFinancingRequest(address daoAddress, address applicant, uint256 amount, bytes32 details) override external returns (uint256) {
        require(daoAddress != address(0x0), "dao address can not be empty");
        require(applicant != address(0x0), "applicant address can not be empty");
        require(daoAddress != address(0x0), "dao address can not be empty");
        require(amount > 0, "invalid requested amount");

        IBankContract bankContract = IBankContract(dao.getAddress(BANK_MODULE));
        require(bankContract.isReservedAddress(applicant), "applicant address cannot be reserved");
        
        IProposalContract proposalContract = IProposalContract(dao.getAddress(PROPOSAL_MODULE));
        uint256 proposalId = proposalContract.createProposal(dao);

        ProposalDetails storage proposal = proposals[proposalId];
        proposal.applicant = applicant;
        proposal.amount = amount;
        proposal.details = details;
        proposal.processed = false;
        return proposalId;
    }

    function processProposal(uint256 proposalId) override external {
        IMemberContract memberContract = IMemberContract(dao.getAddress(MEMBER_MODULE));
        require(memberContract.isActiveMember(dao, msg.sender), "only members can process a financial proposal");

        IVotingContract votingContract = IVotingContract(dao.getAddress(VOTING_MODULE));
        require(votingContract.voteResult(dao, proposalId) == 2, "proposal need to pass to be processed");

        ProposalDetails memory proposal = proposals[proposalId];

        IBankContract bankContract = IBankContract(dao.getAddress(BANK_MODULE));
        // address 0 represents native ETH
        bankContract.addToEscrow(dao, address(0), proposal.amount);
        proposals[proposalId].processed = true;
        payable(address(bankContract)).transfer(proposal.amount); 
    }
}