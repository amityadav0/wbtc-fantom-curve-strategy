// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/uniswap/IUniswapRouterV2.sol";
import "../interfaces/curve/ICurvePool.sol";

import {BaseStrategy} from "../deps/BaseStrategy.sol";

interface ICurveRewardGauge {
    function deposit(uint256 amount) external;

    function withdraw(uint256 shares) external;

    function claim_rewards(address _addr, address _receiver) external;
}

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public lpComponent; // Token we provide liquidity with
    address public reward; // Token we farm and swap to want / lpComponent

    address public constant WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address public constant CRV = 0x1E4F97b9f9F913c46F1632781732927B9019C68b;

    address public constant FANTOM_CURVE_BTC_GAUGE =
        0xBdFF0C27dd073C119ebcb1299a68A6A92aE607F0;
    address public constant SPOOKYSWAP_ROUTER =
        0xF491e7B69E4244ad4002BC14e878a34207E38c29;

    address public constant CURVE_BTC_POOL =
        0x3eF6A01A0f81D6046290f3e2A8c5b843e738E604;

    // Used to signal to the Badger Tree that rewards where sent to it
    event TreeDistribution(
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[3] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(
            _governance,
            _strategist,
            _controller,
            _keeper,
            _guardian
        );
        /// @dev Add config here
        want = _wantConfig[0];
        lpComponent = _wantConfig[1];
        reward = _wantConfig[2];

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(
            FANTOM_CURVE_BTC_GAUGE,
            type(uint256).max
        );

        IERC20Upgradeable(reward).safeApprove(
            SPOOKYSWAP_ROUTER,
            type(uint256).max
        );
        IERC20Upgradeable(WBTC).safeApprove(
            SPOOKYSWAP_ROUTER,
            type(uint256).max
        );
        IERC20Upgradeable(CRV).safeApprove(
            SPOOKYSWAP_ROUTER,
            type(uint256).max
        );

        IERC20Upgradeable(WBTC).safeApprove(CURVE_BTC_POOL, type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external pure override returns (string memory) {
        return "Fantom-renBTC/wBTC-curve-strategy";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public view override returns (uint256) {
        return IERC20Upgradeable(lpComponent).balanceOf(address(this));
    }

    /// @dev Returns true if this strategy requires tending
    function isTendable() public view override returns (bool) {
        return balanceOfWant() > 0;
    }

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens()
        public
        view
        override
        returns (address[] memory)
    {
        address[] memory protectedTokens = new address[](3);
        protectedTokens[0] = want;
        protectedTokens[1] = lpComponent;
        protectedTokens[2] = reward;
        return protectedTokens;
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for (uint256 x = 0; x < protectedTokens.length; x++) {
            require(
                address(protectedTokens[x]) != _asset,
                "Asset is protected"
            );
        }
    }

    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {
        ICurveRewardGauge(FANTOM_CURVE_BTC_GAUGE).deposit(_amount);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        ICurveRewardGauge(FANTOM_CURVE_BTC_GAUGE).withdraw(balanceOfPool());
    }

    /// @dev withdraw the specified amount of want, liquidate from lpComponent to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        ICurveRewardGauge(FANTOM_CURVE_BTC_GAUGE).withdraw(_amount);
        return _amount;
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        // Write your code here
        ICurveRewardGauge(FANTOM_CURVE_BTC_GAUGE).claim_rewards(
            address(this),
            address(this)
        );

        uint256 earned_crv = IERC20Upgradeable(CRV).balanceOf(address(this));
        if (earned_crv > 0) {
            address[] memory path = new address[](2);
            path[0] = CRV;
            path[1] = reward;
            // swap crv to wFTM
            IUniswapRouterV2(SPOOKYSWAP_ROUTER).swapExactTokensForTokens(
                earned_crv,
                0,
                path,
                address(this),
                now
            );
        }

        uint256 earned_fantom =
            IERC20Upgradeable(reward).balanceOf(address(this));
        if (earned_fantom == 0) {
            return 0;
        }
        address[] memory path = new address[](2);
        path[0] = reward;
        path[1] = WBTC;
        // swap wFTM to BTC
        IUniswapRouterV2(SPOOKYSWAP_ROUTER).swapExactTokensForTokens(
            earned_fantom,
            0,
            path,
            address(this),
            now
        );

        uint256[2] memory amounts;
        amounts[0] = IERC20Upgradeable(WBTC).balanceOf(address(this));

        if (amounts[0] > 0)
            ICurvePool(CURVE_BTC_POOL).add_liquidity(amounts, 0);

        uint256 earned =
            IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        /// @notice Keep this in so you get paid!
        (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) =
            _processRewardsFees(earned, want);

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earned, block.number);

        /// @dev Harvest must return the amount of want increased
        return earned;
    }

    // Alternative Harvest with Price received from harvester, used to avoid exessive front-running
    function harvest(uint256 price)
        external
        whenNotPaused
        returns (uint256 harvested)
    {}

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();

        uint256 toDeposit = balanceOfWant();
        if (toDeposit > 0) {
            ICurveRewardGauge(FANTOM_CURVE_BTC_GAUGE).deposit(toDeposit);
        }
    }

    /// ===== Internal Helper Functions =====

    /// @dev used to manage the governance and strategist fee on earned rewards, make sure to use it to get paid!
    function _processRewardsFees(uint256 _amount, address _token)
        internal
        returns (uint256 governanceRewardsFee, uint256 strategistRewardsFee)
    {
        governanceRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeGovernance,
            IController(controller).rewards()
        );

        strategistRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeStrategist,
            strategist
        );
    }
}
