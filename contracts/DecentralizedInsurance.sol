// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DecentralizedInsurance
 * @dev Implements a decentralized insurance platform with pool management and claim processing
 */
contract DecentralizedInsurance is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CLAIM_ASSESSOR_ROLE = keccak256("CLAIM_ASSESSOR_ROLE");

    error UnauthorizedAccess();
    error InvalidPoolParameters();
    error InvalidClaimParameters();
    error InsufficientFunds();
    error PoolNotActive();
    error AlreadyMember();
    error NotPoolMember();
    error ExceedsCoverageLimit();
    error InvalidClaimId();
    error ClaimAlreadyFinalized();
    error AlreadyVoted();
    error ClaimNotApproved();

    struct InsurancePool {
        string name;
        uint256 totalFunds;
        uint256 minimumContribution;
        uint256 coverageLimit;
        uint256 memberCount;
        bool active;
        mapping(address => uint256) contributions;
        mapping(address => bool) isMember;
    }

    struct Policy {
        uint256 id;
        uint256 poolId;
        uint256 premiumPaid;
        uint256 timestamp;
        bool isActive;
    }

    struct Claim {
        address claimant;
        uint256 poolId;
        uint256 amount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
        uint256 approvalCount;
        uint256 rejectionCount;
        uint256 totalVotes;
        mapping(address => bool) assessorVotes;
    }

    enum ClaimStatus { Pending, Approved, Rejected, Paid }

    mapping(uint256 => InsurancePool) public insurancePools;
    mapping(uint256 => Claim) public claims;
    mapping(address => Policy[]) public userPolicies;
    mapping(address => uint256[]) private userClaimIds;
    uint256 public poolCount;
    uint256 public claimCount;
    uint256 public minAssessorVotes;

    address[] public assessors;
    mapping(address => bool) public isAssessor;

    event PoolCreated(uint256 indexed poolId, string name, uint256 minimumContribution);
    event MemberJoined(uint256 indexed poolId, address indexed member, uint256 contribution);
    event ClaimSubmitted(uint256 indexed claimId, address indexed claimant, uint256 indexed poolId);
    event ClaimAssessed(uint256 indexed claimId, address indexed assessor, bool approved);
    event ClaimFinalized(uint256 indexed claimId, ClaimStatus status);
    event FundsPaid(uint256 indexed claimId, address indexed recipient, uint256 amount);
    event AssessorAdded(address indexed assessor);
    event AssessorRemoved(address indexed assessor);
    event PolicyCreated(address indexed user, uint256 poolId, uint256 premium);

    modifier onlyPoolMember(uint256 _poolId) {
        if (!insurancePools[_poolId].isMember[msg.sender]) revert NotPoolMember();
        _;
    }

    modifier activePool(uint256 _poolId) {
        if (!insurancePools[_poolId].active) revert PoolNotActive();
        _;
    }

    modifier validClaimAmount(uint256 _poolId, uint256 _amount) {
        InsurancePool storage pool = insurancePools[_poolId];
        if (_amount > pool.coverageLimit) revert ExceedsCoverageLimit();
        if (_amount > pool.totalFunds) revert InsufficientFunds();
        _;
    }

    modifier validClaimId(uint256 _claimId) {
        if (_claimId >= claimCount) revert InvalidClaimId();
        _;
    }

    modifier claimNotFinalized(uint256 _claimId) {
        ClaimStatus status = claims[_claimId].status;
        if (status == ClaimStatus.Approved || status == ClaimStatus.Rejected || status == ClaimStatus.Paid) {
            revert ClaimAlreadyFinalized();
        }
        _;
    }

    modifier canJoinPool(uint256 _poolId) {
        InsurancePool storage pool = insurancePools[_poolId];
        if (!pool.active) revert PoolNotActive();
        if (pool.isMember[msg.sender]) revert AlreadyMember();
        if (msg.value < pool.minimumContribution) revert InsufficientFunds();
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(CLAIM_ASSESSOR_ROLE, msg.sender);
        assessors.push(msg.sender);
        isAssessor[msg.sender] = true;
        minAssessorVotes = 1;
    }

    function createPool(string memory _name, uint256 _minimumContribution, uint256 _coverageLimit) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        if (_minimumContribution == 0 || _coverageLimit == 0) revert InvalidPoolParameters();

        uint256 poolId = poolCount++;
        InsurancePool storage pool = insurancePools[poolId];
        pool.name = _name;
        pool.minimumContribution = _minimumContribution;
        pool.coverageLimit = _coverageLimit;
        pool.active = true;

        emit PoolCreated(poolId, _name, _minimumContribution);
    }

    function joinPool(uint256 _poolId) external payable nonReentrant whenNotPaused canJoinPool(_poolId) {
        InsurancePool storage pool = insurancePools[_poolId];

        pool.contributions[msg.sender] = msg.value;
        pool.totalFunds += msg.value;
        pool.memberCount++;
        pool.isMember[msg.sender] = true;

        userPolicies[msg.sender].push(
            Policy({
                id: userPolicies[msg.sender].length,
                poolId: _poolId,
                premiumPaid: msg.value,
                timestamp: block.timestamp,
                isActive: true
            })
        );

        emit MemberJoined(_poolId, msg.sender, msg.value);
        emit PolicyCreated(msg.sender, _poolId, msg.value);
    }

    function submitClaim(uint256 _poolId, uint256 _amount, string memory _description)
        external nonReentrant whenNotPaused onlyPoolMember(_poolId) activePool(_poolId) validClaimAmount(_poolId, _amount)
    {
        if (bytes(_description).length == 0) revert InvalidClaimParameters();

        uint256 claimId = claimCount++;
        Claim storage claim = claims[claimId];
        claim.claimant = msg.sender;
        claim.poolId = _poolId;
        claim.amount = _amount;
        claim.description = _description;
        claim.timestamp = block.timestamp;
        claim.status = ClaimStatus.Pending;

        userClaimIds[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, msg.sender, _poolId);
    }

    function assessClaim(uint256 _claimId, bool _approve) external nonReentrant whenNotPaused validClaimId(_claimId) claimNotFinalized(_claimId) {
        if (!hasRole(CLAIM_ASSESSOR_ROLE, msg.sender)) revert UnauthorizedAccess();

        Claim storage claim = claims[_claimId];
        if (claim.assessorVotes[msg.sender]) revert AlreadyVoted();

        claim.assessorVotes[msg.sender] = true;
        claim.totalVotes++;
        if (_approve) claim.approvalCount++;
        else claim.rejectionCount++;

        emit ClaimAssessed(_claimId, msg.sender, _approve);
        _checkAndFinalizeClaim(_claimId);
    }

    function _checkAndFinalizeClaim(uint256 _claimId) internal {
        Claim storage claim = claims[_claimId];
        if (claim.totalVotes >= minAssessorVotes) {
            if (claim.approvalCount > claim.rejectionCount) {
                claim.status = ClaimStatus.Approved;
                emit ClaimFinalized(_claimId, ClaimStatus.Approved);
            } else {
                claim.status = ClaimStatus.Rejected;
                emit ClaimFinalized(_claimId, ClaimStatus.Rejected);
            }
        }
    }

    function payClaim(uint256 _claimId) external nonReentrant whenNotPaused validClaimId(_claimId) {
        Claim storage claim = claims[_claimId];
        if (claim.status != ClaimStatus.Approved) revert ClaimNotApproved();

        InsurancePool storage pool = insurancePools[claim.poolId];
        if (pool.totalFunds < claim.amount) revert InsufficientFunds();

        pool.totalFunds -= claim.amount;
        claim.status = ClaimStatus.Paid;

        (bool success, ) = payable(claim.claimant).call{value: claim.amount}("");
        require(success, "Transfer failed");

        emit FundsPaid(_claimId, claim.claimant, claim.amount);
        emit ClaimFinalized(_claimId, ClaimStatus.Paid);
    }

    function addAssessor(address _assessor) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        if (!isAssessor[_assessor]) {
            _grantRole(CLAIM_ASSESSOR_ROLE, _assessor);
            assessors.push(_assessor);
            isAssessor[_assessor] = true;
            emit AssessorAdded(_assessor);
        }
    }

    function removeAssessor(address _assessor) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        if (isAssessor[_assessor]) {
            _revokeRole(CLAIM_ASSESSOR_ROLE, _assessor);
            isAssessor[_assessor] = false;
            for (uint256 i = 0; i < assessors.length; i++) {
                if (assessors[i] == _assessor) {
                    assessors[i] = assessors[assessors.length - 1];
                    assessors.pop();
                    break;
                }
            }
            emit AssessorRemoved(_assessor);
        }
    }

    function getAssessorCount() external view returns (uint256) {
        return assessors.length;
    }

    function setMinAssessorVotes(uint256 _minVotes) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        require(_minVotes > 0, "Min votes must be positive");
        minAssessorVotes = _minVotes;
    }

    function pause() external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        _pause();
    }

    function unpause() external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        _unpause();
    }

    function getClaimDetails(uint256 _claimId) external view validClaimId(_claimId) returns (
        address, uint256, uint256, string memory, uint256, ClaimStatus, uint256, uint256, uint256
    ) {
        Claim storage claim = claims[_claimId];
        return (
            claim.claimant,
            claim.poolId,
            claim.amount,
            claim.description,
            claim.timestamp,
            claim.status,
            claim.approvalCount,
            claim.rejectionCount,
            claim.totalVotes
        );
    }

    function getPoolDetails(uint256 _poolId) external view returns (
        string memory, uint256, uint256, uint256, uint256, bool
    ) {
        InsurancePool storage pool = insurancePools[_poolId];
        return (
            pool.name,
            pool.totalFunds,
            pool.minimumContribution,
            pool.coverageLimit,
            pool.memberCount,
            pool.active
        );
    }

    function isPoolMember(uint256 _poolId, address _member) external view returns (bool) {
        return insurancePools[_poolId].isMember[_member];
    }

    function getMemberContribution(uint256 _poolId, address _member) external view returns (uint256) {
        return insurancePools[_poolId].contributions[_member];
    }

    function getPolicyCountForAddress(address _user) public view returns (uint256) {
        return userPolicies[_user].length;
    }

    function hasAssessorVoted(uint256 _claimId, address _assessor) external view validClaimId(_claimId) returns (bool) {
        return claims[_claimId].assessorVotes[_assessor];
    }

    function getPoliciesByUser(address _user) external view returns (Policy[] memory) {
        return userPolicies[_user];
    }

    function renounceRole(bytes32 role, address account) public override {
        require(role != ADMIN_ROLE, "Cannot renounce admin role");
        super.renounceRole(role, account);
    }

    function emergencyWithdraw(uint256 _poolId) external {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert UnauthorizedAccess();
        InsurancePool storage pool = insurancePools[_poolId];
        uint256 amount = pool.totalFunds;
        pool.totalFunds = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Emergency withdrawal failed");
    }

    function getClaimIdsByUser(address user) external view returns (uint256[] memory) {
        return userClaimIds[user];
    }

    receive() external payable {
        revert("Please use joinPool()");
    }
}
