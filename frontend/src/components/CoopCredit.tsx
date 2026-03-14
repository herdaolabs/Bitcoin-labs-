import React, { useState } from 'react';
import { callContract } from '../utils/stacks';

interface Props { authenticated: boolean }

export default function CoopCredit({ authenticated }: Props) {
  const [borrowAmt, setBorrowAmt] = useState('');
  const [loanId, setLoanId] = useState('');
  const [vouchAddr, setVouchAddr] = useState('');
  const [vouchAmt, setVouchAmt] = useState('');
  const [status, setStatus] = useState<{msg: string; type: string} | null>(null);
  const [score, setScore] = useState<number | null>(null);
  const [member, setMember] = useState(false);

  const join = async () => {
    setStatus({ msg: 'Joining cooperative...', type: 'pending' });
    try {
      await callContract('coop-credit', 'join-cooperative', []);
      setMember(true);
      setScore(100);
      setStatus({ msg: '✓ Joined cooperative — starting score: 100', type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const borrow = async () => {
    if (!borrowAmt) return;
    setStatus({ msg: 'Requesting loan...', type: 'pending' });
    try {
      await callContract('coop-credit', 'borrow', [parseInt(borrowAmt)]);
      setStatus({ msg: `✓ Loan of ${borrowAmt} sats approved`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const repay = async () => {
    if (!loanId) return;
    setStatus({ msg: `Repaying loan #${loanId}...`, type: 'pending' });
    try {
      await callContract('coop-credit', 'repay-loan', [parseInt(loanId)]);
      if (score !== null) setScore(s => (s || 0) + 10);
      setStatus({ msg: `✓ Loan #${loanId} repaid — score +10`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const vouch = async () => {
    if (!vouchAddr || !vouchAmt) return;
    setStatus({ msg: 'Submitting vouch...', type: 'pending' });
    try {
      await callContract('coop-credit', 'vouch-for', [vouchAddr, parseInt(vouchAmt)]);
      setStatus({ msg: `✓ Vouched for ${vouchAddr.slice(0, 10)}...`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  return (
    <div>
      <div className="balance-row">
        <div className="balance-item">
          <div className="bal-label">Credit Score</div>
          <div className="bal-value">{score !== null ? score : '—'}</div>
        </div>
        <div className="balance-item">
          <div className="bal-label">Borrow Limit</div>
          <div className="bal-value">{score !== null ? `${(score * 1000).toLocaleString()} sats` : '—'}</div>
        </div>
        <div className="balance-item">
          <div className="bal-label">Member</div>
          <div className="bal-value">{member ? 'Yes' : 'No'}</div>
        </div>
      </div>

      {!member && (
        <div className="card">
          <h3>Join the Cooperative</h3>
          <p>Join to receive a base credit score of 100. Build score through repayments and vouches.</p>
          <button className="btn-secondary" disabled={!authenticated} onClick={join}>
            Join Cooperative
          </button>
        </div>
      )}

      <div className="card">
        <h3>Borrow</h3>
        <p>Request a loan up to your credit limit (score × 1000 sats).</p>
        <div className="form-row">
          <div className="field">
            <label>Amount (sats)</label>
            <input value={borrowAmt} onChange={e => setBorrowAmt(e.target.value)}
              type="number" placeholder="50000" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated || !member} onClick={borrow}>
          Request Loan
        </button>
      </div>

      <div className="card">
        <h3>Repay Loan</h3>
        <p>Repay an active loan and earn +10 credit score.</p>
        <div className="form-row">
          <div className="field">
            <label>Loan ID</label>
            <input value={loanId} onChange={e => setLoanId(e.target.value)} type="number" placeholder="0" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated || !member} onClick={repay}>
          Repay
        </button>
      </div>

      <div className="card">
        <h3>Vouch for a Member</h3>
        <p>Vouch for another member to increase their credit score by 5.</p>
        <div className="form-row">
          <div className="field">
            <label>Member Address</label>
            <input value={vouchAddr} onChange={e => setVouchAddr(e.target.value)} placeholder="ST1PQH..." />
          </div>
          <div className="field">
            <label>Vouch Amount</label>
            <input value={vouchAmt} onChange={e => setVouchAmt(e.target.value)} type="number" placeholder="10" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated || !member} onClick={vouch}>
          Vouch
        </button>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}
