"""Invariant configuration and checking for BTCNFT Protocol simulation reports.

Provides a typed Python API for loading invariant bounds from JSON,
checking them against tick-level market data and action logs, and
generating structured alerts with red/yellow/green severity levels.

Usage:
    from invariant_config import load_invariants, check_all_ticks, Severity

    invariants = load_invariants(Path("invariants.json"))
    alerts = check_all_ticks(invariants, market_rows, actions, tick_count)
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
from collections import defaultdict
from pathlib import Path
from enum import Enum


class Severity(Enum):
    CRITICAL = "critical"
    WARNING = "warning"
    INFO = "info"

    @property
    def emoji(self) -> str:
        return {"critical": "🔴", "warning": "🟡", "info": "🔵"}.get(self.value, "⚪")

    @property
    def css_class(self) -> str:
        return {"critical": "alert-critical", "warning": "alert-warning", "info": "alert-info"}.get(
            self.value, "alert-info"
        )


class InvariantType(Enum):
    RANGE = "range"
    THRESHOLD_HIGH = "threshold_high"
    SOLVENCY = "solvency"
    MAX_RATIO = "max_ratio"


@dataclass(frozen=True)
class Alert:
    tick: int
    invariant_id: str
    label: str
    severity: Severity
    message: str

    def to_html(self) -> str:
        icon = self.severity.emoji
        cls = self.severity.css_class
        return (
            f'<div class="alert-row {cls}">'
            f'<span class="alert-icon">{icon}</span>'
            f'<span class="alert-tick">Tick {self.tick}</span>'
            f'<span class="alert-label">{self.label}</span>'
            f'<span class="alert-msg">{self.message}</span>'
            f'</div>'
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "tick": self.tick,
            "id": self.invariant_id,
            "label": self.label,
            "severity": self.severity.value,
            "message": self.message,
        }


@dataclass
class Invariant:
    id: str
    label: str
    type: InvariantType
    severity: Severity
    enabled: bool = True

    # Range fields
    column: str = ""
    scale: float = 1.0
    min: Optional[float] = None
    max: Optional[float] = None
    warn_min: Optional[float] = None
    warn_max: Optional[float] = None

    # Threshold fields
    warn_threshold: Optional[float] = None
    critical_threshold: Optional[float] = None
    window_ticks: int = 1

    # Solvency fields
    balance_column: str = ""
    liability_column: str = ""
    multiplier: float = 1.0

    # Max ratio fields
    numerator_column: str = ""
    denominator_column: str = ""
    max_ratio: Optional[float] = None

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "Invariant":
        inv_type = InvariantType(d.get("type", "range"))
        severity = Severity(d.get("severity", "critical"))
        return cls(
            id=d.get("id", ""),
            label=d.get("label", d.get("id", "")),
            type=inv_type,
            severity=severity,
            enabled=d.get("enabled", True),
            column=d.get("column", ""),
            scale=d.get("scale", 1.0),
            min=d.get("min"),
            max=d.get("max"),
            warn_min=d.get("warn_min"),
            warn_max=d.get("warn_max"),
            warn_threshold=d.get("warn_threshold"),
            critical_threshold=d.get("critical_threshold"),
            window_ticks=d.get("window_ticks", 1),
            balance_column=d.get("balance_column", ""),
            liability_column=d.get("liability_column", ""),
            multiplier=d.get("multiplier", 1.0),
            numerator_column=d.get("numerator_column", ""),
            denominator_column=d.get("denominator_column", ""),
            max_ratio=d.get("max_ratio"),
        )

    def check_range(self, row: Dict[str, Any]) -> Optional[Alert]:
        if self.type != InvariantType.RANGE:
            return None
        raw = row.get(self.column, 0)
        # Skip uninitialized pool (vbtcRatio == 0 before AMM seeding)
        if self.id == "vbtc_ratio_bounds" and raw == 0:
            return None
        val = raw / self.scale

        # Critical bounds
        crit_low = self.min if self.min is not None else float("-inf")
        crit_high = self.max if self.max is not None else float("inf")

        if val < crit_low or val > crit_high:
            return Alert(
                tick=row.get("tick", 0),
                invariant_id=self.id,
                label=self.label,
                severity=Severity.CRITICAL,
                message=f"{self.label} = {val:.4f} (bounds [{crit_low}, {crit_high}])",
            )

        # Warning bounds
        warn_low = self.warn_min if self.warn_min is not None else crit_low
        warn_high = self.warn_max if self.warn_max is not None else crit_high

        if val < warn_low or val > warn_high:
            return Alert(
                tick=row.get("tick", 0),
                invariant_id=self.id,
                label=self.label,
                severity=Severity.WARNING,
                message=f"{self.label} = {val:.4f} (warning bounds [{warn_low}, {warn_high}])",
            )

        return None

    def check_threshold_high(
        self, tick: int, total_actions: int, failed_actions: int
    ) -> Optional[Alert]:
        if self.type != InvariantType.THRESHOLD_HIGH:
            return None
        if total_actions == 0:
            return None
        rate = failed_actions / total_actions * 100

        crit = self.critical_threshold if self.critical_threshold is not None else float("inf")
        warn = self.warn_threshold if self.warn_threshold is not None else float("inf")

        if rate > crit:
            return Alert(
                tick=tick,
                invariant_id=self.id,
                label=self.label,
                severity=Severity.CRITICAL,
                message=f"{self.label} = {rate:.1f}% (critical threshold {crit}%)",
            )
        elif rate > warn:
            return Alert(
                tick=tick,
                invariant_id=self.id,
                label=self.label,
                severity=Severity.WARNING,
                message=f"{self.label} = {rate:.1f}% (warning threshold {warn}%)",
            )
        return None

    def check_solvency(self, row: Dict[str, Any]) -> Optional[Alert]:
        if self.type != InvariantType.SOLVENCY:
            return None
        bal = row.get(self.balance_column, 0)
        liab = row.get(self.liability_column, 0)
        # Skip when no activity (both zero)
        if bal == 0 and liab == 0:
            return None
        if bal < liab * self.multiplier:
            return Alert(
                tick=row.get("tick", 0),
                invariant_id=self.id,
                label=self.label,
                severity=self.severity,
                message=f"{self.label}: balance {bal} < liability {liab} x{self.multiplier}",
            )
        return None

    def check_max_ratio(self, row: Dict[str, Any]) -> Optional[Alert]:
        if self.type != InvariantType.MAX_RATIO:
            return None
        num = row.get(self.numerator_column, 0)
        den = row.get(self.denominator_column, 0)
        max_r = self.max_ratio if self.max_ratio is not None else float("inf")
        if den > 0 and (num / den) > max_r:
            ratio = num / den
            return Alert(
                tick=row.get("tick", 0),
                invariant_id=self.id,
                label=self.label,
                severity=self.severity,
                message=f"{self.label}: ratio {ratio:.4f} > max {max_r}",
            )
        return None


def load_invariants(path: Path) -> List[Invariant]:
    """Load invariant definitions from a JSON file."""
    if not path.exists():
        return []
    with open(path) as f:
        data = json.load(f)
    return [Invariant.from_dict(inv) for inv in data.get("invariants", [])]


def compute_tick_alerts(
    invariants: List[Invariant],
    market: List[Dict[str, Any]],
    actions: List[Dict[str, Any]],
    tick_count: int,
) -> List[Alert]:
    """Compute all alerts across all ticks.

    Returns a list of Alert objects, one per invariant violation.
    """
    # Pre-compute per-tick failure counts from actions
    tick_fail_counts: Dict[int, int] = defaultdict(int)
    tick_total_counts: Dict[int, int] = defaultdict(int)
    for act in actions:
        t = act["tick"]
        tick_total_counts[t] += 1
        if not act.get("success", True):
            tick_fail_counts[t] += 1

    alerts: List[Alert] = []
    for tick in range(tick_count):
        row = market[tick] if tick < len(market) else {}
        row = dict(row)
        row["tick"] = tick

        for inv in invariants:
            if not inv.enabled:
                continue

            if inv.type == InvariantType.RANGE:
                alert = inv.check_range(row)
                if alert:
                    alerts.append(alert)

            elif inv.type == InvariantType.THRESHOLD_HIGH:
                window = inv.window_ticks
                total = sum(tick_total_counts.get(t, 0) for t in range(max(0, tick - window + 1), tick + 1))
                failed = sum(tick_fail_counts.get(t, 0) for t in range(max(0, tick - window + 1), tick + 1))
                alert = inv.check_threshold_high(tick, total, failed)
                if alert:
                    alerts.append(alert)

            elif inv.type == InvariantType.SOLVENCY:
                alert = inv.check_solvency(row)
                if alert:
                    alerts.append(alert)

            elif inv.type == InvariantType.MAX_RATIO:
                alert = inv.check_max_ratio(row)
                if alert:
                    alerts.append(alert)

    return alerts


def get_current_tick_alerts(alerts: List[Alert], tick: int) -> List[Alert]:
    """Filter alerts to only those at a specific tick."""
    return [a for a in alerts if a.tick == tick]


def format_alert_panel(alerts: List[Alert], total_alerts: int) -> str:
    """Render the alert panel HTML for the current tick."""
    if not alerts:
        return (
            '<div class="alert-panel">\n'
            '<div class="alert-panel-header">\n'
            '<span class="alert-status">✅</span>\n'
            '<div class="alert-panel-title">All Invariants Pass</div>\n'
            '<div class="alert-count">0 active alerts</div>\n'
            '</div>\n'
            '<div style="color:#3fb950;font-size:13px">All configured invariants are within bounds for the current tick.</div>\n'
            '</div>'
        )

    critical = sum(1 for a in alerts if a.severity == Severity.CRITICAL)
    warning = sum(1 for a in alerts if a.severity == Severity.WARNING)
    icon = "🔴" if critical > 0 else "🟡"
    status_text = f"{critical} critical, {warning} warning" if critical > 0 else f"{warning} warning"

    rows = "\n".join(a.to_html() for a in alerts)
    return (
        f'<div class="alert-panel">\n'
        f'<div class="alert-panel-header">\n'
        f'<span class="alert-status">{icon}</span>\n'
        f'<div class="alert-panel-title">Invariant Alerts</div>\n'
        f'<div class="alert-count">{status_text} | {total_alerts} total across simulation</div>\n'
        f'</div>\n'
        f'{rows}\n'
        f'</div>'
    )


def format_alert_history(alerts: List[Alert]) -> str:
    """Render the alert history section HTML."""
    if not alerts:
        return (
            '<h2>⚖️ Alert History</h2>\n'
            '<div class="alert-history-empty">No alerts triggered during this simulation. All invariants passed.</div>'
        )

    rows = "\n".join(a.to_html() for a in alerts)
    return (
        f'<h2>⚖️ Alert History ({len(alerts)} total)</h2>\n'
        f'<div class="alert-history">\n'
        f'{rows}\n'
        f'</div>'
    )


def persist_alerts_js(alerts: List[Alert]) -> str:
    """Generate the JavaScript snippet for localStorage alert persistence."""
    alert_json = json.dumps([a.to_dict() for a in alerts])
    return f"""
// Alert persistence in localStorage
(function(){{
  const key = 'zeno_sim_alerts_' + location.pathname;
  const stored = localStorage.getItem(key);
  const storedAlerts = stored ? JSON.parse(stored) : [];
  // Merge with current run alerts (dedup by tick+id)
  const seen = new Set(storedAlerts.map(a => a.tick + '|' + a.id));
  for (const a of allAlerts) {{
    const k = a.tick + '|' + a.id;
    if (!seen.has(k)) {{ storedAlerts.push(a); seen.add(k); }}
  }}
  localStorage.setItem(key, JSON.stringify(storedAlerts));
  // Expose for console debugging
  window.zenoAlerts = storedAlerts;
}})();
"""
