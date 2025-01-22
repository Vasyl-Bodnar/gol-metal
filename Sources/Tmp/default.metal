#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertex_main(constant VertexIn *vert [[buffer(0)]],
                             uint id [[vertex_id]]) { 
    VertexOut out;
    out.position = vert[id].position;
    out.color = vert[id].color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant uint *size [[buffer(0)]]) {
    return in.color * clamp(float4(in.position[0]/size[0], in.position[1]/size[0], 0.0, 1.0), 0.3, 1.0);
}

kernel void game(constant bool *in [[buffer(0)]],
                 device bool *out [[buffer(1)]],
                 device VertexIn *vert [[buffer(2)]],
                 constant uint &size [[buffer(3)]],
                 uint index [[thread_position_in_grid]]) {
    uint alive = in[index - 1] + in[index + 1] 
                 + in[index - size] + in[index + size]
                 + in[index - 1 - size] + in[index - 1 + size]
                 + in[index + 1 - size] + in[index + 1 + size];
    out[index] = alive == 3 || (in[index] && alive == 2);
    vert[index * 4].color = float4(out[index], out[index], out[index], 1);
    vert[index * 4 + 1].color = float4(out[index], out[index], out[index], 1);
    vert[index * 4 + 2].color = float4(out[index], out[index], out[index], 1);
    vert[index * 4 + 3].color = float4(out[index], out[index], out[index], 1);
}
