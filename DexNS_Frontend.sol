pragma solidity ^0.4.15;

import './DexNS_Storage.sol';
import './safeMath.sol';
import './strings.sol';

 /*
 * The following is an implementation of the Naming Service that aims to boost
 * the usability of smart-contracts and provide a human-friendly utility
 * to work with low-level smart-contract interactions.
 * 
 * In addition it can be used as a central controlling unit of the system
 * with dynamically linked smart-contracts.
 * 
 * Current implementation aims to simplify searches by contract names
 * and automated loading of ABIs for smart-contracts. 
 * This can be used to provide an automated token adding
 * to the web wallet interfaces like ClassicEtherWallet as well.
 *
 *  Designed by Dexaran, dexaran820@gmail.com
 * 
 */
 
 contract DexNS_Abstract_Interface {
     function name(string)    constant returns (bytes32);
     function getName(string) constant returns (address _owner, address _associated, string _value, uint _end, bytes32 _sig);
     
     function ownerOf(string)   constant returns (address);
     function addressOf(string) constant returns (address);
     function valueOf(string)   constant returns (string);
     function endtimeOf(string) constant returns (uint);
     function updateName(string, string);
     function updateName(string, address);
     function updateName(string, address, string);
     function registerName(string) payable returns (bool);
     function registerAndUpdateName(string, address, address, string, bool) payable returns (bool);
     function changeNameOwner(string, address);
     function hideNameOwner(string);
     function extendNameBindingTime(string) payable;
     function appendNameMetadata(string, string);
 }
 
 
