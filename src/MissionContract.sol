pragma solidity ^0.8.0;

contract MissionContract {
    address public admin;

    struct Organization {
        string name;
        string description;
        address wallet;
        bool exists;
    }

    struct Mission {
        uint id;
        string description;
        address organization;
    }

    struct Completion {
        address user;
        uint missionId;
        uint timestamp;
        address organization;
    }

    mapping(address => Organization) public organizations;
    uint public missionCount;
    mapping(uint => Mission) public missions;
    Completion[] public completions;
    address[] public organizationList;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function addOrganization(address wallet, string memory name, string memory description) public onlyAdmin {
        require(!organizations[wallet].exists, "Organization already exists");
        organizations[wallet] = Organization(name, description, wallet, true);
        organizationList.push(wallet);
    }

    function addMission(string memory description, address organization) public {
        require(organizations[organization].exists, "Organization does not exist");
        require(msg.sender == admin || msg.sender == organization, "Not authorized");
        missionCount++;
        missions[missionCount] = Mission(missionCount, description, organization);
    }

    function completeMission(uint missionId, address user, uint timestamp) public {
        require(missions[missionId].id != 0, "Mission does not exist");
        address org = missions[missionId].organization;
        require(msg.sender == admin || msg.sender == org, "Not authorized");
        completions.push(Completion(user, missionId, timestamp, org));
    }

    // View functions

    function getOrganization(address wallet) public view returns (string memory name, string memory description, address walletAddr) {
        require(organizations[wallet].exists, "Organization does not exist");
        Organization memory org = organizations[wallet];
        return (org.name, org.description, org.wallet);
    }

    function getMission(uint id) public view returns (uint missionId, string memory description, address organization) {
        require(missions[id].id != 0, "Mission does not exist");
        Mission memory mission = missions[id];
        return (mission.id, mission.description, mission.organization);
    }

    function getCompletionCount() public view returns (uint) {
        return completions.length;
    }

    function getCompletion(uint index) public view returns (address user, uint missionId, uint timestamp, address organization) {
        require(index < completions.length, "Index out of bounds");
        Completion memory completion = completions[index];
        return (completion.user, completion.missionId, completion.timestamp, completion.organization);
    }

    function getOrganizationCount() public view returns (uint) {
        return organizationList.length;
    }

    function getOrganizationByIndex(uint index) public view returns (address wallet) {
        require(index < organizationList.length, "Index out of bounds");
        return organizationList[index];
    }
}