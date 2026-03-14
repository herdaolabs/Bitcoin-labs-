import React, { useState } from 'react';
import { callContract } from '../utils/stacks';

interface Props { authenticated: boolean }

export default function Streams({ authenticated }: Props) {
  const [recipient, setRecipient] = useState('');
  const [deposit, setDeposit] = useState('');
  const [rate, setRate] = useState('');
  const [duration, setDuration] = useState('');
  const [streamId, setStreamId] = useState('');
  const [status, setStatus] = useState<{msg: string; type: string} | null>(null);
  const [streams, setStreams] = useState<{id: number; recipient: string; rate: string}[]>([]);

  const createStream = async () => {
    if (!recipient || !deposit || !rate || !duration) return;
    setStatus({ msg: 'Creating stream...', type: 'pending' });
    try {
      await callContract('sbtc-streams', 'create-stream', [
        recipient, parseInt(deposit), parseInt(rate), parseInt(duration)
      ]);
      const newId = streams.length;
      setStreams(s => [...s, { id: newId, recipient, rate: `${rate} sats/block` }]);
      setStatus({ msg: `✓ Stream #${newId} created`, type: 'success' });
      setRecipient(''); setDeposit(''); setRate(''); setDuration('');
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const claim = async () => {
    if (!streamId) return;
    setStatus({ msg: `Claiming from stream #${streamId}...`, type: 'pending' });
    try {
      await callContract('sbtc-streams', 'claim', [parseInt(streamId)]);
      setStatus({ msg: `✓ Claimed from stream #${streamId}`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  const cancelStream = async () => {
    if (!streamId) return;
    setStatus({ msg: `Cancelling stream #${streamId}...`, type: 'pending' });
    try {
      await callContract('sbtc-streams', 'cancel-stream', [parseInt(streamId)]);
      setStatus({ msg: `✓ Stream #${streamId} cancelled`, type: 'success' });
    } catch (e: any) {
      setStatus({ msg: `Error: ${e.message}`, type: 'error' });
    }
  };

  return (
    <div>
      <div className="balance-row">
        <div className="balance-item">
          <div className="bal-label">Active Streams</div>
          <div className="bal-value">{streams.length}</div>
        </div>
        <div className="balance-item">
          <div className="bal-label">Block Time</div>
          <div className="bal-value">~10 min</div>
        </div>
      </div>

      <div className="card">
        <h3>Create Stream</h3>
        <p>Lock sBTC and stream it block-by-block to a recipient.</p>
        <div className="form-row">
          <div className="field">
            <label>Recipient Address</label>
            <input value={recipient} onChange={e => setRecipient(e.target.value)} placeholder="ST1PQH..." />
          </div>
          <div className="field">
            <label>Total Deposit (sats)</label>
            <input value={deposit} onChange={e => setDeposit(e.target.value)} type="number" placeholder="10000" />
          </div>
          <div className="field">
            <label>Rate (sats/block)</label>
            <input value={rate} onChange={e => setRate(e.target.value)} type="number" placeholder="100" />
          </div>
          <div className="field">
            <label>Duration (blocks)</label>
            <input value={duration} onChange={e => setDuration(e.target.value)} type="number" placeholder="100" />
          </div>
        </div>
        <button className="btn-secondary" disabled={!authenticated} onClick={createStream}>
          Create Stream
        </button>
      </div>

      <div className="card">
        <h3>Claim / Cancel Stream</h3>
        <p>Recipients claim accrued sBTC. Senders can cancel early and recover unearned funds.</p>
        <div className="form-row">
          <div className="field">
            <label>Stream ID</label>
            <input value={streamId} onChange={e => setStreamId(e.target.value)} type="number" placeholder="0" />
          </div>
        </div>
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <button className="btn-secondary" disabled={!authenticated} onClick={claim}>
            Claim (Recipient)
          </button>
          <button className="btn-secondary" disabled={!authenticated} onClick={cancelStream}>
            Cancel (Sender)
          </button>
        </div>
      </div>

      {status && <div className={`status ${status.type}`}>{status.msg}</div>}
    </div>
  );
}
