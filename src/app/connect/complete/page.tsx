export default function ConnectCompletePage() {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <section style={{ maxWidth: 420, textAlign: "center" }}>
        <h1>Bank account connected!</h1>
        <p>You can now cash out your BEAM balance.</p>
        <a
          href="beamwallet://connect-complete"
          style={{
            display: "inline-block",
            marginTop: 16,
            padding: "12px 18px",
            borderRadius: 10,
            background: "#16a34a",
            color: "white",
            textDecoration: "none",
            fontWeight: 600,
          }}
        >
          Return to BEAM Wallet
        </a>
      </section>
    </main>
  );
}
