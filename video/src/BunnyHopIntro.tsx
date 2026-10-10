import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";

// 5 s brand intro in the app's ember palette: logo blooms in, name rises, tagline fades.
export const BunnyHopIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const logo = spring({ frame, fps, config: { damping: 12, stiffness: 90 } });
  const glow = interpolate(frame, [10, 60], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const word = spring({ frame: frame - 25, fps, config: { damping: 18 } });
  const tag = interpolate(frame, [55, 80], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <AbsoluteFill
      style={{
        background: "radial-gradient(1200px 700px at 70% -10%, rgba(232,93,24,.28), transparent 60%), #1b110b",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: "Segoe UI, system-ui, sans-serif",
        color: "#fff6ea",
      }}
    >
      <Img
        src={staticFile("logo.png")}
        style={{
          width: 300,
          height: 300,
          borderRadius: "50%",
          transform: `scale(${0.6 + 0.4 * logo})`,
          opacity: logo,
          boxShadow: `0 0 ${60 + 80 * glow}px rgba(232,93,24,${0.55 * glow})`,
        }}
      />
      <div style={{ fontSize: 120, fontWeight: 800, letterSpacing: -3, marginTop: 50, transform: `translateY(${40 * (1 - word)}px)`, opacity: word }}>
        Bunny Hop
      </div>
      <div style={{ fontSize: 40, color: "#c4aa94", marginTop: 10, opacity: tag }}>Your team, one press away</div>
    </AbsoluteFill>
  );
};
