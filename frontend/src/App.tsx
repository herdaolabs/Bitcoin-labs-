import React, { useState } from 'react';
import { AppConfig, UserSession, showConnect } from '@stacks/connect';
import Router from './components/Router';
import Backstop from './components/Backstop';
import Streams from './components/Streams';
import CoopCredit from './components/CoopCredit';
import './App.css';

const appConfig = new AppConfig(['store_write', 'publish_data']);
export const userSession = new UserSession({ appConfig });

type Tab = 'router' | 'backstop' | 'streams' | 'credit';

export default function App() {
  const [tab, setTab] = useState<Tab>('router');
  const [authenticated, setAuthenticated] = useState(
    userSession.isUserSignedIn()
  );

  const connect = () => {
    showConnect({
      appDetails: { name: 'HER DAO Labs', icon: '/logo.png' },
      userSession,
      onFinish: () => setAuthenticated(true),
    });
  };

  const disconnect = () => {
    userSession.signUserOut();
    setAuthenticated(false);
  };

  const address = authenticated
    ? userSession.loadUserData().profile.stxAddress.testnet
    : null;

  return (
    <div className="app">
      <header className="header">
        <div className="header-left">
          <span className="logo">⬡</span>
          <span className="title">HER DAO Labs</span>
          <span className="subtitle">Bitcoin Capital Markets Lab</span>
        </div>
        <div className="header-right">
          {authenticated ? (
            <>
              <span className="address">
                {address?.slice(0, 8)}...{address?.slice(-4)}
              </span>
              <button className="btn-outline" onClick={disconnect}>
                Disconnect
              </button>
            </>
          ) : (
            <button className="btn-primary" onClick={connect}>
              Connect Wallet
            </button>
          )}
        </div>
      </header>

      <nav className="tabs">
        {(['router', 'backstop', 'streams', 'credit'] as Tab[]).map((t) => (
          <button
            key={t}
            className={`tab ${tab === t ? 'active' : ''}`}
            onClick={() => setTab(t)}
          >
            {t === 'router' && 'sBTC Router'}
            {t === 'backstop' && 'Liquidity Backstop'}
            {t === 'streams' && 'sBTC Streams'}
            {t === 'credit' && 'CoopCredit'}
          </button>
        ))}
      </nav>

      <main className="main">
        {!authenticated && (
          <div className="notice">
            Connect your Hiro Wallet to interact with testnet contracts.
          </div>
        )}
        {tab === 'router' && <Router authenticated={authenticated} />}
        {tab === 'backstop' && <Backstop authenticated={authenticated} />}
        {tab === 'streams' && <Streams authenticated={authenticated} />}
        {tab === 'credit' && <CoopCredit authenticated={authenticated} />}
      </main>

      <footer className="footer">
        HER DAO Labs · Open-source Bitcoin DeFi on Stacks ·{' '}
        <a href="https://github.com/herdaolabs/Bitcoin-labs-" target="_blank" rel="noreferrer">
          GitHub
        </a>
      </footer>
    </div>
  );
}
