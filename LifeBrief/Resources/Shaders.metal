#include <metal_stdlib>
using namespace metal;

/// A stitchable distortion shader that simulates a 3D glass lens / water droplet refraction.
/// - position: The current pixel coordinates in user space.
/// - center: The center coordinates of the droplet.
/// - radius: The radius of the droplet.
/// - refractionStrength: The strength of the convex lens magnification warp (e.g. 0.35).
[[stitchable]] float2 raindropDistortion(float2 position, float2 center, float radius, float refractionStrength) {
    float2 delta = position - center;
    float dist = length(delta);

    if (dist < radius && radius > 0.0) {
        // Normalized distance from center (0.0 at center, 1.0 at outer rim)
        float normalizedDist = dist / radius;

        // Spherical lens dome factor: z = sqrt(1.0 - normDist^2)
        float dome = sqrt(max(1.0 - normalizedDist * normalizedDist, 0.0));

        // Smooth convex magnification profile that tapers to 0 at the boundary rim
        float warpFactor = (1.0 - normalizedDist * normalizedDist) * refractionStrength * (0.6 + 0.4 * dome);

        // Pulling the sampled coordinates toward the center magnifies the content beneath
        float2 warpedPosition = center + delta * (1.0 - warpFactor);
        return warpedPosition;
    }

    return position;
}
