import { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import "./App.css";

interface ExplainResult {
  term: string;
  meaning: string;
  usage: string[];
  examples: string[];
  pronunciation: string;
}

interface TextChunk {
  ts_ms: number;
  source: "Screen" | "Audio";
  text: string;
  confidence: number | null;
}

interface Context {
  screen: TextChunk[];
  audio: TextChunk[];
}

function App() {
  const [query, setQuery] = useState("");
  const [result, setResult] = useState<ExplainResult | null>(null);
  const [context, setContext] = useState<Context | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showDebug, setShowDebug] = useState(true); // Show by default for debugging

  // Auto-refresh context every 2 seconds when debug panel is visible
  useEffect(() => {
    if (showDebug) {
      loadContext();
      const interval = setInterval(loadContext, 2000);
      return () => clearInterval(interval);
    }
  }, [showDebug]);

  async function handleAskExplain(e: React.FormEvent) {
    e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError(null);

    try {
      const res = await invoke<ExplainResult>("ask_explain", { query });
      setResult(res);
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  }

  async function handleSpeak(text: string) {
    try {
      await invoke("tts_speak", { text });
    } catch (err) {
      console.error("TTS error:", err);
    }
  }

  async function loadContext() {
    try {
      const ctx = await invoke<Context>("get_recent_context");
      setContext(ctx);
    } catch (err) {
      console.error("Failed to load context:", err);
    }
  }

  async function addMockData() {
    try {
      await invoke("add_mock_data");
      await loadContext();
    } catch (err) {
      console.error("Failed to add mock data:", err);
    }
  }

  return (
    <main className="container">
      <h1>🎓 AI English Assistant</h1>
      <p className="subtitle">Ask about any English word or phrase</p>

      <form className="query-form" onSubmit={handleAskExplain}>
        <input
          id="query-input"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="What does 'ephemeral' mean?"
          autoFocus
          disabled={loading}
        />
        <button type="submit" disabled={loading || !query.trim()}>
          {loading ? "..." : "Explain"}
        </button>
      </form>

      {error && <div className="error">{error}</div>}

      {result && (
        <div className="result-card">
          <div className="result-header">
            <h2>{result.term}</h2>
            <button
              className="speak-btn"
              onClick={() => handleSpeak(result.term)}
              title="Pronounce"
            >
              🔊
            </button>
          </div>

          <div className="pronunciation">{result.pronunciation}</div>

          <div className="section">
            <h3>Meaning</h3>
            <p>{result.meaning}</p>
          </div>

          <div className="section">
            <h3>Usage</h3>
            <ul>
              {result.usage.map((u, i) => (
                <li key={i}>{u}</li>
              ))}
            </ul>
          </div>

          <div className="section">
            <h3>Examples</h3>
            <ul>
              {result.examples.map((ex, i) => (
                <li key={i}>{ex}</li>
              ))}
            </ul>
          </div>

          <button
            className="speak-btn full-width"
            onClick={() => handleSpeak(result.meaning)}
          >
            🔊 Read Explanation
          </button>
        </div>
      )}

      <div className="debug-section">
        <button
          className="debug-toggle"
          onClick={() => {
            setShowDebug(!showDebug);
            if (!showDebug) loadContext();
          }}
        >
          {showDebug ? "Hide" : "Show"} Debug Context
        </button>

        {showDebug && (
          <div className="debug-panel">
            <button onClick={addMockData} className="mock-btn">
              Add Mock Data
            </button>
            <button onClick={loadContext} className="refresh-btn">
              Refresh
            </button>

            {context && (
              <div className="context-display">
                <div>
                  <h4>Screen Buffer ({context.screen.length} chunks)</h4>
                  {context.screen.map((c, i) => (
                    <div key={i} className="chunk">
                      <span className="chunk-time">
                        {new Date(c.ts_ms).toLocaleTimeString()}
                      </span>
                      <span className="chunk-text">{c.text}</span>
                    </div>
                  ))}
                </div>

                <div>
                  <h4>Audio Buffer ({context.audio.length} chunks)</h4>
                  {context.audio.map((c, i) => (
                    <div key={i} className="chunk">
                      <span className="chunk-time">
                        {new Date(c.ts_ms).toLocaleTimeString()}
                      </span>
                      <span className="chunk-text">{c.text}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </main>
  );
}

export default App;
