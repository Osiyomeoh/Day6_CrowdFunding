// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Project {
        address creator;
        uint256 goal;
        uint256 pledged;
        uint256 deadline;
        bool funded;
    }

    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public pledges;
    uint256 public projectCount;

    event ProjectCreated(uint256 projectId, address creator, uint256 goal, uint256 deadline);
    event PledgeMade(uint256 projectId, address backer, uint256 amount);
    event ProjectFunded(uint256 projectId, uint256 totalAmount);
    event RefundIssued(uint256 projectId, address backer, uint256 amount);

    function createProject(uint256 _goal, uint256 _durationInDays) external {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");

        uint256 projectId = projectCount++;
        projects[projectId] = Project({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            deadline: block.timestamp + (_durationInDays * 1 days),
            funded: false
        });

        emit ProjectCreated(projectId, msg.sender, _goal, projects[projectId].deadline);
    }

    function pledgeFunds(uint256 _projectId) external payable {
        Project storage project = projects[_projectId];
        require(block.timestamp < project.deadline, "Project funding period has ended");
        require(!project.funded, "Project has already been funded");

        pledges[_projectId][msg.sender] += msg.value;
        project.pledged += msg.value;

        emit PledgeMade(_projectId, msg.sender, msg.value);

        if (project.pledged >= project.goal) {
            project.funded = true;
            emit ProjectFunded(_projectId, project.pledged);
        }
    }

    function withdrawFunds(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only the project creator can withdraw funds");
        require(project.funded, "Project has not been fully funded yet");
        require(project.pledged > 0, "No funds to withdraw");

        uint256 amountToWithdraw = project.pledged;
        project.pledged = 0;

        (bool success, ) = payable(project.creator).call{value: amountToWithdraw}("");
        require(success, "Transfer failed");
    }

    function refund(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        require(block.timestamp >= project.deadline, "Project funding period has not ended");
        require(!project.funded, "Project has been funded, cannot refund");

        uint256 pledgedAmount = pledges[_projectId][msg.sender];
        require(pledgedAmount > 0, "No funds to refund");

        pledges[_projectId][msg.sender] = 0;
        project.pledged -= pledgedAmount;

        (bool success, ) = payable(msg.sender).call{value: pledgedAmount}("");
        require(success, "Transfer failed");

        emit RefundIssued(_projectId, msg.sender, pledgedAmount);
    }

    function getProjectDetails(uint256 _projectId) external view returns (
        address creator,
        uint256 goal,
        uint256 pledged,
        uint256 deadline,
        bool funded
    ) {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.goal,
            project.pledged,
            project.deadline,
            project.funded
        );
    }
}