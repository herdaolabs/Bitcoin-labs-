import React, { useState } from 'react';
import { callContract } from '../utils/stacks';

interface Props { authenticated: boolean }

export default function Backstop({ authenticated }: Props) {
  const [liquidityAmt, setLiquidityAmt] = useState('');
  const [withdrawShares, setWithdrawShares] = useState('');
  const [protocolAddr, setProtocolAddr] = useState('');
  const [protocolName, setProtocolName] = useState('');
  const [coverageLimit, setCoverageLimit] = useState('');
  const [status, setStatus] = useState<{msg: string; type: string} | null>(null);
  const [shares, setShares] = useState(0);

  const provideLiquidity = async () => {
    if (!liquidityAmt) return;
    setStatus({ msg: 'Providing liquidity...', type: 'pending' });
    try {
      await callContract('sbtc-backstop', 'provide-liquidity', [parseInt(liquidityAmt)]);
      setShares(s => s + parseInt(liquidityAmt));
      setStatus({ msg: `✓ Provided ${liquidityAmt} sats — shares minted`, type: 'success' });
      setLiquidityAmt('');
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const withdrawLiquidity = async () => {
    if (!withdrawShares) return;
    setStatus({ msg: 'Withdrawing...', type: 'pending' });
    try {
      await callContract('sbtc-backstop', 'withdraw-liquidity', [parseInt(withdrawShares)]);
      setShares(s => Math.max(0, s - parseInt(withdrawShares)));
      setStatus({ msg: `✓ Burned ${withdrawShares} shares`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const registerProtocol = async () => {
    if (!protocolAddr || !protocolName || !coverageLimit) return;
    setStatus({ msg: 'Registering protocol...', type: 'pending' });
    try {
      await callContract('sbtc-backstop', 'register-protocol', [
        protocolAddr, protocolName, parseInt(coverageLimit)
      ]);
      setStatus({ msg: `✓ Protocol registered with ${coverageLimit} sat limit`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  return (
    <div>
      <div className="balance-row">
        <div className="balance-item">
          <div className="bal-label">Your Shares</div>
          <div className="bal-value">{shares.toLocaleString()}</div>
        </div>
        <div className="balance-item">
          <div className="bal-label">Draw Fee</div>
          <div className="bal-value">0.5%</div>
        </div>
      </div>

      <div className="card">
        <h3>Provide Backstop Liquidity</h3>
        <p>Deposit sBTC into the shared reserve. Receive shares proportional to your contribution.</p>
        <div className="form-row">
          <div className="field">
            <label>Amount (sats)</label>
            <input value={liquidityAmt} onChange={e => setLiquidityAmt(e.target.value)}
              type="number" placeholder="1000000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={provideLiquidity}>
          Provide Liquidity
        </button>
      </div>

      <div className="card">
        <h3>Withdraw Liquidity</h3>
        <p>Burn shares to reclaim proportional sBTC including accrued fees.</p>
        <div className="form-row">
          <div className="field">
            <label>Shares to Burn</label>
            <input value={withdrawShares} onChange={e => setWithdrawShares(e.target.value)}
              type="number" placeholder="500000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={withdrawLiquidity}>
          Withdraw
        </button>
      </div>

      <div className="card">
        <h3>Register Protocol (Owner)</h3>
        <p>Authorize a protocol to draw coverage with a maximum draw limit.</p>
        <div className="form-row">
          <div className="field">
            <label>Protocol Address</label>
            <input value={protocolAddr} onChange={e => setProtocolAddr(e.target.value)} placeholder="ST1PQH..." />
          </div>
          <div className="field">
            <label>Name</label>
            <input value={protocolName} onChange={e => setProtocolName(e.target.value)} placeholder="my-protocol" />
          </div>
          <div className="field">
            <label>Coverage Limit (sats)</label>
            <input value={coverageLimit} onChange={e => setCoverageLimit(e.target.value)} type="number" placeholder="500000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={registerProtocol}>
          Register
        </button>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}
