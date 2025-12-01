pragma solidity >=0.8.0;
import {FixedPointMathLib} from "./FixedPointMathLib.sol";
library LibERB {
    struct ERBValue {
        uint224 value;
        uint32 updateNumber;
    }
    function grow(
        ERBValue[65535] storage self,
        uint16 growBy,
        uint16 availableSlots
    ) internal returns (uint16 newTotalAvailableSlots) {
        newTotalAvailableSlots = availableSlots + growBy;
        unchecked {
            for (uint256 i = availableSlots; i < newTotalAvailableSlots; i++)
                self[i].updateNumber = type(uint32).max;
        }
    }
    function write(
        ERBValue[65535] storage self,
        uint224 value,
        uint32 totalUpdates,
        uint16 populatedSlots,
        uint16 availableSlots 
    ) internal returns (uint32 newTotalUpdates, uint16 newPopulatedSlots) {
        unchecked {
            newPopulatedSlots = populatedSlots == 0 ||
                (totalUpdates % populatedSlots == (populatedSlots - 1) && populatedSlots < availableSlots)
                ? populatedSlots + 1
                : populatedSlots;
            newTotalUpdates = totalUpdates + 1; 
            self[totalUpdates % newPopulatedSlots] = ERBValue({value: value, updateNumber: newTotalUpdates});
        }
    }
    function read(
        ERBValue[65535] storage self,
        uint32 totalUpdates,
        uint16 populatedSlots
    ) internal view returns (ERBValue memory) {
        return self[FixedPointMathLib.unsafeMod(totalUpdates, populatedSlots)];
    }
    function readOffset(
        ERBValue[65535] storage self,
        uint32 offset,
        uint32 totalUpdates,
        uint16 populatedSlots
    ) internal view returns (ERBValue memory) {
        unchecked {
            require(offset <= populatedSlots, "OUT_OF_BOUNDS");
            return self[FixedPointMathLib.unsafeMod(totalUpdates - offset, populatedSlots)];
        }
    }
    function readUpdateNumber(
        ERBValue[65535] storage self,
        uint32 updateNumber,
        uint32 totalUpdates,
        uint16 populatedSlots
    ) internal view returns (ERBValue memory) {
        require(totalUpdates - updateNumber <= populatedSlots, "OUT_OF_BOUNDS");
        return self[FixedPointMathLib.unsafeMod(updateNumber, populatedSlots)];
    }
}
library LibBoxedERB {
    struct BoxedERB {
        uint32 totalUpdates;
        uint16 populatedSlots;
        uint16 availableSlots;
        LibERB.ERBValue[65535] erb;
    }
    using LibERB for LibERB.ERBValue[65535];
    function init(BoxedERB storage self) internal {
        self.availableSlots = 1;
        self.erb[0].updateNumber = type(uint32).max;
    }
    function grow(BoxedERB storage self, uint16 growBy) internal {
        self.availableSlots = self.erb.grow(growBy, self.availableSlots);
    }
    function write(BoxedERB storage self, uint224 value) internal {
        (self.totalUpdates, self.populatedSlots) = self.erb.write(
            value,
            self.totalUpdates,
            self.populatedSlots,
            self.availableSlots
        );
    }
    function read(BoxedERB storage self) internal view returns (LibERB.ERBValue memory) {
        return self.erb.read(self.totalUpdates, self.populatedSlots);
    }
    function readOffset(BoxedERB storage self, uint32 offset) internal view returns (LibERB.ERBValue memory) {
        return self.erb.readOffset(offset, self.totalUpdates, self.populatedSlots);
    }
    function readUpdateNumber(BoxedERB storage self, uint32 updateNumber)
        internal
        view
        returns (LibERB.ERBValue memory)
    {
        return self.erb.readUpdateNumber(updateNumber, self.totalUpdates, self.populatedSlots);
    }
}