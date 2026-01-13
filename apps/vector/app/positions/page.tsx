'use client';

export default function PositionsPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Your Positions</h1>
        <p className="text-vector-neutral">
          View and manage all your active positions across products.
        </p>
      </div>

      {/* Positions Grid */}
      <div className="space-y-6">
        {/* Perpetual Positions */}
        <section>
          <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-vector-primary" />
            Perpetual Positions
          </h2>
          <div className="bg-vector-card border border-vector-border rounded-lg p-6">
            <p className="text-vector-muted">No open positions</p>
          </div>
        </section>

        {/* Yield Positions */}
        <section>
          <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-position-yield" />
            Yield Vault
          </h2>
          <div className="bg-vector-card border border-vector-border rounded-lg p-6">
            <p className="text-vector-muted">No deposits</p>
          </div>
        </section>

        {/* Volatility Positions */}
        <section>
          <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-position-volLong" />
            Volatility Pools
          </h2>
          <div className="bg-vector-card border border-vector-border rounded-lg p-6">
            <p className="text-vector-muted">No pool shares</p>
          </div>
        </section>
      </div>
    </div>
  );
}
