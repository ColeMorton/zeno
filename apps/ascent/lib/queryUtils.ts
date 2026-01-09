/**
 * JSON replacer function for bigint values
 * Used for serializing query data that contains bigints
 */
export function bigintReplacer(_key: string, value: unknown): unknown {
  return typeof value === 'bigint' ? value.toString() : value;
}

/**
 * Creates a structural sharing function for TanStack Query
 * Compares old and new data by JSON serialization to prevent unnecessary re-renders
 * Handles bigint values correctly
 */
export function createStructuralSharing<T>() {
  return (oldData: T | undefined, newData: T): T => {
    if (!oldData || !newData) return newData;
    const oldJson = JSON.stringify(oldData, bigintReplacer);
    const newJson = JSON.stringify(newData, bigintReplacer);
    return oldJson === newJson ? oldData : newData;
  };
}

/**
 * Pre-built structural sharing function for common use cases
 * Use this directly in query options: structuralSharing: bigintStructuralSharing
 */
export const bigintStructuralSharing = <T>(oldData: T | undefined, newData: T): T => {
  if (!oldData || !newData) return newData;
  const oldJson = JSON.stringify(oldData, bigintReplacer);
  const newJson = JSON.stringify(newData, bigintReplacer);
  return oldJson === newJson ? oldData : newData;
};
