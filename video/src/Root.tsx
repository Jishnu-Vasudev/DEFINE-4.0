import { Composition } from "remotion";
import { BunnyHopIntro } from "./BunnyHopIntro";

export const RemotionRoot: React.FC = () => (
  <Composition id="BunnyHopIntro" component={BunnyHopIntro} durationInFrames={150} fps={30} width={1920} height={1080} />
);
