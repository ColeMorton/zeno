/**
 * Simulation analytics utilities.
 * Provides reporting and ghost variable integration for local testing.
 *
 * @module simulation
 */

export {
  SimulationReporter,
  createSimulationReporter,
  type SimulationReport,
  type SimulationSummary,
  type SimulationReporterConfig,
} from './reporter.js';

export {
  readGhostVariables,
  formatGhostVariables,
  calculateConservation,
  type GhostVariables,
  type ProtocolGhostVariables,
  type CrossLayerGhostVariables,
  type CallCounterVariables,
} from './ghosts.js';
