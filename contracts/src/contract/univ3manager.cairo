#[starknet::contract]
mod UniswapV3Manager {
    use contracts::contract::interface::{
        IERC20TraitDispatcher, IERC20TraitDispatcherTrait, IUniswapV3Manager,
        UniswapV3PoolTraitDispatcher, UniswapV3PoolTraitDispatcherTrait,
    };
    use contracts::libraries::utils::math::scale_amount;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    #[storage]
    struct Storage {
        token0: ContractAddress,
        token1: ContractAddress,
        pool_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        pool_address: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
    ) {
        self.pool_address.write(pool_address);
        self.token0.write(token0);
        self.token1.write(token1);
    }

    #[abi(embed_v0)]
    impl IUniswapV3ManagerImpl of IUniswapV3Manager<ContractState> {
        fn mint_callback(
            ref self: ContractState, amount0: u128, amount1: u128, data: Array<felt252>,
        ) {
            let caller = get_caller_address();
            assert(caller == self.pool_address.read(), 'only pool can call contract');
            let mut erc0 = IERC20TraitDispatcher { contract_address: self.token0.read() };
            let mut erc1 = IERC20TraitDispatcher { contract_address: self.token1.read() };

            erc0.transfer(caller, amount0.into());
            erc1.transfer(caller, amount1.into());
        }

        fn burn_callback(ref self: ContractState, amount0: u128, amount1: u128) {
            let caller = get_caller_address();
            assert(caller == self.pool_address.read(), 'only pool can call contract');

            let mut erc0 = IERC20TraitDispatcher { contract_address: self.token0.read() };
            let mut erc1 = IERC20TraitDispatcher { contract_address: self.token1.read() };

            if amount0 != 0 {
                erc0.burn(amount0.into());
            }

            if amount1 != 0 {
                erc1.burn(amount1.into());
            }
        }

        fn swap_callback(
            ref self: ContractState, amount0_delta: i128, amount1_delta: i128, data: Array<felt252>,
        ) {
            let caller = get_caller_address();
            assert(caller == self.pool_address.read(), 'only pool can call contract');

            if amount0_delta > 0 {
                let token0 = self.token0.read();
                let mut token0_dispatcher = IERC20TraitDispatcher { contract_address: token0 };
                let decimals0 = token0_dispatcher.get_decimals();
                let scaled_amount0 = scale_amount(amount0_delta, decimals0);
                token0_dispatcher.transfer(caller, scaled_amount0.try_into().unwrap());
            }

            if amount1_delta > 0 {
                let token1 = self.token1.read();
                let mut token1_dispatcher = IERC20TraitDispatcher { contract_address: token1 };
                let decimals1 = token1_dispatcher.get_decimals();
                let scaled_amount1 = scale_amount(amount1_delta, decimals1);
                token1_dispatcher.transfer(caller, scaled_amount1.try_into().unwrap());
            }
        }


        fn mint(
            ref self: ContractState,
            lower_tick: i32,
            upper_tick: i32,
            amount: u128,
            data: Array<felt252>,
        ) -> (u256, u256) {
            let pool_address = self.pool_address.read();
            let mut pool = UniswapV3PoolTraitDispatcher { contract_address: pool_address };

            pool.mint(lower_tick, upper_tick, amount, data)
        }

        fn burn(
            ref self: ContractState, lower_tick: i32, upper_tick: i32, amount: u128,
        ) -> (u256, u256) {
            let pool_address = self.pool_address.read();
            let mut pool = UniswapV3PoolTraitDispatcher { contract_address: pool_address };

            pool.burn(lower_tick, upper_tick, amount)
        }
    }
}
