pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { DateTime } from "./external/DateTime.sol";
import { SafeCast } from "./SafeCast.sol";
import { BalancerVault } from "./interfaces/BalancerVault.sol";
import { Space } from "./interfaces/Space.sol";
interface SpaceFactoryLike {
    function divider() external view returns (address);
    function create(address, uint256) external returns (address);
    function pools(address, uint256) external view returns (Space);
}
interface DividerLike {
    function series(address, uint256) external returns (address, uint48, address, uint96, address, uint256, uint256, uint256, uint256);
    function issue(address, uint256, uint256) external returns (uint256);
    function settleSeries(address, uint256) external;
    function mscale(address, uint256) external view returns (uint256);
    function redeem(address, uint256, uint256) external;
    function combine(address, uint256, uint256) external;
}
interface YTLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function collect() external;
    function balanceOf(address) external view returns (uint256);
}
interface PeripheryLike {
    function sponsorSeries(address, uint256, bool) external returns (ERC20, YTLike);
    function swapYTsForTarget(address, uint256, uint256) external returns (uint256);
    function create(address, uint256) external returns (address);
    function spaceFactory() external view returns (SpaceFactoryLike);
    function MIN_YT_SWAP_IN() external view returns (uint256);
}
interface OwnedAdapterLike {
    function target() external view returns (address);
    function ifee() external view returns (uint256);
    function openSponsorWindow() external;
    function scale() external returns (uint256);
    function scaleStored() external view returns (uint256);
    function getStakeAndTarget() external view returns (address,address,uint256);
    function setIsTrusted(address,bool) external;
}
contract AutoRoller is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using SafeCast for *;
    error ActivePhaseOnly();
    error UnrecognizedParam(bytes32 what);
    error InsufficientLiquidity();
    error RollWindowNotOpen();
    error OnlyAdapter();
    error InvalidSettler();
    uint32 internal constant MATURITY_NOT_SET = type(uint32).max;
    int256 internal constant WITHDRAWAL_GUESS_OFFSET = 0.95e18; 
    DividerLike      internal immutable divider;
    BalancerVault    internal immutable balancerVault;
    OwnedAdapterLike internal immutable adapter;
    uint256 internal immutable ifee; 
    uint256 internal immutable minSwapAmount; 
    uint256 internal immutable firstDeposit; 
    uint256 internal immutable maxError; 
    address internal immutable rewardRecipient; 
    PeripheryLike    internal periphery;
    SpaceFactoryLike internal spaceFactory;
    address          internal owner; 
    RollerUtils      internal utils; 
    YTLike  internal yt;
    ERC20   internal pt;
    Space   internal space;
    bytes32 internal poolId;
    address internal lastRoller; 
    uint256 internal initScale;
    uint256 public  maturity = MATURITY_NOT_SET;
    uint256 internal pti;
    uint256 internal maxRate        = 53144e19; 
    uint256 internal targetedRate   = 2.9e18; 
    uint256 internal targetDuration = 3; 
    uint256 public cooldown         = 10 days; 
    uint256 public lastSettle; 
    constructor(
        ERC20 _target,
        DividerLike _divider,
        address _periphery,
        address _spaceFactory,
        address _balancerVault,
        OwnedAdapterLike _adapter,
        RollerUtils _utils,
        address _rewardRecipient
    ) ERC4626(
        _target,
        string(abi.encodePacked(_target.name(), " Sense Auto Roller")),
        string(abi.encodePacked(_target.symbol(), "-sAR"))
    ) {
        divider       = _divider;
        periphery     = PeripheryLike(_periphery);
        spaceFactory  = SpaceFactoryLike(_spaceFactory);
        balancerVault = BalancerVault(_balancerVault);
        _target.safeApprove(address(_divider), type(uint256).max);
        _target.safeApprove(address(_balancerVault), type(uint256).max);
        uint256 scalingFactor = 10**(18 - decimals);
        minSwapAmount = (periphery.MIN_YT_SWAP_IN() - 1) / scalingFactor + 1; 
        maxError      = (1e7 - 1) / scalingFactor + 1;
        firstDeposit  = (0.01e18 - 1) / scalingFactor + 1;
        adapter = _adapter;
        ifee    = _adapter.ifee(); 
        owner   = msg.sender;
        utils   = _utils;
        rewardRecipient = _rewardRecipient;
    }
    function roll() external {
        if (maturity != MATURITY_NOT_SET) revert RollWindowNotOpen();
        if (lastSettle == 0) {
            deposit(firstDeposit, address(0));
        } else if (lastSettle + cooldown > block.timestamp) {
            revert RollWindowNotOpen();
        }
        lastRoller = msg.sender;
        adapter.openSponsorWindow();
    }
    function onSponsorWindowOpened(ERC20 stake, uint256 stakeSize) external {
        if (msg.sender != address(adapter)) revert OnlyAdapter();
        stake.safeTransferFrom(lastRoller, address(this), stakeSize);
        stake.safeApprove(address(periphery), stakeSize);
        uint256 _maturity = utils.getFutureMaturity(targetDuration);
        (ERC20 _pt, YTLike _yt) = periphery.sponsorSeries(address(adapter), _maturity, true);
        (Space _space, bytes32 _poolId, uint256 _pti, uint256 _initScale) = utils.getSpaceData(periphery, OwnedAdapterLike(msg.sender), _maturity);
        _pt.approve(address(balancerVault), type(uint256).max);
        _yt.approve(address(periphery), type(uint256).max);
        ERC20 _asset = asset;
        ERC20[] memory tokens = new ERC20[](2);
        tokens[1 - _pti] = _asset;
        tokens[_pti] = _pt;
        uint256 targetBal = _asset.balanceOf(address(this));
        (uint256 eqPTReserves, uint256 eqTargetReserves) = _space.getEQReserves(
            targetedRate < 0.01e18 ? 0.01e18 : targetedRate, 
            _maturity,
            0, 
            targetBal, 
            targetBal.mulWadDown(_initScale), 
            _space.g2() 
        );
        uint256 targetForIssuance = _getTargetForIssuance(eqPTReserves, eqTargetReserves, targetBal, _initScale);
        divider.issue(address(adapter), _maturity, targetForIssuance);
        uint256[] memory balances = new uint256[](2);
        balances[1 - _pti] = targetBal - targetForIssuance;
        _joinPool(
            _poolId,
            BalancerVault.JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: balances,
                userData: abi.encode(balances, 0), 
                fromInternalBalance: false
            })
        );
        _swap(
            BalancerVault.SingleSwap({
                poolId: _poolId,
                kind: BalancerVault.SwapKind.GIVEN_IN,
                assetIn: address(_pt),
                assetOut: address(tokens[1 - _pti]),
                amount: eqPTReserves.mulDivDown(balances[1 - _pti], targetBal),
                userData: hex""
            })
        );
        balances[_pti    ] = _pt.balanceOf(address(this));
        balances[1 - _pti] = _asset.balanceOf(address(this));
        _joinPool(
            _poolId,
            BalancerVault.JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: balances,
                userData: abi.encode(balances, 0), 
                fromInternalBalance: false
            })
        );
        space  = _space;
        poolId = _poolId;
        pt     = _pt;
        yt     = _yt;
        initScale = _initScale;
        maturity  = _maturity; 
        pti       = _pti;
        emit Rolled(_maturity, uint256(_initScale), address(_space), msg.sender);
    }
    function settle() public {
        if(msg.sender != lastRoller) revert InvalidSettler();
        uint256 assetBalPre = asset.balanceOf(address(this));
        divider.settleSeries(address(adapter), maturity); 
        uint256 assetBalPost = asset.balanceOf(address(this));
        asset.safeTransfer(msg.sender, assetBalPost - assetBalPre); 
        (, address stake, uint256 stakeSize) = adapter.getStakeAndTarget();
        if (stake != address(asset)) {
            ERC20(stake).safeTransfer(msg.sender, stakeSize);
        }
        startCooldown();
    }
    function startCooldown() public {
        require(divider.mscale(address(adapter), maturity) != 0);
        ERC20[] memory tokens = new ERC20[](2);
        tokens[1 - pti] = asset;
        tokens[pti    ] = pt;
        _exitPool(
            poolId,
            BalancerVault.ExitPoolRequest({
                assets: tokens,
                minAmountsOut: new uint256[](2),
                userData: abi.encode(space.balanceOf(address(this))),
                toInternalBalance: false
            })
        );
        divider.redeem(address(adapter), maturity, pt.balanceOf(address(this))); 
        yt.collect(); 
        targetedRate = utils.getNewTargetedRate(targetedRate, address(adapter), maturity, space);
        maturity   = MATURITY_NOT_SET;
        lastSettle = uint32(block.timestamp);
        delete pt; delete yt; delete space; delete pti; delete poolId; delete initScale; 
    }
    function beforeWithdraw(uint256, uint256 shares) internal override {
        if (maturity != MATURITY_NOT_SET) {
            (uint256 excessBal, bool isExcessPTs) = _exitAndCombine(shares);
            if (excessBal < minSwapAmount) return;
            if (isExcessPTs) {
                (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
                uint256 maxPTSale = _maxPTSell(ptReserves, targetReserves, space.adjustedTotalSupply());
                if (excessBal > maxPTSale) revert InsufficientLiquidity(); 
                _swap(
                    BalancerVault.SingleSwap({
                        poolId: poolId,
                        kind: BalancerVault.SwapKind.GIVEN_IN,
                        assetIn: address(pt),
                        assetOut: address(asset),
                        amount: excessBal,
                        userData: hex""
                    })
                );
            } else {
                periphery.swapYTsForTarget(address(adapter), maturity, excessBal); 
            }
        }
    }
    function afterDeposit(uint256 assets, uint256 shares) internal override {
        if (maturity != MATURITY_NOT_SET) {
            uint256 _supply = totalSupply; 
            bytes32 _poolId = poolId;
            uint256 _pti    = pti;
            (ERC20[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(_poolId);
            uint256 previewedLPBal = _supply - shares == 0 ?
                shares : shares.mulDivUp(space.balanceOf(address(this)), _supply - shares); 
            uint256 targetToJoin = previewedLPBal.mulDivUp(balances[1 - _pti], space.adjustedTotalSupply());
            balances[1 - _pti] = targetToJoin;
            if (assets - targetToJoin > 0) { 
                balances[_pti] = divider.issue(address(adapter), maturity, assets - targetToJoin);
            }
            _joinPool(
                _poolId,
                BalancerVault.JoinPoolRequest({
                    assets: tokens,
                    maxAmountsIn: balances,
                    userData: abi.encode(balances, 0),
                    fromInternalBalance: false
                })
            );
        }
    }
    function totalAssets() public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return asset.balanceOf(address(this));
        } 
        else {
            Space _space = space;
            (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
            (uint256 targetBal, uint256 ptBal, uint256 ytBal, ) = _decomposeShares(ptReserves, targetReserves, totalSupply, true);
            uint256 ptSpotPrice = _space.getPriceFromImpliedRate(
                (ptReserves + _space.adjustedTotalSupply()).divWadDown(targetReserves.mulWadDown(initScale)) - 1e18
            ); 
            uint256 scale = adapter.scaleStored();
            if (ptBal >= ytBal) {
                return targetBal + ytBal.divWadDown(scale) + ptSpotPrice.mulWadDown(ptBal - ytBal);
            } else {
                uint256 ytSpotPrice = (1e18 - ptSpotPrice.mulWadDown(scale)).divWadDown(scale);
                return targetBal + ptBal.divWadDown(scale) + ytSpotPrice.mulWadDown(ytBal - ptBal);
            }
        }
    }
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return super.previewDeposit(assets);
        } else {
            Space _space = space;
            (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
            uint256 previewedLPBal = (assets - _getTargetForIssuance(ptReserves, targetReserves, assets, adapter.scaleStored()))
                .mulDivDown(_space.adjustedTotalSupply(), targetReserves);
            return previewedLPBal.mulDivDown(totalSupply, _space.balanceOf(address(this)));
        }
    }
    function previewMint(uint256 shares) public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return super.previewMint(shares);
        } else {
            (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
            (uint256 targetToJoin, uint256 ptsToJoin, , ) = _decomposeShares(ptReserves, targetReserves, shares, true);
            return targetToJoin + ptsToJoin.divWadUp(adapter.scaleStored().mulWadDown(1e18 - ifee)); 
        }
    }
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return super.previewRedeem(shares);
        } else {
            (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
            (uint256 targetBal, uint256 ptBal, uint256 ytBal, uint256 lpBal) = _decomposeShares(ptReserves, targetReserves, shares, false);
            uint256 scale = adapter.scaleStored();
            ptReserves     = ptReserves - ptBal;
            targetReserves = targetReserves - targetBal;
            uint256 spaceSupply = space.adjustedTotalSupply();
            ptBal       = ptBal       + lpBal.mulDivDown(pt.balanceOf(address(this)), spaceSupply);
            targetBal   = targetBal   + lpBal.mulDivDown(asset.balanceOf(address(this)), spaceSupply);
            spaceSupply = spaceSupply - lpBal;
            if (ptBal > ytBal) {
                unchecked {
                    uint256 maxPTSale = _maxPTSell(
                        ptReserves,
                        targetReserves,
                        spaceSupply
                    );
                    uint256 ptsToSell = _min(ptBal - ytBal, maxPTSale);
                    uint256 targetOut = ptsToSell > minSwapAmount ?
                        space.onSwapPreview(
                            true,
                            true,
                            ptsToSell,
                            ptReserves,
                            targetReserves,
                            spaceSupply,
                            scale
                        ) : 0;
                    return targetBal + ytBal.divWadDown(scale) + targetOut - maxError;
                }
            } else {
                unchecked {
                    uint256 ytsToSell = _min(ytBal - ptBal, ptReserves);
                    uint256 targetOut = ytsToSell > minSwapAmount ? 
                        ytsToSell.divWadDown(scale) - space.onSwapPreview(
                            false,
                            false,
                            ytsToSell,
                            targetReserves,
                            ptReserves,
                            spaceSupply,
                            scale
                        ) : 0;
                    return targetBal + ptBal.divWadDown(scale) + targetOut - maxError;
                }
            }
        }
    }
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return super.previewWithdraw(assets);
        } else {
            uint256 _supply = totalSupply - firstDeposit;
            int256 prevGuess  = _min(assets, _supply).safeCastToInt();
            int256 prevAnswer = previewRedeem(prevGuess.safeCastToUint()).safeCastToInt() - assets.safeCastToInt();
            int256 guess = prevGuess * WITHDRAWAL_GUESS_OFFSET / 1e18;
            int256 supply = _supply.safeCastToInt();
            for (uint256 i = 0; i < 20;) { 
                if (guess > supply) {
                    guess = supply;
                }
                int256 answer = previewRedeem(guess.safeCastToUint()).safeCastToInt() - assets.safeCastToInt();
                if (answer >= 0 && answer <= assets.mulWadDown(0.001e18).safeCastToInt() || (prevAnswer == answer)) { 
                    break;
                }
                if (guess == supply && answer < 0) revert InsufficientLiquidity();
                int256 nextGuess = guess - (answer * (guess - prevGuess) / (answer - prevAnswer));
                prevGuess  = guess;
                prevAnswer = answer;
                guess      = nextGuess;
                unchecked { ++i; }
            }
            return guess.safeCastToUint() + maxError; 
        }
    }
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (maturity == MATURITY_NOT_SET) {
            return super.maxWithdraw(owner);
        } else {
            return previewRedeem(maxRedeem(owner));
        }
    }
    function maxRedeem(address owner) public view override returns (uint256) { 
        if (maturity == MATURITY_NOT_SET) {
            return super.maxRedeem(owner);
        } else {
            uint256 shares = balanceOf[owner];
            (uint256 ptReserves, uint256 targetReserves) = _getSpaceReserves();
            (uint256 targetBal, uint256 ptBal, uint256 ytBal, uint256 lpBal) = _decomposeShares(ptReserves, targetReserves, shares, false);
            ptReserves     = ptReserves - ptBal;
            targetReserves = targetReserves - targetBal;
            uint256 spaceSupply = space.adjustedTotalSupply();
            ptBal       = ptBal       + lpBal.mulDivDown(pt.balanceOf(address(this)), spaceSupply);
            targetBal   = targetBal   + lpBal.mulDivDown(asset.balanceOf(address(this)), spaceSupply);
            spaceSupply = spaceSupply - lpBal;
            bool isExcessPTs = ptBal > ytBal;
            uint256 diff = isExcessPTs ? ptBal - ytBal : ytBal - ptBal;
            if (isExcessPTs) {
                uint256 maxPTSale = _maxPTSell(ptReserves, targetReserves, spaceSupply);
                if (maxPTSale >= diff) {
                    return shares;
                } else {
                    uint256 hole = diff.divWadDown(lpBal);
                    return maxPTSale.divWadDown(hole).mulDivDown(totalSupply, space.balanceOf(address(this)));
                }
            } else {
                if (ptReserves >= diff) { 
                    return shares;
                } else {
                    uint256 hole = diff.divWadDown(lpBal);
                    return ptReserves.divWadDown(hole).mulDivDown(totalSupply, space.balanceOf(address(this)));
                }
            }
        }
    }
    function eject(
        uint256 shares,
        address receiver,
        address owner
    ) public returns (uint256 assets, uint256 excessBal, bool isExcessPTs) {
        if (maturity == MATURITY_NOT_SET) revert ActivePhaseOnly();
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; 
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        (excessBal, isExcessPTs) = _exitAndCombine(shares);
        _burn(owner, shares); 
        if (isExcessPTs) {
            pt.transfer(receiver, excessBal);
        } else {
            yt.transfer(receiver, excessBal);
        }
        asset.transfer(receiver, assets = asset.balanceOf(address(this)));
        emit Ejected(msg.sender, receiver, owner, assets, shares,
            isExcessPTs ? excessBal : 0,
            isExcessPTs ? 0 : excessBal
        );
    }
    function _exitAndCombine(uint256 shares) internal returns (uint256, bool) {
        uint256 supply = totalSupply; 
        uint256 lpBal      = shares.mulDivDown(space.balanceOf(address(this)), supply);
        uint256 totalPTBal = pt.balanceOf(address(this));
        uint256 ptShare    = shares.mulDivDown(totalPTBal, supply);
        ERC20[] memory tokens = new ERC20[](2);
        tokens[1 - pti] = asset;
        tokens[pti    ] = pt;
        _exitPool(
            poolId,
            BalancerVault.ExitPoolRequest({
                assets: tokens,
                minAmountsOut: new uint256[](2),
                userData: abi.encode(lpBal),
                toInternalBalance: false
            })
        );
        uint256 ytBal = shares.mulDivDown(yt.balanceOf(address(this)), supply);
        ptShare += pt.balanceOf(address(this)) - totalPTBal;
        unchecked {
            if (ptShare > ytBal) {
                divider.combine(address(adapter), maturity, ytBal);
                return (ptShare - ytBal, true);
            } else { 
                divider.combine(address(adapter), maturity, ptShare);
                return (ytBal - ptShare, false);
            }
        }
    }
    function claimRewards(ERC20 coin) external {
        require(coin != asset);
        if (maturity != MATURITY_NOT_SET) {
            require(coin != ERC20(address(yt)) && coin != pt && coin != ERC20(address(space)));
        }
        coin.transfer(rewardRecipient, coin.balanceOf(address(this)));
    }
    function _joinPool(bytes32 _poolId, BalancerVault.JoinPoolRequest memory request) internal {
        balancerVault.joinPool(_poolId, address(this), address(this), request);
    }
    function _exitPool(bytes32 _poolId, BalancerVault.ExitPoolRequest memory request) internal {
        balancerVault.exitPool(_poolId, address(this), payable(address(this)), request);
    }
    function _swap(BalancerVault.SingleSwap memory request) internal {
        BalancerVault.FundManagement memory funds = BalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        balancerVault.swap(request, funds, 0, type(uint256).max);
    }
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
    function _getTargetForIssuance(uint256 ptReserves, uint256 targetReserves, uint256 targetBal, uint256 scale) 
        internal view returns (uint256) 
    {
        return targetBal.mulWadUp(ptReserves.divWadUp(
            scale.mulWadDown(1e18 - ifee).mulWadDown(targetReserves) + ptReserves
        ));
    }
    function _getSpaceReserves() internal view returns (uint256, uint256) {
        (, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        uint256 _pti = pti;
        return (balances[_pti], balances[1 - _pti]);
    }
    function _decomposeShares(uint256 ptReserves, uint256 targetReserves, uint256 shares, bool withLoose)
        internal view returns (uint256, uint256, uint256, uint256)
    {
        uint256 supply      = totalSupply;
        uint256 totalLPBal  = space.balanceOf(address(this));
        uint256 spaceSupply = space.adjustedTotalSupply();
        return (
            shares.mulDivUp(totalLPBal.mulDivUp(targetReserves, spaceSupply) + (withLoose ? asset.balanceOf(address(this)) : 0), supply),
            shares.mulDivUp(totalLPBal.mulDivUp(ptReserves, spaceSupply) + (withLoose ? pt.balanceOf(address(this)) : 0), supply),
            shares.mulDivUp(yt.balanceOf(address(this)), supply),
            shares.mulDivUp(totalLPBal, supply)
        );
    }
    function _maxPTSell(uint256 ptReserves, uint256 targetReserves, uint256 spaceSupply) internal view returns (uint256) {
        (uint256 eqPTReserves, ) = space.getEQReserves(
            maxRate, 
            maturity,
            ptReserves,
            targetReserves,
            spaceSupply,
            space.g2()
        );
        return ptReserves >= eqPTReserves ? 0 : eqPTReserves - ptReserves; 
    }
    function setParam(bytes32 what, address data) external {
        require(msg.sender == owner);
        if (what == "SPACE_FACTORY") spaceFactory = SpaceFactoryLike(data);
        else if (what == "PERIPHERY") periphery = PeripheryLike(data);
        else if (what == "OWNER") owner = data;
        else revert UnrecognizedParam(what);
        emit ParamChanged(what, data);
    }
    function setParam(bytes32 what, uint256 data) external {
        require(msg.sender == owner);
        if (what == "MAX_RATE") maxRate = data;
        else if (what == "TARGET_DURATION") targetDuration = data;
        else if (what == "COOLDOWN") {
            require(lastSettle == 0 || maturity != MATURITY_NOT_SET); 
            cooldown = data;
        }
        else revert UnrecognizedParam(what);
        emit ParamChanged(what, data);
    }
    event ParamChanged(bytes32 what, address newData);
    event ParamChanged(bytes32 what, uint256 newData);
    event Rolled(uint256 nextMaturity, uint256 initScale, address space, address roller);
    event Ejected(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        uint256 pts,
        uint256 yts
    );
}
contract RollerUtils {
    using FixedPointMathLib for uint256;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;
    uint256 internal constant ONE = 1e18;
    address internal constant DIVIDER = 0x09B10E45A912BcD4E80a8A3119f0cfCcad1e1f12;
    function getFutureMaturity(uint256 monthsForward) public view returns (uint256) {
        (uint256 year, uint256 month, ) = DateTime.timestampToDate(DateTime.addMonths(block.timestamp, monthsForward));
        return DateTime.timestampFromDateTime(year, month, 1 , 0, 0, 0);
    }
    function getSpaceData(PeripheryLike periphery, OwnedAdapterLike adapter, uint256 maturity)
        public returns (Space, bytes32, uint256, uint256)
    {
        Space _space = periphery.spaceFactory().pools(address(adapter), maturity);
        return (_space, _space.getPoolId(), _space.pti(), adapter.scale());
    }
    function getNewTargetedRate(uint256 , address adapter, uint256 prevMaturity, Space space) public returns (uint256) {
        (, uint48 prevIssuance, , , , , uint256 iscale, uint256 mscale, ) = DividerLike(DIVIDER).series(adapter, prevMaturity);
        require(mscale != 0);
        if (mscale <= iscale) return 0;
        uint256 rate = (_powWad(
            (mscale - iscale).divWadDown(iscale) + ONE, ONE.divWadDown((prevMaturity - prevIssuance) * ONE)
        ) - ONE).mulWadDown(SECONDS_PER_YEAR * ONE);
        return _powWad(rate + ONE, ONE.divWadDown(space.ts().mulWadDown(SECONDS_PER_YEAR * ONE))) - ONE;
    }
    function _powWad(uint256 x, uint256 y) internal pure returns (uint256) {
        require(x < 1 << 255);
        require(y < 1 << 255);
        return uint256(FixedPointMathLib.powWad(int256(x), int256(y))); 
    }
}