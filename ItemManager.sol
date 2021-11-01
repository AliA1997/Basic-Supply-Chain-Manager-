pragma solidity ^0.8.0;

contract Ownable {
    address _owner;
    
    constructor() public {
        _owner = address(msg.sender);
    }
    
    modifier onlyOwner() {
        require(isOwner(), "You are not the owner");
        _;
    }
    
    function isOwner() public view returns(bool) {
        return (msg.sender == _owner);
    }
}

contract Item {
    uint public priceInWei;
    uint public pricePaid;
    uint public index;
    
    ItemManager parentContract;
    
    constructor(ItemManager _parentContract, uint _priceInWei, uint _index) public {
        priceInWei = _priceInWei;
        index = _index;
        parentContract = _parentContract;
    }
    
    //Create a fallback function that will receive funds with no populated message data.
    receive() external payable {
        require(pricePaid == 0, "Item is paid already");
        require(priceInWei == msg.value, "Only full payments allowed");
        pricePaid += msg.value;
        //The transfer function only can do 23000 gas, but they are cases when more is required such as calling a function in a parentContract
        // address(parentContract).transfer(msg.value)
        //As of version 8(i think) you can set the amount of gas you want to use and value is between curly braces.
        (bool success, ) = address(parentContract).call{value: msg.value, gas: 1000000 }(abi.encodeWithSignature("triggerPayment(uint256)", index));
        require(success, "The transaction wasn't successful.");
    }
    
    fallback() external payable {}
}

contract ItemManager is Ownable {
    enum SupplyChainState{Created, Paid, Delivered}
    
    struct Supply_Chain_Item {
        //Reference item to be payable
        Item _item;
        string _identifier;
        uint _itemPrice;
        ItemManager.SupplyChainState _state;
    }
    
    mapping(uint => Supply_Chain_Item) public items;
    
    uint numberOfItems;
    
    
    event SupplyChainChange(uint indexed _index, ItemManager.SupplyChainState indexed _state, address indexed _itemAddress);
    
    function createItem(string memory _identifier, uint _itemPrice) public onlyOwner {
        Item item = new Item(this, _itemPrice, numberOfItems);
        items[numberOfItems]._item = item;
        items[numberOfItems]._identifier = _identifier;
        items[numberOfItems]._itemPrice = _itemPrice;
        items[numberOfItems]._state = SupplyChainState.Created;
        numberOfItems++;
        emit SupplyChainChange(numberOfItems, items[numberOfItems]._state, address(item));
    }
    
    function triggerPayment(uint _index) public payable onlyOwner {
        require(items[_index]._itemPrice == msg.value, "Can't accept partial payments.");
        require(items[_index]._state == SupplyChainState.Created, "Item is further up the supply chain.");
        
        items[_index]._state = SupplyChainState.Paid;
        emit SupplyChainChange(_index, items[_index]._state, address(items[_index]._item));
    }
    
    function triggerDelivery(uint _index) public onlyOwner {
        require(items[_index]._state == SupplyChainState.Paid, "Item is further up the supply chain.");

        items[_index]._state = SupplyChainState.Delivered;
        emit SupplyChainChange(_index, items[_index]._state, address(items[_index]._item));
    }
}