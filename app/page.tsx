export default function Home() {
  return (
    <main className="godot-shell">
      <div className="godot-bar">
        <div>
          <b>THE SHATTERED KEEP</b>
          <span>Godot 4.7 · Mooncrypt combat build</span>
        </div>
        <div className="godot-controls">
          WASD move · Space attack · Q shield burst · Shift dash
        </div>
      </div>
      <iframe
        className="godot-game"
        src="/godot/index.html"
        title="The Shattered Keep — Godot vertical slice"
        allow="autoplay; fullscreen; gamepad"
      />
    </main>
  );
}
