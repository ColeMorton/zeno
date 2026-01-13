'use client';

export default function VolatilityPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Volatility Pools</h1>
        <p className="text-vector-neutral">
          Long or short volatility via socialized pools. Daily settlement.
        </p>
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Long Vol Pool */}
        <div className="bg-vector-card border border-vector-border rounded-lg p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-4 h-4 rounded-full bg-position-volLong" />
            <h2 className="text-xl font-semibold">Long Volatility</h2>
          </div>

          <p className="text-vector-neutral text-sm mb-4">
            Profit when realized variance exceeds strike variance.
          </p>

          <div className="space-y-3">
            <div className="flex justify-between text-sm">
              <span className="text-vector-muted">Pool Assets</span>
              <span className="font-mono">--</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-vector-muted">Your Shares</span>
              <span className="font-mono">--</span>
            </div>
          </div>
        </div>

        {/* Short Vol Pool */}
        <div className="bg-vector-card border border-vector-border rounded-lg p-6">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-4 h-4 rounded-full bg-position-volShort" />
            <h2 className="text-xl font-semibold">Short Volatility</h2>
          </div>

          <p className="text-vector-neutral text-sm mb-4">
            Profit when realized variance is below strike variance.
          </p>

          <div className="space-y-3">
            <div className="flex justify-between text-sm">
              <span className="text-vector-muted">Pool Assets</span>
              <span className="font-mono">--</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-vector-muted">Your Shares</span>
              <span className="font-mono">--</span>
            </div>
          </div>
        </div>
      </div>

      {/* Settlement Status */}
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-semibold mb-1">Settlement Status</h3>
            <p className="text-vector-muted text-sm">Next settlement in: --</p>
          </div>
          <div className="text-right">
            <div className="text-sm text-vector-muted mb-1">Realized Variance</div>
            <div className="font-mono">-- vs -- strike</div>
          </div>
        </div>
      </div>
    </div>
  );
}
