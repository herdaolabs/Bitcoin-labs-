import React, { useState } from 'react';
import { callContract } from '../utils/stacks';

interface Props { authenticated: boolean }

export default function Router({ authenticated }: Props) {
  const [depositAmt, setDepositAmt] = useState('');
  const [withdrawAmt, setWithdrawAmt] = useState('');
  const [protocolName, setProtocolName] = useState('');
  const [protocolAddr, setProtocolAddr] = useState('');
  const [weight, setWeight] = useState('');
  const [status, setStatus] = useState<{msg: string; type: string} | null>(null);
  const [balance, setBalance] = useState(0);

  const deposit = async () => {
    if (!depositAmt) return;
    setStatus({ msg: 'Broadcasting deposit...', type: 'pending' });
    try {
      await callContract('sbtc-router', 'deposit', [parseInt(depositAmt)]);
      setBalance(b => b + parseInt(depositAmt));
      setStatus({ msg: `✓ Deposited ${depositAmt} sats`, type: 'success' });
      setDepositAmt('');
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const withdraw = async () => {
    if (!withdrawAmt) return;
    setStatus({ msg: 'Broadcasting withdrawal...', type: 'pending' });
    try {
      await callContract('sbtc-router', 'withdraw', [parseInt(withdrawAmt)]);
      setBalance(b => Math.max(0, b - parseInt(withdrawAmt)));
      setStatus({ msg: `✓ Withdrew ${withdrawAmt} sats`, type: 'success' });
      setWithdrawAmt('');
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const registerProtocol = async () => {
    if (!protocolName || !protocolAddr || !weight) return;
    setStatus({ msg: 'Registering protocol...', type: 'pending' });
    try {
      await callContract('sbtc-router', 'register-protocol', [
        protocolName, protocolAddr, parseInt(weight)
      ]);
      setStatus({ msg: `✓ Protocol "${protocolName}" registered at ${weight} bps`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  return (
    <div>
      <div className="balance-row">
        <div className="balance-item">
          <div className="bal-label">Your Deposit</div>
          <div className="bal-value">{balance.toLocaleString()} sats</div>
        </div>
        <div className="balance-item">
          <div className="bal-label">Network</div>
          <div className="bal-value">Testnet</div>
        </div>
      </div>

      <div className="card">
        <h3>Deposit sBTC</h3>
        <p>Deposit sBTC into the router for protocol allocation.</p>
        <div className="form-row">
          <div className="field">
            <label>Amount (sats)</label>
            <input value={depositAmt} onChange={e => setDepositAmt(e.target.value)}
              type="number" placeholder="1000000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={deposit}>
          Deposit
        </button>
      </div>

      <div className="card">
        <h3>Withdraw sBTC</h3>
        <p>Reclaim your deposited sBTC from the router.</p>
        <div className="form-row">
          <div className="field">
            <label>Amount (sats)</label>
            <input value={withdrawAmt} onChange={e => setWithdrawAmt(e.target.value)}
              type="number" placeholder="500000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={withdraw}>
          Withdraw
        </button>
      </div>

      <div className="card">
        <h3>Register Protocol (Owner)</h3>
        <p>Add a protocol with an allocation weight in basis points (10000 = 100%).</p>
        <div className="form-row">
          <div className="field">
            <label>Protocol Name</label>
            <input value={protocolName} onChange={e => setProtocolName(e.target.value)} placeholder="alex-dex" />
          </div>
          <div className="field">
            <label>Contract Address</label>
            <input value={protocolAddr} onChange={e => setProtocolAddr(e.target.value)} placeholder="ST1PQH..." />
          </div>
          <div className="field">
            <label>Weight (bps)</label>
            <input value={weight} onChange={e => setWeight(e.target.value)} type="number" placeholder="5000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={registerProtocol}>
          Register Protocol
        </button>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}
