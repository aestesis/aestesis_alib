//
//  default.metal
//  Alib
//
//  Created by renan jegouzo on 20/03/2016.
//  Copyright © 2016 aestesis. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct Uniforms
{
    float4x4 matrix;
};
struct Uniforms3d
{
    float4x4 view;
    float4x4 world;
    float3 eye;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
constant half3 zero = half3(0,0,0);
constant half3 one = half3(1,1,1);
constant half3 two = one * 2.0;
constant half e = 1e-10;
constant float pi = 3.14159265358979323846264;
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
half mixColorBurn(half a, half b);
half mixColorDodge(half a, half b);
half mixHardLight(half a, half b);
half mixOverlay(half a, half b);
half mixLinearBurn(half a, half b, float mix);
half mixLinearDodge(half a, half b);
half mixLinearLight(half a, half b);
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
half mixColorBurn(half a, half b) {
    return 1.0-(1.0-a)/(b+e);
}
half mixColorDodge(half a, half b) {
    return a/(1.0+e-b);
}
half mixHardLight(half a, half b) {
    if(b<0.5)
        return 2.0*a*b;
    else
        return 1.0-2.0*(1.0-a)*(1.0-b);
}
half mixOverlay(half a, half b) {
    if(a<0.5)
        return 2.0*a*b;
    else
        return 1.0-2.0*(1.0-a)*(1.0-b);
}
half mixLinearBurn(half a, half b, float mix) {
    return a+(b-1.0)*mix;
}
half mixLinearDodge(half a, half b) {
    return a+b;
}
half mixLinearLight(half a, half b) {
    if(b<0.5)
        return a+2.0*a*b;
    else
        return a+2.0*(b-a)*(1.0-a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
half3 rgb2hsv(half3 c) {
    const half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 p = mix(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
    half4 q = mix(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
half3 hsv2rgb(half3 c) {
    const half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
half brightness(half3 rgb) {
    // sqrt( .299 R² + .587 G² + .114 B² )
    const half3 K = half3(0.299,0.587,0.114);
    half3 v = rgb*rgb*K;
    return v.x+v.y+v.z;
}
half3 brightness3(half3 rgb) {
    half b = brightness(rgb);
    return half3(b,b,b);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct InstanceIn {
    float4x4 matrix;
    float4 color;
};
struct ColorVerticeIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};
struct ColorVertice {
    float4 position [[position]];
    half4 color;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex ColorVertice colorFuncVertex(const device ColorVerticeIn *vin [[buffer(0)]],
                                    constant Uniforms &u [[buffer(1)]],
                                    uint vid [[vertex_id]]){
    ColorVertice vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.color = half4(vin[vid].color);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 colorFuncFragment(ColorVertice v [[stage_in]]) {
    return v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//#if PROGBLENDING
fragment half4 colorBlendMultiply(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = cb.rgb * co.rgb;
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendScreen(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = one-(one-cb.rgb)*(one-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendOverlay(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  half3(mixOverlay(cb.r,co.r),mixOverlay(cb.g,co.g),mixOverlay(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendSoftLight(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = (one-two*co.rgb)*cb.rgb*cb.rgb+two*co.rgb*cb.rgb;
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendLighten(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = max(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendDarken(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = min(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendAverage(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = (cb.rgb + co.rgb) * 0.5;
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendSubstract(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    return half4(cb.rgb+(co.rgb-one)*opa,max(opa,cb.a));
}
fragment half4 colorBlendDifference(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    return half4(abs(cb.rgb-co.rgb*opa),max(opa,cb.a));
}
fragment half4 colorBlendNegation(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = one-abs(one-cb.rgb-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendColorDodge(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  min(one,half3(mixColorDodge(cb.r,co.r),mixColorDodge(cb.g,co.g),mixColorDodge(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendColorBurn(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  max(zero,half3(mixColorBurn(cb.r,co.r),mixColorBurn(cb.g,co.g),mixColorBurn(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendHardLight(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  half3(mixHardLight(cb.r,co.r),mixHardLight(cb.g,co.g),mixHardLight(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendLinearLight(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  half3(mixLinearLight(cb.r,co.r),mixLinearLight(cb.g,co.g),mixLinearLight(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendLinearBurn(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend =  half3(mixLinearBurn(cb.r,co.r,opa),mixLinearBurn(cb.g,co.g,opa),mixLinearBurn(cb.b,co.b,opa));
    return half4(blend,max(opa,cb.a));
}
fragment half4 colorBlendReflect(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = cb.rgb*cb.rgb/(half3(1.01,1.01,1.01)-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendGlow(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = co.rgb*co.rgb/(half3(1.01,1.01,1.01)-cb.rgb);
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendPhoenix(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = min(cb.rgb,co.rgb)+max(cb.rgb,co.rgb)-one;
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
fragment half4 colorBlendExclusion(ColorVertice v [[stage_in]], half4 cb [[color(0)]])
{
    half3 co = v.color.rgb;
    half opa = v.color.a;
    half3 blend = cb.rgb+co.rgb-2.0*cb.rgb*co.rgb;
    return half4(mix(cb.rgb,blend,opa),max(opa,cb.a));
}
//#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct TextureVerticeIn
{
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 uv [[attribute(2)]];
};
struct TextureVertice
{
    float4 position [[position]];
    half4 color;
    float2 uv;
};
struct TextureVertice_float
{
    float4 position [[position]];
    float4 color;
    float2 uv;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct TextureMaskVerticeIn
{
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 uv [[attribute(2)]];
    float2 uvmask [[attribute(3)]];
};
struct TextureMaskVertice
{
    float4 position [[position]];
    half4 color;
    float2 uv;
    float2 uvmask;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex TextureVertice textureFuncVertex(const device TextureVerticeIn *vin [[buffer(0)]],
                                        constant Uniforms &u [[buffer(1)]],
                                        uint vid [[vertex_id]]) {
    TextureVertice vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.uv = vin[vid].uv;
    vout.color = half4(vin[vid].color);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex TextureVertice_float textureFuncVertex_float(const device TextureVerticeIn *vin [[buffer(0)]],
                                        constant Uniforms &u [[buffer(1)]],
                                        uint vid [[vertex_id]]) {
    TextureVertice_float vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.uv = vin[vid].uv;
    vout.color = vin[vid].color;
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex TextureMaskVertice textureBitmapMaskFuncVertex(const device TextureMaskVerticeIn *vin [[buffer(0)]],constant Uniforms &u [[buffer(1)]],uint vid [[vertex_id]])
{
    TextureMaskVertice vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.uv = vin[vid].uv;
    vout.uvmask = vin[vid].uvmask;
    vout.color = half4(vin[vid].color);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct GenerateLutHsvDecal {
    float size;
    float3 decal;
};
fragment half4 generateLutHsvDecal(TextureVertice v [[stage_in]], constant GenerateLutHsvDecal &params[[buffer(0)]]) {
    half d = v.uv.x * params.size;
    half3 c = half3(fract(d),floor(d)/params.size,v.uv.y);
    half3 h = rgb2hsv(c.rgb)+half3(params.decal);
    h.x = fract(h.x);
    h.yz = saturate(h.yz);
    return half4(hsv2rgb(h),1)*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureLutFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture3d<half> lut [[texture(1)]], sampler s [[sampler(0)]])
{
    constexpr sampler ss = sampler(mag_filter::linear, min_filter::linear, mip_filter::linear, address::clamp_to_edge);
    half4 c=t.sample(s,v.uv).rgba;
    half4 l=lut.sample(ss,float3(c.rgb));
    return half4(l.rgb,c.a)*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    half4 c=t.sample(s,v.uv).rgba;
    return c*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment float4 textureFuncFragment_float(TextureVertice_float v [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]])
{
    float4 c = t.sample(s,v.uv);
    return c*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureFuncFragmentColor(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    half c=t.sample(s,v.uv).r;
    return half4(v.color.rgb,c*v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureFuncFragmentSetAlpha(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    half c=t.sample(s,v.uv).r;
    return half4(0,0,0,c*v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureMaskFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> mask [[texture(1)]], sampler s [[sampler(0)]])
{
    half4 c = t.sample(s,v.uv);
    half4 m = mask.sample(s,v.uv);
    return half4(c.rgb*v.color.rgb,m.a*m.r*c.a*v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureBitmapMaskFragment(TextureMaskVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> mask [[texture(1)]], sampler s [[sampler(0)]])
{
    half4 c = t.sample(s,v.uv);
    half4 m = mask.sample(s,v.uvmask);
    return half4(c.rgb*v.color.rgb,m.a*m.r*c.a*v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureGradientMaskFragment(TextureMaskVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> mask [[texture(1)]], texture2d<half> gradient [[texture(2)]], sampler s [[sampler(0)]])
{
    constexpr sampler ss(coord::normalized,s_address::clamp_to_edge,t_address::clamp_to_edge,filter::linear);
    half4 cs = t.sample(s,v.uv).rgba;
    float ls = cs.r*0.3333+cs.g*0.3333+cs.b*0.3333;
    half4 cg = gradient.sample(ss,float2(ls,0)).rgba;
    half4 c = mix(cs,cg,v.color.a);
    half4 m = mask.sample(ss,v.uvmask);
    return half4(c.rgb*v.color.rgb,m.a*m.r*c.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureLuma(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    half4 c = t.sample(s,v.uv);
    return half4(brightness3(c.rgb),c.a) * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//#if PROGBLENDING
fragment half4 textureFuncFragmentMulAlpha(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 fbc [[color(0)]] )
{
    half c=t.sample(s,v.uv).r;
    return half4(0,0,0,fbc.a*c*v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 textureBlendMultiply(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = cb.rgb * co.rgb;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendMultiplyLuma(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = brightness(c.rgb) * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = cb.rgb * co.rgb;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendScreen(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = one-(one-cb.rgb)*(one-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendOverlay(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend =  half3(mixOverlay(cb.r,co.r),mixOverlay(cb.g,co.g),mixOverlay(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendSoftLight(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = (one-two*co.rgb)*cb.rgb*cb.rgb+two*co.rgb*cb.rgb;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendLighten(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = max(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendDarken(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = min(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendAverage(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = (cb.rgb + co.rgb) * 0.5;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendSubstract(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    return half4(cb.rgb+(co.rgb-one)*opa,max(c.a,cb.a));
}
fragment half4 textureBlendDifference(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    return half4(abs(cb.rgb-co.rgb*opa),max(c.a,cb.a));
}
fragment half4 textureBlendNegation(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = one-abs(one-cb.rgb-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendColorDodge(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend =  min(one,half3(mixColorDodge(cb.r,co.r),mixColorDodge(cb.g,co.g),mixColorDodge(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendColorBurn(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend =  max(zero,half3(mixColorBurn(cb.r,co.r),mixColorBurn(cb.g,co.g),mixColorBurn(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendHardLight(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend =  half3(mixHardLight(cb.r,co.r),mixHardLight(cb.g,co.g),mixHardLight(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendLinearLight(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half opa = c.a * v.color.a;
    half3 co = c.rgb * v.color.rgb * opa;
    half3 blend =  half3(mixLinearLight(cb.r,co.r),mixLinearLight(cb.g,co.g),mixLinearLight(cb.b,co.b));
    return half4(blend,max(c.a,cb.a));
}
fragment half4 textureBlendLinearBurn(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half opa = c.a * v.color.a;
    half3 co = c.rgb * v.color.rgb;
    half3 blend =  half3(mixLinearBurn(cb.r,co.r,opa),mixLinearBurn(cb.g,co.g,opa),mixLinearBurn(cb.b,co.b,opa));
    return half4(blend,max(c.a,cb.a));
}
fragment half4 textureBlendReflect(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = cb.rgb*cb.rgb/(half3(1.01,1.01,1.01)-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendGlow(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = co.rgb*co.rgb/(half3(1.01,1.01,1.01)-cb.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendPhoenix(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = min(cb.rgb,co.rgb)+max(cb.rgb,co.rgb)-one;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
fragment half4 textureBlendExclusion(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], half4 cb [[color(0)]])
{
    half4 c = t.sample(s,v.uv);
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = cb.rgb+co.rgb-2.0*cb.rgb*co.rgb;
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
//#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct BlurParams {
    float2 sigma;
};
struct BlurVerticeIn {
    float3 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};
struct BlurVertice {
    float4 position [[position]];
    float2 uv;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex BlurVertice blurFuncVertex(const device BlurVerticeIn *vin [[buffer(0)]],constant Uniforms &u [[buffer(1)]],uint vid [[vertex_id]])
{
    BlurVertice vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.uv = vin[vid].uv;
    return vout;
}
fragment half4 blurH(BlurVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant BlurParams &p[[buffer(0)]])
{
    const float o[] = { 0.0, 1.3846153846, 3.2307692308 };
    const float w[] = { 0.2270270270, 0.3162162162, 0.0702702703  };
    half4 c=t.sample(s,v.uv)*w[0];
    for(int i=1; i<3; i++) {
        c += t.sample(s,v.uv+float2(o[i]*p.sigma.x,0))*w[i];
        c += t.sample(s,v.uv-float2(o[i]*p.sigma.x,0))*w[i];
    }
    return c;
}
fragment half4 blurV(BlurVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant BlurParams &p[[buffer(0)]])
{
    const float o[] = { 0.0, 1.3846153846, 3.2307692308 };
    const float w[] = { 0.2270270270, 0.3162162162, 0.0702702703  };
    half4 c=t.sample(s,v.uv)*w[0];
    for(int i=1; i<3; i++) {
        c += t.sample(s,v.uv+float2(0,o[i]*p.sigma.y))*w[i];
        c += t.sample(s,v.uv-float2(0,o[i]*p.sigma.y))*w[i];
    }
    return c;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct BlendParams {
    float opacity;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct BlendVerticeIn
{
    float3 position [[attribute(0)]];
    float2 uv [[attribute(2)]];
};
struct BlendVertice {
    float4 position [[position]];
//    half4 color;
    float2 uv;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex BlendVertice blendFuncVertex(const device BlendVerticeIn *vin [[buffer(0)]],constant Uniforms &u [[buffer(1)]],uint vid [[vertex_id]])
{
    BlendVertice vout;
    vout.position = u.matrix * float4(vin[vid].position, 1);
    vout.uv = vin[vid].uv;
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendMultiply(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = cb.rgb * co.rgb;
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendScreen(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = one-(one-cb.rgb)*(one-co.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendOverlay(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  half3(mixOverlay(cb.r,co.r),mixOverlay(cb.g,co.g),mixOverlay(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendSoftLight(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = (one-two*co.rgb)*cb.rgb*cb.rgb+two*co.rgb*cb.rgb;
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendAdd(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    return half4(cb.rgb + co.rgb * opa,co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendLighten(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = max(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendDarken(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = min(cb.rgb,co.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendAverage(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = (cb.rgb + co.rgb) * 0.5;
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendSubstract(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    return half4(cb.rgb+(co.rgb-one)*opa,co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendDifference(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    return half4(abs(cb.rgb-co.rgb*opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendNegation(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = one-abs(one-cb.rgb-co.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendColorDodge(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  min(one,half3(mixColorDodge(cb.r,co.r),mixColorDodge(cb.g,co.g),mixColorDodge(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendColorBurn(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  max(zero,half3(mixColorBurn(cb.r,co.r),mixColorBurn(cb.g,co.g),mixColorBurn(cb.b,co.b)));
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendHardLight(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  half3(mixHardLight(cb.r,co.r),mixHardLight(cb.g,co.g),mixHardLight(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendLinearLight(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  half3(mixLinearLight(cb.r,co.r),mixLinearLight(cb.g,co.g),mixLinearLight(cb.b,co.b));
    return half4(mix(cb.rgb,blend,opa),co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendLinearBurn(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend =  half3(mixLinearBurn(cb.r,co.r,opa),mixLinearBurn(cb.g,co.g,opa),mixLinearBurn(cb.b,co.b,opa));
    return half4(blend,co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendReflect(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = cb.rgb*cb.rgb/(half3(1.01,1.01,1.01)-co.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendGlow(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = co.rgb*co.rgb/(half3(1.01,1.01,1.01)-cb.rgb);
    return half4(mix(cb.rgb,blend,opa),co.a);}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendPhoenix(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = min(cb.rgb,co.rgb)+max(cb.rgb,co.rgb)-one;
    return half4(mix(cb.rgb,blend,opa),co.a);}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendSub(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    return half4(cb.rgb-co.rgb*opa,co.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 blendExclusion(BlendVertice v [[stage_in]], texture2d<half> base [[texture(0)]], texture2d<half> over [[texture(1)]], sampler s [[sampler(0)]], constant BlendParams &p[[buffer(0)]])
{
    half4 cb=base.sample(s,v.uv);
    half4 co=over.sample(s,v.uv);
    half opa = co.a * p.opacity;
    half3 blend = cb.rgb+co.rgb-2.0*cb.rgb*co.rgb;
    return half4(mix(cb.rgb,blend,opa),co.a);}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 gradientHeightFragment(TextureVertice v [[stage_in]], texture2d<float> t [[texture(0)]], texture2d<half> pal [[texture(1)]], sampler s [[sampler(0)]])
{
    constexpr sampler ss(coord::normalized,s_address::clamp_to_edge,t_address::clamp_to_edge,filter::linear);
    float ls = t.sample(s,v.uv).r;
    half4 cg = pal.sample(ss,float2(ls,0)).rgba;
    return cg*v.color;
}
fragment half4 gradientFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> pal [[texture(1)]], sampler s [[sampler(0)]])
{
    constexpr sampler ss(coord::normalized,s_address::clamp_to_edge,t_address::clamp_to_edge,filter::linear);
    half4 cs = t.sample(s,v.uv).rgba;
    float ls = cs.r*0.3333+cs.g*0.3333+cs.b*0.3333;
    half4 cg = pal.sample(ss,float2(ls,0)).rgba;
    return mix(cs,cg,v.color.a)*half4(v.color.rgb,1);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct Point3dIn{
    float3  position [[attribute(0)]];
    float   size [[attribute(1)]];
    float4  color [[attribute(2)]];
};
struct Point3dOut {
    float4  position [[position]];
    float   size [[point_size]];
    half4   color;
};
struct Vertex3dIn{
    float3  position [[attribute(0)]];
    float4  color [[attribute(1)]];
    float2  uv [[attribute(2)]];
    float3  normal [[attribute(3)]];
};
struct Vertex3dOut{
    float4  position [[position]];
    half4   color;
    float2  uv;
    float3  normal;
    float3  fragmentPosition;
    float3  eye;
};
struct DirectionalLight {
    float4  color;
    float   intensity;
    float3  direction;
};
struct PointLight {
    float4  color;
    float   attenuationConstant;
    float   attenuationLinear;
    float   attenuationQuadratic;
    float3  position;
};
struct Material {
    float4  ambient;
    float4  diffuse;
    float4  specular;
    float   shininess;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Point3dOut point3DFunc(const device Point3dIn *pin [[buffer(0)]],
                              constant Uniforms3d &u [[buffer(1)]],
                              uint id [[vertex_id]]) {
    Point3dOut pout;
    pout.position = u.view * float4(pin[id].position,1);
    float rz = 1/(1+pout.position.z*100);
    pout.size = 10*rz;
    pout.color = half4(pin[id].color);
    pout.color.a *= rz;
    return pout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Vertex3dOut vertex3DFunc(const device Vertex3dIn *vin [[buffer(0)]],
                                constant Uniforms3d &u [[buffer(1)]],
                                uint vid [[vertex_id]]) {
    Vertex3dOut vout;
    vout.position = u.view * float4(vin[vid].position,1);
    vout.normal = normalize((u.world*float4(vin[vid].normal,0)).xyz);
    vout.fragmentPosition = (u.world*float4(vin[vid].position,1)).xyz;
    vout.color = half4(vin[vid].color);
    vout.uv = vin[vid].uv;
    vout.eye = normalize(u.eye - vout.fragmentPosition);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Vertex3dOut vertex3DInstance(const device Vertex3dIn *vin [[buffer(0)]],
                                    constant Uniforms3d &u [[buffer(1)]],
                                    constant InstanceIn *instances [[buffer(2)]],
                                    uint iid [[instance_id]],
                                    uint vid [[vertex_id]]) {
    Vertex3dOut vout;
    InstanceIn i = instances[iid];
    vout.position = u.view * i.matrix * float4(vin[vid].position,1);
    vout.normal = normalize((u.world * i.matrix * float4(vin[vid].normal,0)).xyz);
    vout.fragmentPosition = (u.world * i.matrix * float4(vin[vid].position,1)).xyz;
    vout.color = half4(vin[vid].color*i.color);
    vout.uv = vin[vid].uv;
    vout.eye = normalize(u.eye - vout.fragmentPosition);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct UniformsHeight {
    float width;
    float height;
    float scale;
    float adjustNormals;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Vertex3dOut vertex3DHeightFunc(  const device Vertex3dIn *vin [[buffer(0)]],
                                      constant Uniforms3d &u [[buffer(1)]],
                                      constant UniformsHeight &uh [[buffer(2)]],
                                      texture2d<half> tc [[texture(0)]],
                                      texture2d<float> th [[texture(1)]],
                                      uint vid [[vertex_id]]) {
    constexpr sampler ss(coord::normalized,s_address::repeat,t_address::clamp_to_edge,filter::linear);
    Vertex3dOut vout;
    float dy = 0.5/uh.height;
    float dx = 0.5/uh.width;
    half4 c = tc.sample(ss,vin[vid].uv);
    float h = th.sample(ss,vin[vid].uv).r;
    float htop = th.sample(ss,vin[vid].uv+float2(0,-dy)).r;
    float hbottom = th.sample(ss,vin[vid].uv+float2(0,dy)).r;
    float hleft = th.sample(ss,vin[vid].uv+float2(-dx,0)).r;
    float hright = th.sample(ss,vin[vid].uv+float2(+dx,0)).r;
    float3 n = normalize(vin[vid].normal);
    float t = atan2(n.y,n.x);
    float p = acos(n.z);
    if(isnan(t)) {  // iOS & tvOS...
        t = 0;
    }
    float2 dt = float2(float(hbottom - htop)*uh.adjustNormals,dx*2);
    t -= atan2(dt.y,dt.x);
    float2 dp = float2(float(hright - hleft)*uh.adjustNormals,dy*2);
    p += atan2(dp.x,dp.y);
    n.x = sin(p) * cos(t);
    n.y = sin(p) * sin(t);
    n.z = cos(p);
    float3 pos = vin[vid].position + vin[vid].normal * float(h) * uh.scale;
    vout.position = u.view * float4(pos,1);
    vout.normal = normalize((u.world*float4(n,0)).xyz);
    vout.fragmentPosition = (u.world*float4(pos,1)).xyz;
    vout.color = half4(vin[vid].color) * c;
    vout.uv = vin[vid].uv;
    vout.eye = normalize(u.eye - vout.fragmentPosition);
    //vout.color = half4(0.5+(hright.r-hleft.r)*5,0/*0.5+(hbottom.r-htop.r)*5*/,0,1);   // 4debug
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Vertex3dOut vertex3DHeightTextureFunc(  const device Vertex3dIn *vin [[buffer(0)]],
                                             constant Uniforms3d &u [[buffer(1)]],
                                             constant UniformsHeight &uh [[buffer(2)]],
                                             texture2d<float> th [[texture(0)]],
                                             uint vid [[vertex_id]]) {
    constexpr sampler ss(coord::normalized,s_address::repeat,t_address::clamp_to_edge,filter::linear);
    Vertex3dOut vout;
    float dy = 0.5/uh.height;
    float dx = 0.5/uh.width;
    float h = th.sample(ss,vin[vid].uv).r;
    float htop = th.sample(ss,vin[vid].uv+float2(0,-dy)).r;
    float hbottom = th.sample(ss,vin[vid].uv+float2(0,dy)).r;
    float hleft = th.sample(ss,vin[vid].uv+float2(-dx,0)).r;
    float hright = th.sample(ss,vin[vid].uv+float2(+dx,0)).r;
    float3 n = normalize(vin[vid].normal);
    float t = atan2(n.y,n.x);
    float p = acos(n.z);
    if(isnan(t)) {  // iOS & tvOS...
        t = 0;
    }
    float2 dt = float2(float(hbottom - htop)*uh.adjustNormals,dx*2);
    t -= atan2(dt.y,dt.x);
    float2 dp = float2(float(hright - hleft)*uh.adjustNormals,dy*2);
    p += atan2(dp.x,dp.y);
    n.x = sin(p) * cos(t);
    n.y = sin(p) * sin(t);
    n.z = cos(p);
    float3 pos = vin[vid].position + vin[vid].normal * float(h) * uh.scale;
    vout.position = u.view * float4(pos,1);
    vout.normal = normalize((u.world*float4(n,0)).xyz);
    vout.fragmentPosition = (u.world*float4(pos,1)).xyz;
    vout.color = half4(vin[vid].color);
    vout.uv = vin[vid].uv;
    vout.eye = normalize(u.eye - vout.fragmentPosition);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
vertex Vertex3dOut vertex3DBonesFunc(               const device Vertex3dIn *vin [[buffer(0)]],
                                     constant Uniforms3d &u [[buffer(1)]],
                                     //                                        constant Bones &bones [[buffer(2)]],
                                     uint vid [[vertex_id]]) {
    Vertex3dOut vout;
    vout.position = u.view * float4(vin[vid].position,1);
    vout.normal = normalize((u.world*float4(vin[vid].normal,0)).xyz);
    vout.fragmentPosition = (u.world*float4(vin[vid].position,1)).xyz;
    vout.color = half4(vin[vid].color);
    vout.uv = vin[vid].uv;
    vout.eye = normalize(u.eye - vout.fragmentPosition);
    return vout;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPointFunc(                   Point3dOut p [[stage_in]],
                                 float2 uv  [[point_coord]],
                                 constant Material &material [[buffer(0)]]) {
    float a = max(0.0,2*(0.5-length(uv-float2(0.5,0.5))));
    return p.color*half4(material.diffuse)*half4(1,1,1,a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPointTextureFunc(            Point3dOut p [[stage_in]],
                                        float2 uv  [[point_coord]],
                                        texture2d<half> t [[texture(0)]],
                                        constant Material &material [[buffer(0)]],
                                        sampler s [[sampler(0)]]) {
    return t.sample(s,uv)*p.color*half4(material.diffuse);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentFunc( Vertex3dOut v [[stage_in]],
                            constant Material &material [[buffer(0)]]) {
    //return half4(half3(v.normal),1);
    return v.color*half4(material.diffuse);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTextureFunc(                 Vertex3dOut v [[stage_in]],
                                   texture2d<half> t [[texture(0)]],
                                   constant Material &material [[buffer(0)]],
                                   sampler s [[sampler(0)]]) {
    return t.sample(s,v.uv).rgba * v.color * half4(material.diffuse);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentDirectionalLightFunc(        Vertex3dOut v [[stage_in]],
                                            constant Material &material [[buffer(0)]],
                                            constant DirectionalLight &light [[buffer(2)]]) {
    //return half4(half3(v.normal)*0.5+0.5,1);
    float3 normal = normalize(v.normal);
    half4 c = half4();
    c += half4(light.color*light.intensity*material.ambient);
    float diffuseFactor = max(0.0,dot(normal,light.direction));
    if(diffuseFactor>0) {
        c += half4(light.color*light.intensity*material.diffuse*diffuseFactor);
        float3 hv = normalize(v.eye-light.direction);
        float specularFactor = pow(max(0.0,dot(normal,hv)),material.shininess);
        c += half4(material.specular*specularFactor*min(1.0,diffuseFactor*3.0));
    }
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTextureDirectionalLightFunc( Vertex3dOut v [[stage_in]],
                                                   texture2d<half> t [[texture(0)]],
                                                   constant Material &material [[buffer(0)]],
                                                   constant DirectionalLight &light [[buffer(2)]],
                                                   sampler s [[sampler(0)]]) {
    float3 normal = normalize(v.normal);
    half4 c = half4();
    c += half4(light.color*light.intensity*material.ambient);
    float diffuseFactor = max(0.0,dot(normal,light.direction));
    if(diffuseFactor>0) {
        c += half4(light.color*light.intensity*material.diffuse*diffuseFactor);
        float3 hv = normalize(v.eye-light.direction);
        float specularFactor = pow(max(0.0,dot(normal,hv)),material.shininess);
        c += half4(material.specular*specularFactor*min(1.0,diffuseFactor*3.0));
    }
    return c * t.sample(s,v.uv).rgba * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
// https://www.tomdalling.com/blog/modern-opengl/07-more-lighting-ambient-specular-attenuation-gamma/
// http://www.lighthouse3d.com/tutorials/glsl-12-tutorial/point-light-per-pixel/
half4 calcLight(Vertex3dOut v, Material material, PointLight light);
half4 calcLight(Vertex3dOut v, Material material, PointLight light) {
    half4 c=half4();
    float3 normal = normalize(v.normal);
    float3 lightdir = normalize(light.position - v.fragmentPosition);   // normalize(float3(1,-1,-1));
    float diffuseFactor = dot(normal,lightdir);
    if(diffuseFactor>0) {
        float dist = length(light.position - v.fragmentPosition);
        float att = 1.0 / (light.attenuationConstant+light.attenuationLinear*dist+light.attenuationQuadratic*dist*dist);
        c += att * half4(material.diffuse) * diffuseFactor;
        float3 hv = normalize(v.eye+lightdir);
        float specularFactor = pow(max(0.0,dot(normal,hv)),material.shininess);
        c += att * half4(material.specular*specularFactor*min(1.0,diffuseFactor*3.0)); // normaly no mul by diffuseFactor*2 here
        //c = half4(0,1,0,1);
    }
    return c * half4(light.color);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPointLightFunc(          Vertex3dOut v [[stage_in]],
                                      constant Material &material [[buffer(0)]],
                                      constant PointLight &light [[buffer(2)]]) {
    //return half4(half3(v.normal)*0.5+0.5,1);
    half4 c = half4(material.ambient)+calcLight(v,material,light);
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTexturePointLightFunc(   Vertex3dOut v [[stage_in]],
                                             texture2d<half> t [[texture(0)]],
                                             constant Material &material [[buffer(0)]],
                                             constant PointLight &light [[buffer(2)]],
                                             sampler s [[sampler(0)]]) {
    half4 c = half4(material.ambient)+calcLight(v,material,light);
    return c * v.color * t.sample(s,v.uv).rgba;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPoint2LightFunc(         Vertex3dOut v [[stage_in]],
                                       constant Material &material [[buffer(0)]],
                                       constant PointLight &light1 [[buffer(2)]],
                                       constant PointLight &light2 [[buffer(3)]]) {
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTexturePoint2LightFunc(  Vertex3dOut v [[stage_in]],
                                              texture2d<half> t [[texture(0)]],
                                              constant Material &material [[buffer(0)]],
                                              constant PointLight &light1 [[buffer(2)]],
                                              constant PointLight &light2 [[buffer(3)]],
                                              sampler s [[sampler(0)]]) {
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    return c * v.color * t.sample(s,v.uv).rgba;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPoint3LightFunc(         Vertex3dOut v [[stage_in]],
                                       constant Material &material [[buffer(0)]],
                                       constant PointLight &light1 [[buffer(2)]],
                                       constant PointLight &light2 [[buffer(3)]],
                                       constant PointLight &light3 [[buffer(4)]]) {
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    c += calcLight(v,material,light3);
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTexturePoint3LightFunc(  Vertex3dOut v [[stage_in]],
                                              texture2d<half> t [[texture(0)]],
                                              constant Material &material [[buffer(0)]],
                                              constant PointLight &light1 [[buffer(2)]],
                                              constant PointLight &light2 [[buffer(3)]],
                                              constant PointLight &light3 [[buffer(4)]],
                                              sampler s [[sampler(0)]]) {
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    c += calcLight(v,material,light3);
    return c * v.color * t.sample(s,v.uv).rgba;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentPoint4LightFunc(         Vertex3dOut v [[stage_in]],
                                       constant Material &material [[buffer(0)]],
                                       constant PointLight &light1 [[buffer(2)]],
                                       constant PointLight &light2 [[buffer(3)]],
                                       constant PointLight &light3 [[buffer(4)]],
                                       constant PointLight &light4 [[buffer(5)]]) {
    //return half4(half3(v.normal)*0.5+0.5,1);
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    c += calcLight(v,material,light3);
    c += calcLight(v,material,light4);
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fragmentTexturePoint4LightFunc(  Vertex3dOut v [[stage_in]],
                                              texture2d<half> t [[texture(0)]],
                                              constant Material &material [[buffer(0)]],
                                              constant PointLight &light1 [[buffer(2)]],
                                              constant PointLight &light2 [[buffer(3)]],
                                              constant PointLight &light3 [[buffer(4)]],
                                              constant PointLight &light4 [[buffer(5)]],
                                              sampler s [[sampler(0)]]) {
    half4 c = half4(material.ambient);
    c += calcLight(v,material,light1);
    c += calcLight(v,material,light2);
    c += calcLight(v,material,light3);
    c += calcLight(v,material,light4);
    return c * v.color * t.sample(s,v.uv).rgba;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct zoomParameters
{
    float zoom;
    float rotation;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 zoomFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant zoomParameters &zoom [[buffer(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center);
    if(zoom.rotation == 0) {
        float2 p = d * zoom.zoom + center;
        half4 c = t.sample(s,p).rgba;
        return c * v.color;
    }
    float r = length(d) * zoom.zoom;
    float a = atan2(d.y, d.x) + zoom.rotation;
    float2 p = float2(cos(a), sin(a)) * r + center;
    half4 c = t.sample(s,p).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 circularFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    float2 p=float2((v.uv.x-0.5)*2,(v.uv.y-0.5)*2);
    p.x = length(p);
    p.y = 0;
    half4 c = t.sample(s,p).rgba * v.color;
    return half4(c.r,c.g,c.b,v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 polarFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 p = {length(d), (atan2(d.y, d.x)+pi*0.5)/(pi*2.0)};
    half4 c = t.sample(s,p).rgba * v.color;
    return half4(c.r,c.g,c.b,v.color.a);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment float polarFuncFragmentHeight(TextureVertice v [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 p = {length(d), (atan2(d.y, d.x)+pi*0.5)/(pi*2.0)};
    return t.sample(s,p).r*float(v.color.r);
}
// 4test / 4debug
fragment float polarFuncFragmentHeightAdd(TextureVertice v [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]], float cb [[color(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 p = {length(d), (atan2(d.y, d.x)+pi*0.5)/(pi*2.0)};
    return cb+t.sample(s,p).r*float(v.color.r);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 crossFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]])
{
    half4 c = t.sample(s,float2(v.uv.x,0)).rgba + t.sample(s,float2(v.uv.y,1)).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 paletizeFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> pal [[texture(1)]], sampler s [[sampler(0)]], constant float2 &p[[buffer(0)]])
{
    constexpr sampler ss(coord::normalized,s_address::clamp_to_edge,t_address::clamp_to_edge,filter::linear);
    half4 cs = t.sample(s,v.uv).rgba;
    float2 ps = float2(brightness(cs.rgb))+p;
    half4 c = pal.sample(ss,ps).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct popoopooo
{
    float2 offset;
    float2 amplitude;
    float2 decal;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 popoopoooFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant popoopooo &p[[buffer(0)]])
{
    //constexpr sampler ss(coord::normalized,s_address::clamp_to_edge,t_address::repeat,filter::linear);
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 uv = {length(d), ((atan2(d.y, d.x)+pi*0.5)/(pi*2.0))};
    float2 duv = { uv.x+p.decal.x * uv.y, uv.y + p.decal.y * uv.x };
    uv = duv * p.amplitude + p.offset;
    half4 c = t.sample(s,uv).rgba * v.color;
    return half4(c.r,c.g,c.b,v.color.a);
}
fragment half4 popoopoooScreenFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant popoopooo &p[[buffer(0)]], half4 cb [[color(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 uv = {length(d), ((atan2(d.y, d.x)+pi*0.5)/(pi*2.0))};
    float2 duv = { uv.x+p.decal.x * uv.y, uv.y + p.decal.y * uv.x };
    uv = duv * p.amplitude + p.offset;
    half4 c = t.sample(s,uv).rgba;
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = one-(one-cb.rgb)*(one-co.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
    
}
fragment half4 popoopoooDifferenceFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant popoopooo &p[[buffer(0)]], half4 cb [[color(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 uv = {length(d), ((atan2(d.y, d.x)+pi*0.5)/(pi*2.0))};
    float2 duv = { uv.x+p.decal.x * uv.y, uv.y + p.decal.y * uv.x };
    uv = duv * p.amplitude + p.offset;
    half4 c = t.sample(s,uv).rgba;
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    return half4(abs(cb.rgb-co.rgb*opa),max(c.a,cb.a));
}
fragment half4 popoopoooGlowFuncFragment(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant popoopooo &p[[buffer(0)]], half4 cb [[color(0)]])
{
    const float2 center = { 0.5, 0.5 };
    float2 d = (v.uv-center)*2;
    float2 uv = {length(d), ((atan2(d.y, d.x)+pi*0.5)/(pi*2.0))};
    float2 duv = { uv.x+p.decal.x * uv.y, uv.y + p.decal.y * uv.x };
    uv = duv * p.amplitude + p.offset;
    half4 c = t.sample(s,uv).rgba;
    half3 co = c.rgb * v.color.rgb;
    half opa = c.a * v.color.a;
    half3 blend = co.rgb*co.rgb/(half3(1.01,1.01,1.01)-cb.rgb);
    return half4(mix(cb.rgb,blend,opa),max(c.a,cb.a));
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct FxColorRGBParams {
    float2 r_offset;
    float2 g_offset;
    float2 b_offset;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fxColorRGB(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], sampler s [[sampler(0)]], constant FxColorRGBParams &p[[buffer(0)]]) {
    half4 r = t.sample(s,v.uv+p.r_offset).rgba;
    half4 g = t.sample(s,v.uv+p.g_offset).rgba;
    half4 b = t.sample(s,v.uv+p.b_offset).rgba;
    return half4(r.r,g.g,b.b,1)*half4(r.a,g.a,b.a,max(max(r.a,g.a),b.a))*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fxColorHSV(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<half> adjust [[texture(1)]], sampler s [[sampler(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    half4 cc = t.sample(s,v.uv).rgba;
    half4 ca = t.sample(s,v.uv + float2(0.005,0.005)).rgba;
    ca += t.sample(s,v.uv + float2(-0.005,0.005)).rgba;
    ca += t.sample(s,v.uv + float2(0.005,-0.005)).rgba;
    ca += t.sample(s,v.uv + float2(-0.005,-0.005)).rgba;
    ca /= 4;
    half3 hca = rgb2hsv(ca.rgb);
    half3 hco = rgb2hsv(cc.rgb);
    hco.z = adjust.sample(ss,float2(hca.x,0)).x * hco.z;
    half3 cr = hsv2rgb(hco);
    return half4(cr,cc.a)*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct FxDynamicPolarParams {
    float ratio;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fxDynamicPolar(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<float> adjust [[texture(1)]], sampler s [[sampler(0)]], constant FxDynamicPolarParams &params[[buffer(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    const float2 center = { 0.5, 0.5 };
    float2 ratio = float2(params.ratio,1);
    float2 d = (v.uv-center) * ratio;
    float r = length(d);
    float a = atan2(d.y, d.x);
    r = adjust.sample(ss,float2(r*0.5,0)).r;
    float2 p = float2(cos(a), sin(a)) / ratio * r + center;
    half4 c = t.sample(s,p).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fxDynamicVhsDesync(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<float> adjust [[texture(1)]], sampler s [[sampler(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    float2 d = float2(adjust.sample(ss,float2(v.uv.y,0)).r,0);
    half4 c = t.sample(s,v.uv+d).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment half4 fxDynamicFloat2(TextureVertice v [[stage_in]], texture2d<half> t [[texture(0)]], texture2d<float> adjust [[texture(1)]], sampler s [[sampler(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    float2 d = float2(adjust.sample(ss,v.uv).xy);
    half4 c = t.sample(s,v.uv+d).rgba;
    return c * v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
struct FxDynamicPolar2Params {
    float2 amplitude;
};
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment float4 fxDynamicPolarFloat2(TextureVertice_float v [[stage_in]], texture2d<float> t [[texture(0)]], constant FxDynamicPolar2Params &params[[buffer(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    const float2 center = { 0.5, 0.5 };
    float2 p = (v.uv-center)*2;
    float l = length(p);
    if (l>1) {
        return float4(0,0,0,0);
    }
    float2 da = params.amplitude;
    float  a = atan2(p.y, p.x);
    float2 d = t.sample(ss,float2(l*0.5,0)).rg;
    float2 la = float2(l,a) + d * da;
    float2 pd = float2(cos(la.y), sin(la.y)) * la.x;
    return float4(pd-p,0,1)*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
fragment float4 fxDynamicCartesianFloat2(TextureVertice_float v [[stage_in]], texture2d<float> t [[texture(0)]]) {
    constexpr sampler ss = sampler(filter::linear, address::clamp_to_edge);
    float2 p = v.uv;
    float2 d = float2(t.sample(ss,float2(p.x,0)).r,t.sample(ss,float2(p.y,0)).r);
    return float4(d,0,1)*v.color;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

