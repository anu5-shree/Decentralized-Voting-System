// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DecentralizedVoting {
    
    // Struct to represent a poll
    struct Poll {
        uint256 id;
        string title;
        string description;
        string[] options;
        uint256[] votes;
        uint256 startTime;
        uint256 endTime;
        address creator;
        bool isActive;
        mapping(address => bool) hasVoted;
        address[] voters;
    }
    
    // State variables
    mapping(uint256 => Poll) public polls;
    mapping(address => bool) public registeredVoters;
    mapping(address => bool) public authorizedPollers;
    
    uint256 public pollCount;
    address public admin;
    
    // Events
    event VoterRegistered(address indexed voter);
    event PollerAuthorized(address indexed poller);
    event PollCreated(uint256 indexed pollId, string title, address indexed creator);
    event VoteCast(uint256 indexed pollId, address indexed voter, uint256 optionIndex);
    event PollEnded(uint256 indexed pollId);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(registeredVoters[msg.sender], "You must be a registered voter");
        _;
    }
    
    modifier onlyAuthorizedPoller() {
        require(authorizedPollers[msg.sender], "You must be an authorized poller");
        _;
    }
    
    modifier validPoll(uint256 _pollId) {
        require(_pollId < pollCount, "Poll does not exist");
        _;
    }
    
    modifier pollActive(uint256 _pollId) {
        require(polls[_pollId].isActive, "Poll is not active");
        require(block.timestamp >= polls[_pollId].startTime, "Poll has not started yet");
        require(block.timestamp <= polls[_pollId].endTime, "Poll has ended");
        _;
    }
    
    // Constructor
    constructor() {
        admin = msg.sender;
        authorizedPollers[msg.sender] = true; // Admin can create polls
    }
    
    // Voter registration
    function registerVoter() external {
        require(!registeredVoters[msg.sender], "Already registered");
        registeredVoters[msg.sender] = true;
        emit VoterRegistered(msg.sender);
    }
    
    // Admin function to authorize poll creators
    function authorizePoller(address _poller) external onlyAdmin {
        require(!authorizedPollers[_poller], "Already authorized");
        authorizedPollers[_poller] = true;
        emit PollerAuthorized(_poller);
    }
    
    // Create a new poll
    function createPoll(
        string memory _title,
        string memory _description,
        string[] memory _options,
        uint256 _durationInMinutes
    ) external onlyAuthorizedPoller {
        require(_options.length >= 2, "Poll must have at least 2 options");
        require(_options.length <= 10, "Poll cannot have more than 10 options");
        require(_durationInMinutes > 0, "Duration must be greater than 0");
        
        uint256 pollId = pollCount;
        Poll storage newPoll = polls[pollId];
        
        newPoll.id = pollId;
        newPoll.title = _title;
        newPoll.description = _description;
        newPoll.options = _options;
        newPoll.votes = new uint256[](_options.length);
        newPoll.startTime = block.timestamp;
        newPoll.endTime = block.timestamp + (_durationInMinutes * 60);
        newPoll.creator = msg.sender;
        newPoll.isActive = true;
        
        pollCount++;
        
        emit PollCreated(pollId, _title, msg.sender);
    }
    
    // Cast a vote
    function vote(uint256 _pollId, uint256 _optionIndex) 
        external 
        onlyRegisteredVoter 
        validPoll(_pollId) 
        pollActive(_pollId) 
    {
        Poll storage poll = polls[_pollId];
        
        require(!poll.hasVoted[msg.sender], "You have already voted in this poll");
        require(_optionIndex < poll.options.length, "Invalid option index");
        
        poll.hasVoted[msg.sender] = true;
        poll.votes[_optionIndex]++;
        poll.voters.push(msg.sender);
        
        emit VoteCast(_pollId, msg.sender, _optionIndex);
    }
    
    // End a poll manually (only creator or admin)
    function endPoll(uint256 _pollId) external validPoll(_pollId) {
        Poll storage poll = polls[_pollId];
        require(
            msg.sender == poll.creator || msg.sender == admin,
            "Only poll creator or admin can end the poll"
        );
        require(poll.isActive, "Poll is already ended");
        
        poll.isActive = false;
        emit PollEnded(_pollId);
    }
    
    // Get poll information
    function getPollInfo(uint256 _pollId) 
        external 
        view 
        validPoll(_pollId) 
        returns (
            string memory title,
            string memory description,
            string[] memory options,
            uint256[] memory votes,
            uint256 startTime,
            uint256 endTime,
            address creator,
            bool isActive,
            uint256 totalVotes
        ) 
    {
        Poll storage poll = polls[_pollId];
        return (
            poll.title,
            poll.description,
            poll.options,
            poll.votes,
            poll.startTime,
            poll.endTime,
            poll.creator,
            poll.isActive && block.timestamp <= poll.endTime,
            poll.voters.length
        );
    }
    
    // Get poll results
    function getPollResults(uint256 _pollId) 
        external 
        view 
        validPoll(_pollId) 
        returns (
            string[] memory options,
            uint256[] memory votes,
            uint256 totalVotes,
            uint256 winningOption
        ) 
    {
        Poll storage poll = polls[_pollId];
        
        uint256 maxVotes = 0;
        uint256 winningIndex = 0;
        
        for (uint256 i = 0; i < poll.votes.length; i++) {
            if (poll.votes[i] > maxVotes) {
                maxVotes = poll.votes[i];
                winningIndex = i;
            }
        }
        
        return (
            poll.options,
            poll.votes,
            poll.voters.length,
            winningIndex
        );
    }
    
    // Check if user has voted in a specific poll
    function hasUserVoted(uint256 _pollId, address _user) 
        external 
        view 
        validPoll(_pollId) 
        returns (bool) 
    {
        return polls[_pollId].hasVoted[_user];
    }
    
    // Get all active polls
    function getActivePolls() external view returns (uint256[] memory) {
        uint256[] memory activePolls = new uint256[](pollCount);
        uint256 activePollCount = 0;
        
        for (uint256 i = 0; i < pollCount; i++) {
            if (polls[i].isActive && block.timestamp <= polls[i].endTime) {
                activePolls[activePollCount] = i;
                activePollCount++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](activePollCount);
        for (uint256 i = 0; i < activePollCount; i++) {
            result[i] = activePolls[i];
        }
        
        return result;
    }
    
    // Get voter count for a poll
    function getVoterCount(uint256 _pollId) 
        external 
        view 
        validPoll(_pollId) 
        returns (uint256) 
    {
        return polls[_pollId].voters.length;
    }
    
    // Emergency function to transfer admin rights
    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        admin = _newAdmin;
    }
    
    // Check if poll has ended
    function isPollEnded(uint256 _pollId) external view validPoll(_pollId) returns (bool) {
        return !polls[_pollId].isActive || block.timestamp > polls[_pollId].endTime;
    }
}
