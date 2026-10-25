module ecs.systems.audio;
import raylib;

import ecs.world;
import ecs.components.audio;
import ecs.components.transform;
import ecs.components.renderer.camera;

final class AudioSystem {
    private World world;

    void initialize(World world) { this.world = world; }
    void update() {
        Vector3 listener = world.get!Transform3D(world.getActiveCamera()).position;

        foreach (entity, audio, transform; world.view!(AudioSource, Transform3D)) {
            if (!audio.sound) continue;

            bool isPlaying = IsSoundPlaying(*audio.sound);
            audio.playing = isPlaying;
            SetSoundPitch(*audio.sound, audio.pitch);
            if (audio.playing) {
                // distance
                float dist = Vector3Distance(transform.position, listener);
                float volume = 1.0f - (dist / audio.maxDistance);
                volume = Clamp(volume, 0.0f, 1.0f);

                // pan
                if (audio.enablePan) {
                    Vector3 dir = Vector3Normalize(Vector3Subtract(transform.position, listener));
                    float pan = Vector3DotProduct(dir, world.get!WorldCamera(world.getActiveCamera()).right);
                    pan = Clamp(pan, -1.0f, 1.0f);
                    SetSoundPan(*audio.sound, pan);
                }

                float distanceVolume = 1.0f - (dist / audio.maxDistance);
                distanceVolume = Clamp(distanceVolume, 0.0f, 1.0f);
                float attenuation;

                if (dist <= audio.maxDistance)
                    attenuation = 1.0f;
                else if (dist >= audio.maxDistance) 
                    attenuation = 0.0f;
                else
                    attenuation = 1.0f - (dist - audio.minDistance) / (audio.maxDistance - audio.minDistance);
                
                SetSoundVolume(*audio.sound, audio.volume * attenuation);
            }

            if (audio.looped && !audio.playing) PlaySound(*audio.sound);
        }
    }
}