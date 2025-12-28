/**
 * Event indexing utilities for local simulation.
 * Provides real-time event capture during Anvil testnet runs.
 *
 * @module indexer
 */

export {
  AnvilIndexer,
  createAnvilIndexer,
  type ContractAddresses,
  type EventFilter,
  type AnvilIndexerConfig,
} from './anvil.js';
