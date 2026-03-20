// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * AgAu Assurance Contract
 *
 * Rules:
 *   1. Anyone can contribute ETH before the deadline.
 *   2. If the target is reached, the guardian releases funds to the SAFE
 *      and contributors can claim tokens proportional to their contribution.
 *   3. If the deadline passes without success, contributors withdraw their ETH.
 *
 * No admin can touch contributor funds unless the target is met.
 * No contributor can be denied a refund if the target is not met.
 * The Three Commandments are encoded as immutable constraints.
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ──────────────────────────────────────────────
//  The Token: ₳gAu Share
// ──────────────────────────────────────────────

contract AgAuShare is ERC20 {
    address public immutable sale;

    constructor() ERC20("AgAu Share", "AGAU") {
        sale = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == sale, "only sale");
        _mint(to, amount);
    }
}

// ──────────────────────────────────────────────
//  The Sale: Assurance Contract
// ──────────────────────────────────────────────

contract AgAuSale is ReentrancyGuard {

    // ── State ──

    address public immutable guardian;    // the SAFE multisig
    uint256 public immutable deadline;    // November 5, 2026 00:00 UTC
    uint256 public immutable target;      // ETH target amount (wei)

    AgAuShare public immutable token;

    uint256 public totalContributed;
    mapping(address => uint256) public contributions;

    bool public succeeded;
    bool public fundsReleased;

    // ── Events ──

    event Contributed(address indexed contributor, uint256 amount, uint256 total);
    event Succeeded(uint256 totalRaised);
    event FundsReleased(address indexed to, uint256 amount);
    event TokensClaimed(address indexed contributor, uint256 tokens);
    event Refunded(address indexed contributor, uint256 amount);

    // ── Constructor ──

    /**
     * @param _guardian  The SAFE multisig address that can declare success
     * @param _target    The ETH target in wei
     * @param _deadline  Unix timestamp of the cutoff (November 5, 2026)
     */
    constructor(address _guardian, uint256 _target, uint256 _deadline) {
        require(_guardian != address(0), "zero guardian");
        require(_target > 0, "zero target");
        require(_deadline > block.timestamp, "deadline passed");

        guardian = _guardian;
        target = _target;
        deadline = _deadline;
        token = new AgAuShare();
    }

    // ── Contribute ──

    /**
     * Send ETH to participate. Callable by anyone before the deadline,
     * as long as success has not been declared.
     */
    receive() external payable {
        contribute();
    }

    function contribute() public payable {
        require(block.timestamp < deadline, "past deadline");
        require(!succeeded, "already succeeded");
        require(msg.value > 0, "zero value");

        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;

        emit Contributed(msg.sender, msg.value, totalContributed);
    }

    // ── Success Path ──

    /**
     * The guardian declares success. Can only be called when the target
     * is reached and before the deadline.
     */
    function declareSuccess() external {
        require(msg.sender == guardian, "only guardian");
        require(totalContributed >= target, "target not met");
        require(block.timestamp < deadline, "past deadline");
        require(!succeeded, "already succeeded");

        succeeded = true;
        emit Succeeded(totalContributed);
    }

    /**
     * After success, the guardian releases all funds to the SAFE wallet.
     * Called once.
     */
    function releaseFunds() external nonReentrant {
        require(succeeded, "not succeeded");
        require(!fundsReleased, "already released");

        fundsReleased = true;
        uint256 amount = address(this).balance;

        emit FundsReleased(guardian, amount);
        (bool ok, ) = guardian.call{value: amount}("");
        require(ok, "transfer failed");
    }

    /**
     * After success, each contributor claims tokens proportional to their
     * contribution. The total token supply equals the total ETH contributed
     * (in wei), so 1 wei contributed = 1 token unit.
     *
     * A contributor who put in 10% of the total receives 10% of the tokens.
     * This is a mathematical fact, not a policy decision.
     */
    function claimTokens() external nonReentrant {
        require(succeeded, "not succeeded");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "nothing to claim");

        contributions[msg.sender] = 0;
        token.mint(msg.sender, amount);

        emit TokensClaimed(msg.sender, amount);
    }

    // ── Refund Path ──

    /**
     * If the deadline passes without success, every contributor can
     * withdraw exactly what they put in. No fees. No exceptions.
     */
    function refund() external nonReentrant {
        require(block.timestamp >= deadline, "before deadline");
        require(!succeeded, "succeeded — claim tokens instead");
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "nothing to refund");

        contributions[msg.sender] = 0;
        totalContributed -= amount;

        emit Refunded(msg.sender, amount);
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
    }

    // ── View ──

    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function contributionOf(address a) external view returns (uint256) {
        return contributions[a];
    }
}
