pragma solidity ^0.8.4;
library DateTimeLib {
    uint256 internal constant MON = 1;
    uint256 internal constant TUE = 2;
    uint256 internal constant WED = 3;
    uint256 internal constant THU = 4;
    uint256 internal constant FRI = 5;
    uint256 internal constant SAT = 6;
    uint256 internal constant SUN = 7;
    uint256 internal constant JAN = 1;
    uint256 internal constant FEB = 2;
    uint256 internal constant MAR = 3;
    uint256 internal constant APR = 4;
    uint256 internal constant MAY = 5;
    uint256 internal constant JUN = 6;
    uint256 internal constant JUL = 7;
    uint256 internal constant AUG = 8;
    uint256 internal constant SEP = 9;
    uint256 internal constant OCT = 10;
    uint256 internal constant NOV = 11;
    uint256 internal constant DEC = 12;
    uint256 internal constant MAX_SUPPORTED_YEAR = 0xffffffff;
    uint256 internal constant MAX_SUPPORTED_EPOCH_DAY = 0x16d3e098039;
    uint256 internal constant MAX_SUPPORTED_TIMESTAMP = 0x1e18549868c76ff;
    function dateToEpochDay(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 epochDay)
    {
        assembly {
            year := sub(year, lt(month, 3))
            let doy := add(shr(11, add(mul(62719, mod(add(month, 9), 12)), 769)), day)
            let yoe := mod(year, 400)
            let doe := sub(add(add(mul(yoe, 365), shr(2, yoe)), doy), div(yoe, 100))
            epochDay := sub(add(mul(div(year, 400), 146097), doe), 719469)
        }
    }
    function epochDayToDate(uint256 epochDay)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe :=
                div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(5, doy), 2), 153)
            day := add(sub(doy, shr(11, add(mul(mp, 62719), 769))), 1)
            month := sub(add(mp, 3), mul(gt(mp, 9), 12))
            year := add(add(yoe, mul(div(epochDay, 146097), 400)), lt(month, 3))
        }
    }
    function dateToTimestamp(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = dateToEpochDay(year, month, day) * 86400;
        }
    }
    function timestampToDate(uint256 timestamp)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        (year, month, day) = epochDayToDate(timestamp / 86400);
    }
    function dateTimeToTimestamp(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (uint256 result) {
        unchecked {
            result = dateToEpochDay(year, month, day) * 86400 + hour * 3600 + minute * 60 + second;
        }
    }
    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 hour,
            uint256 minute,
            uint256 second
        )
    {
        unchecked {
            (year, month, day) = epochDayToDate(timestamp / 86400);
            uint256 secs = timestamp % 86400;
            hour = secs / 3600;
            secs = secs % 3600;
            minute = secs / 60;
            second = secs % 60;
        }
    }
    function isLeapYear(uint256 year) internal pure returns (bool leap) {
        assembly {
            leap := iszero(and(add(mul(iszero(mod(year, 25)), 12), 3), year))
        }
    }
    function daysInMonth(uint256 year, uint256 month) internal pure returns (uint256 result) {
        bool flag = isLeapYear(year);
        assembly {
            result :=
                add(byte(month, shl(152, 0x1F1C1F1E1F1E1F1F1E1F1E1F)), and(eq(month, 2), flag))
        }
    }
    function weekday(uint256 timestamp) internal pure returns (uint256 result) {
        unchecked {
            result = ((timestamp / 86400 + 3) % 7) + 1;
        }
    }
    function isSupportedDate(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (bool result)
    {
        uint256 md = daysInMonth(year, month);
        assembly {
            let w := not(0)
            result :=
                and(
                    lt(sub(year, 1970), sub(MAX_SUPPORTED_YEAR, 1969)),
                    and(lt(add(month, w), 12), lt(add(day, w), md))
                )
        }
    }
    function isSupportedDateTime(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 hour,
        uint256 minute,
        uint256 second
    ) internal pure returns (bool result) {
        if (isSupportedDate(year, month, day)) {
            assembly {
                result := and(lt(hour, 24), and(lt(minute, 60), lt(second, 60)))
            }
        }
    }
    function isSupportedEpochDay(uint256 epochDay) internal pure returns (bool result) {
        unchecked {
            result = epochDay < MAX_SUPPORTED_EPOCH_DAY + 1;
        }
    }
    function isSupportedTimestamp(uint256 timestamp) internal pure returns (bool result) {
        unchecked {
            result = timestamp < MAX_SUPPORTED_TIMESTAMP + 1;
        }
    }
    function nthWeekdayInMonthOfYearTimestamp(uint256 year, uint256 month, uint256 n, uint256 wd)
        internal
        pure
        returns (uint256 result)
    {
        uint256 d = dateToEpochDay(year, month, 1);
        uint256 md = daysInMonth(year, month);
        assembly {
            let diff := sub(wd, add(mod(add(d, 3), 7), 1))
            let date := add(mul(sub(n, 1), 7), add(mul(gt(diff, 6), 7), diff))
            result := mul(mul(86400, add(date, d)), and(lt(date, md), iszero(iszero(n))))
        }
    }
    function mondayTimestamp(uint256 timestamp) internal pure returns (uint256 result) {
        uint256 t = timestamp;
        assembly {
            let day := div(t, 86400)
            result := mul(mul(sub(day, mod(add(day, 3), 7)), 86400), gt(t, 345599))
        }
    }
    function isWeekEnd(uint256 timestamp) internal pure returns (bool result) {
        result = weekday(timestamp) > FRI;
    }
    function addYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        result = _offsetted(year + numYears, month, day, timestamp);
    }
    function addMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        month = _sub(month + numMonths, 1);
        result = _offsetted(year + month / 12, _add(month % 12, 1), day, timestamp);
    }
    function addDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        result = timestamp + numDays * 86400;
    }
    function addHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        result = timestamp + numHours * 3600;
    }
    function addMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp + numMinutes * 60;
    }
    function addSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp + numSeconds;
    }
    function subYears(uint256 timestamp, uint256 numYears) internal pure returns (uint256 result) {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        result = _offsetted(year - numYears, month, day, timestamp);
    }
    function subMonths(uint256 timestamp, uint256 numMonths)
        internal
        pure
        returns (uint256 result)
    {
        (uint256 year, uint256 month, uint256 day) = epochDayToDate(timestamp / 86400);
        uint256 yearMonth = _totalMonths(year, month) - _add(numMonths, 1);
        result = _offsetted(yearMonth / 12, _add(yearMonth % 12, 1), day, timestamp);
    }
    function subDays(uint256 timestamp, uint256 numDays) internal pure returns (uint256 result) {
        result = timestamp - numDays * 86400;
    }
    function subHours(uint256 timestamp, uint256 numHours) internal pure returns (uint256 result) {
        result = timestamp - numHours * 3600;
    }
    function subMinutes(uint256 timestamp, uint256 numMinutes)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp - numMinutes * 60;
    }
    function subSeconds(uint256 timestamp, uint256 numSeconds)
        internal
        pure
        returns (uint256 result)
    {
        result = timestamp - numSeconds;
    }
    function diffYears(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        toTimestamp - fromTimestamp;
        (uint256 fromYear,,) = epochDayToDate(fromTimestamp / 86400);
        (uint256 toYear,,) = epochDayToDate(toTimestamp / 86400);
        result = _sub(toYear, fromYear);
    }
    function diffMonths(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        toTimestamp - fromTimestamp;
        (uint256 fromYear, uint256 fromMonth,) = epochDayToDate(fromTimestamp / 86400);
        (uint256 toYear, uint256 toMonth,) = epochDayToDate(toTimestamp / 86400);
        result = _sub(_totalMonths(toYear, toMonth), _totalMonths(fromYear, fromMonth));
    }
    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 86400;
    }
    function diffHours(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 3600;
    }
    function diffMinutes(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = (toTimestamp - fromTimestamp) / 60;
    }
    function diffSeconds(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256 result)
    {
        result = toTimestamp - fromTimestamp;
    }
    function _totalMonths(uint256 numYears, uint256 numMonths)
        private
        pure
        returns (uint256 total)
    {
        unchecked {
            total = numYears * 12 + numMonths;
        }
    }
    function _add(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a + b;
        }
    }
    function _sub(uint256 a, uint256 b) private pure returns (uint256 c) {
        unchecked {
            c = a - b;
        }
    }
    function _offsetted(uint256 year, uint256 month, uint256 day, uint256 timestamp)
        private
        pure
        returns (uint256 result)
    {
        uint256 dm = daysInMonth(year, month);
        if (day >= dm) {
            day = dm;
        }
        result = dateToEpochDay(year, month, day) * 86400 + (timestamp % 86400);
    }
}