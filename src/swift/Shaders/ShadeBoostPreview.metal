// ShadeBoostPreview.metal — SwiftUI color-effect mirror of the GS renderer's
// ps_shadeboost fragment shader (see pcsx2/GS/Renderers/Metal/convert.metal),
// so the Settings preview shows exactly what the emulator would render.
// AYS2: additive (seam) — new file, not present upstream.
// SPDX-License-Identifier: GPL-3.0+

#include <metal_stdlib>
using namespace metal;

// Mirrors ps_shadeboost's math verbatim (including its lack of clamping —
// extreme slider values can go out of [0,1] in the real renderer too, and
// the preview should show that faithfully rather than hide it).
[[ stitchable ]]
half4 shadeBoost(float2 position, half4 color, float brightness, float contrast, float saturation, float gamma)
{
    const float3 avgLumin = float3(0.5, 0.5, 0.5);
    const float3 lumCoeff = float3(0.2125, 0.7154, 0.0721);

    float3 brtColor = float3(color.rgb) * brightness;
    float dotIntensity = dot(brtColor, lumCoeff);
    float3 intensity = float3(dotIntensity);
    float3 satColor = mix(intensity, brtColor, saturation);
    float3 conColor = mix(avgLumin, satColor, contrast);
    float3 csb = pow(conColor, float3(1.0 / gamma));

    return half4(half3(csb), color.a);
}
