// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // Task status enumeration
    enum TaskStatus { Created, InProgress, Completed, Cancelled }
    
    // Task structure
    struct Task {
        uint256 id;
        string title;
        string description;
        address creator;
        address assignee;
        uint256 reward;
        TaskStatus status;
        uint256 createdAt;
        uint256 completedAt;
    }
    
    // State variables
    uint256 private taskCounter;
    mapping(uint256 => Task) public tasks;
    mapping(address => uint256[]) public userCreatedTasks;
    mapping(address => uint256[]) public userAssignedTasks;
    mapping(address => uint256) public userReputation;
    
    // Events
    event TaskCreated(uint256 indexed taskId, address indexed creator, string title, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed assignee);
    event TaskCompleted(uint256 indexed taskId, address indexed assignee, uint256 reward);
    event TaskCancelled(uint256 indexed taskId, address indexed creator);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    
    // Modifiers
    modifier onlyTaskCreator(uint256 _taskId) {
        require(tasks[_taskId].creator == msg.sender, "Only task creator can perform this action");
        _;
    }
    
    modifier onlyAssignee(uint256 _taskId) {
        require(tasks[_taskId].assignee == msg.sender, "Only assigned user can perform this action");
        _;
    }
    
    modifier taskExists(uint256 _taskId) {
        require(_taskId > 0 && _taskId <= taskCounter, "Task does not exist");
        _;
    }
    
    // Core Function 1: Create Task
    function createTask(
        string memory _title,
        string memory _description
    ) external payable returns (uint256) {
        require(bytes(_title).length > 0, "Task title cannot be empty");
        require(bytes(_description).length > 0, "Task description cannot be empty");
        require(msg.value > 0, "Task reward must be greater than 0");
        
        taskCounter++;
        
        tasks[taskCounter] = Task({
            id: taskCounter,
            title: _title,
            description: _description,
            creator: msg.sender,
            assignee: address(0),
            reward: msg.value,
            status: TaskStatus.Created,
            createdAt: block.timestamp,
            completedAt: 0
        });
        
        userCreatedTasks[msg.sender].push(taskCounter);
        
        emit TaskCreated(taskCounter, msg.sender, _title, msg.value);
        
        return taskCounter;
    }
    
    // Core Function 2: Assign Task
    function assignTask(uint256 _taskId, address _assignee) 
        external 
        taskExists(_taskId) 
        onlyTaskCreator(_taskId) 
    {
        require(_assignee != address(0), "Invalid assignee address");
        require(tasks[_taskId].status == TaskStatus.Created, "Task is not available for assignment");
        require(_assignee != tasks[_taskId].creator, "Creator cannot assign task to themselves");
        
        tasks[_taskId].assignee = _assignee;
        tasks[_taskId].status = TaskStatus.InProgress;
        
        userAssignedTasks[_assignee].push(_taskId);
        
        emit TaskAssigned(_taskId, _assignee);
    }
    
    // Core Function 3: Complete Task and Update Reputation
    function completeTask(uint256 _taskId) 
        external 
        taskExists(_taskId) 
        onlyAssignee(_taskId) 
    {
        require(tasks[_taskId].status == TaskStatus.InProgress, "Task is not in progress");
        
        Task storage task = tasks[_taskId];
        task.status = TaskStatus.Completed;
        task.completedAt = block.timestamp;
        
        uint256 reward = task.reward;
        
        // Update assignee reputation
        userReputation[task.assignee] += 10; // +10 points for completing a task
        
        // Transfer reward to assignee
        (bool success, ) = payable(task.assignee).call{value: reward}("");
        require(success, "Reward transfer failed");
        
        emit TaskCompleted(_taskId, task.assignee, reward);
        emit ReputationUpdated(task.assignee, userReputation[task.assignee]);
    }
    
    // Additional utility functions
    function cancelTask(uint256 _taskId) 
        external 
        taskExists(_taskId) 
        onlyTaskCreator(_taskId) 
    {
        require(
            tasks[_taskId].status == TaskStatus.Created || 
            tasks[_taskId].status == TaskStatus.InProgress, 
            "Cannot cancel completed or cancelled task"
        );
        
        Task storage task = tasks[_taskId];
        task.status = TaskStatus.Cancelled;
        
        // If task was assigned, decrease assignee reputation
        if (task.assignee != address(0)) {
            if (userReputation[task.assignee] >= 5) {
                userReputation[task.assignee] -= 5; // -5 points for incomplete task
            }
            emit ReputationUpdated(task.assignee, userReputation[task.assignee]);
        }
        
        // Refund reward to creator
        (bool success, ) = payable(task.creator).call{value: task.reward}("");
        require(success, "Refund transfer failed");
        
        emit TaskCancelled(_taskId, task.creator);
    }
    
    // View functions
    function getTask(uint256 _taskId) 
        external 
        view 
        taskExists(_taskId) 
        returns (Task memory) 
    {
        return tasks[_taskId];
    }
    
    function getUserCreatedTasks(address _user) external view returns (uint256[] memory) {
        return userCreatedTasks[_user];
    }
    
    function getUserAssignedTasks(address _user) external view returns (uint256[] memory) {
        return userAssignedTasks[_user];
    }
    
    function getUserReputation(address _user) external view returns (uint256) {
        return userReputation[_user];
    }
    
    function getTotalTasks() external view returns (uint256) {
        return taskCounter;
    }
    
    function getAvailableTasks() external view returns (uint256[] memory) {
        uint256[] memory availableTasks = new uint256[](taskCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= taskCounter; i++) {
            if (tasks[i].status == TaskStatus.Created) {
                availableTasks[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = availableTasks[i];
        }
        
        return result;
    }
}