/** contract Test
 *  {
 *   address constant_name_service;
 *   function() payable
 *   {
 *        DexNS_Storage dexns = DexNS_Storage(constant_name_service);
 *        dexns.addressOf("Recipient name").send(msg.value);
 *   }
 *}
 */
 
 contract DexNS_Frontend is safeMath
 {
    using strings for *;
    
    event Error(bytes32);
    event NamePriceChanged(uint indexed _price);
    event OwningTimeChanged(uint indexed _period);
    event DebugDisabled();
    event NameRegistered(string _name, address indexed _owner);
    event NameUpdated(bytes32 indexed _signature);
    event Assignment(address indexed _owner, string _name);
    event Unassignment(address indexed _owner, string _name);
    
    DexNS_Storage public db;
    
    modifier only_owner
    {
        if ( msg.sender != owner )
            revert();
        _;
    }
    
    modifier only_name_owner(string _name)
    {
        if ( msg.sender != db.ownerOf(_name) )
            revert();
        _;
    }
    
    modifier only_debug
    {
        if ( !debug )
            revert();
        _;
    }
    
    address public owner;
    bool public debug      = true;
    uint public owningTime = 31536000; //1 year in seconds
    uint public namePrice  = 0;
    
    mapping (bytes32 => uint256) public expirations;
    
    function DexNS_Frontend()
    {
        owner             = msg.sender;
        db                = DexNS_Storage(0x429611c633806a03447391026a538a022e1e2731);
        bytes32     _sig  = sha256("DexNS commission");
        expirations[_sig] = 99999999999999999999;
    }
    
    
    
    function name(string _name) constant returns (bytes32 hash)
    {
        return bytes32(sha256(_name));
    }
    
    function registerAndUpdateName(string _name, address _owner, address _destination, string _metadata, bool _hideOwner) payable returns (bool ok)
    {
        if(!(msg.value < namePrice))
        {
            bytes32 _sig = sha256(_name);
            if(expirations[_sig] < now)
            {
                db.registerAndUpdateName(_name, _owner, _destination, _metadata, _hideOwner);
                expirations[_sig] = safeAdd(now, owningTime);
                if (db.addressOf("DexNS commission").send(namePrice))
                {
                    if(safeSub(msg.value, namePrice ) > 0)
                    {
                        msg.sender.transfer(msg.value - namePrice);
                    }
                    NameRegistered(_name, _owner);
                    return true;
                }
            }
        }
        revert();
    }
    
    function registerName(string _name) payable returns (bool ok)
    {
        if(!(msg.value < namePrice))
        {
            bytes32 _sig = sha256(_name);
            if(expirations[_sig] < now)
            {
                db.registerName(msg.sender, _name);
                expirations[_sig] = safeAdd(now, owningTime);
                if (db.addressOf("DexNS commission").send(namePrice))
                {
                    if(safeSub(msg.value, namePrice ) > 0)
                    {
                        msg.sender.transfer(msg.value - namePrice);
                    }
                    NameRegistered(_name, msg.sender);
                    return true;
                }
            }
        }
        revert();
    }
    
    function endtimeOf(string _name) constant returns (uint _expires)
    {
        return expirations[sha256(_name)];
    }
    
    function updateName(string _name, address _addr, string _value) only_name_owner(_name)
    {
        db.updateName(_name, _addr, _value);
        NameUpdated(db.signatureOf(_name));
    }
    
    function updateName(string _name, string _value) only_name_owner(_name)
    {
        db.updateName(_name, _value);
        NameUpdated(db.signatureOf(_name));
    }
    
    function updateName(string _name, address _addr) only_name_owner(_name)
    {
        db.updateName(_name, _addr);
        NameUpdated(db.signatureOf(_name));
    }
    
    function appendNameMetadata(string _name, string _value) only_name_owner(_name)
    {
        db.appendNameMetadata(_name, _value);
        NameUpdated(db.signatureOf(_name));
    }
    
    function changeNameOwner(string _name, address _newOwner) only_name_owner(_name)
    {
        db.changeNameOwner(_name, _newOwner);
        NameUpdated(db.signatureOf(_name));
    }
    
    function hideNameOwner(string _name, bool _hide) only_name_owner(_name)
    {
        db.hideNameOwner(_name, _hide);
        NameUpdated(db.signatureOf(_name));
    }
    
    function assignName(string _name) only_name_owner(_name)
    {
        db.assignName(_name);
        Assignment(msg.sender, _name);
    }
    
    function unassignName(string _name) only_name_owner(_name)
    {
        db.unassignName(_name);
        Unassignment(msg.sender, _name);
    }
    
    struct slice
    {
        uint _len;
        uint _ptr;
    }
    
    function toSlice(string self) private returns (slice)
    {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }
    
    function memcpy(uint dest, uint src, uint len) private
    {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
    
    function concat(slice self, slice other) private returns (string)
    {
        var ret = new string(self._len + other._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }
    
    function toString(slice self) internal returns (string)
    {
        var ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }
    
    function StringAppend(string _str1, string _str2) private constant returns (string)
    {
        return concat(toSlice(_str1), toSlice(_str2));
    }
    
    function extend_Name_Binding_Time(string _name) payable
    {
        if(msg.value >= namePrice)
        {
           if(db.addressOf("DexNS commission").send(msg.value))
           {
               expirations[sha256(_name)] = safeAdd(now, owningTime);
           }
        }
    }
    
    
    function change_Storage_Address(address _newStorage) only_owner
    {
        db = DexNS_Storage(_newStorage);
    }
    
    function change_Owner(address _newOwner) only_owner
    {
        owner=_newOwner;
    }
    
    function disable_Debug() only_owner only_debug
    {
        debug = false;
        DebugDisabled();
    }
    
    function set_Owning_Time(uint _newOwningTime) only_owner only_debug
    {
        owningTime = _newOwningTime;
        OwningTimeChanged(_newOwningTime);
    }
    
    function change_Name_Price(uint _newNamePrice) only_owner only_debug
    {
        namePrice = _newNamePrice;
        NamePriceChanged(_newNamePrice);
    }
    
    function dispose() only_owner only_debug
    {
        selfdestruct(owner);
    }
    
    function delegateCall(address _target, uint _gas, bytes _data) payable only_owner only_debug
    {
        if(!_target.call.value(_gas)(_data))
        {
            Error(0);
        }
    }
}
