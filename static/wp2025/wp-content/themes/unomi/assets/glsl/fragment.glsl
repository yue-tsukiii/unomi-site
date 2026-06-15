precision highp float;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_random_seed;
uniform float u_scale;
uniform float u_density;
uniform float u_blur;
uniform float u_speed;
uniform float u_saturation;
uniform float u_distortion;
uniform float u_halftone_size;
uniform float u_halftone_strength;
uniform float u_mouse_halftone_size;
uniform float u_mouse_halftone_strength;
uniform vec2 u_mouse;
uniform float u_mouse_radius;
uniform float u_mouse_effect_strength;
const int MAX_TRAIL_POINTS = 60;
uniform vec2 u_trail_positions[MAX_TRAIL_POINTS];
uniform float u_trail_strengths[MAX_TRAIL_POINTS];
uniform float u_trail_sizes[MAX_TRAIL_POINTS];
uniform int u_trail_count;

// 3Dノイズ関数
vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    
    i = mod289(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// ハッシュ関数（疑似ランダム値生成用）
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec2 hash2(float n) {
    return vec2(
        fract(sin(n) * 43758.5453123),
        fract(cos(n) * 12345.6789012)
    );
}

// ハーフトーン効果関数（マウスインタラクション対応）
// 注意: 軌跡ループはANGLE(Android Chrome)でuniform配列のループアクセスが
// 正しくコンパイルされない不具合があるため無効化。マウス単一ポイントの影響のみ使用。
float halftone(vec2 uv, vec2 originalUV, float brightness) {
    // マウス位置からの距離を計算（元のUVを使用）
    vec2 pixelPos = originalUV * u_resolution;
    float distToMouse = length(pixelPos - u_mouse);
    
    // マウスの影響範囲内での効果を計算（境界線が見えないように広い範囲でフェード）
    float outerRadius = u_mouse_radius * 2.5;
    float innerRadius = u_mouse_radius * 0.1;
    // smoothstepはedge0 < edge1が必須（逆順はGLSL仕様で未定義動作、ANGLEで不具合）
    float mouseInfluence = 1.0 - smoothstep(innerRadius, outerRadius, distToMouse);
    float mouseStrength = 1.0;
    
    // 境界をより滑らかにするため、影響度を二次関数的に減衰
    float smoothInfluence = mouseInfluence * mouseInfluence * mouseStrength;
    
    // カーソル周辺とデフォルトのハーフトーンサイズをブレンド
    float effectiveHalftoneSize = mix(u_halftone_size, u_mouse_halftone_size, smoothInfluence);
    
    // アスペクト比を考慮したグリッド計算
    vec2 aspectRatio = vec2(u_resolution.x / u_resolution.y, 1.0);
    vec2 grid = uv * aspectRatio * u_resolution.y * effectiveHalftoneSize;
    vec2 cellPos = fract(grid);
    
    // セルの中心からの距離
    vec2 center = vec2(0.5);
    float dist = length(cellPos - center);
    
    // サイズ倍率を計算（カーソル周辺で大きくなる、こちらも滑らかに）
    float sizeMultiplier = 1.0 + smoothInfluence * u_mouse_effect_strength;
    
    // 明るさに応じてドットのサイズを変える（マウス効果を適用）
    // デフォルトは0.7（元の状態）、カーソル周辺で大きくなる
    float dotSize = (1.0 - brightness) * 0.7 * sizeMultiplier;
    
    // ドットパターンを生成（デフォルトは0.1、カーソル周辺で滑らかに）
    float edgeSoftness = mix(0.1, 0.15, smoothInfluence);
    // smoothstepはedge0 < edge1が必須（逆順はGLSL仕様で未定義動作）
    float dotPattern = 1.0 - smoothstep(dotSize - edgeSoftness, dotSize, dist);
    
    // デフォルトはシンプルなドットパターン（元の状態）
    // カーソル周辺では明るさを保つ処理を適用（元の表現）
    float minBrightness = max(brightness * 0.85, 0.3);
    float mouseHalftoneEffect = mix(minBrightness, 1.0, 1.0 - dotPattern);
    
    // デフォルトとカーソル周辺のハーフトーン効果をブレンド
    float halftoneEffect = mix(dotPattern, mouseHalftoneEffect, smoothInfluence);
    
    // カーソル周辺とデフォルトのハーフトーン強度をブレンド（滑らかに）
    float effectiveStrength = mix(u_halftone_strength, u_mouse_halftone_strength, smoothInfluence);
    
    // ハーフトーン効果を適用して返す
    return mix(brightness, halftoneEffect, effectiveStrength);
}

// RGBチャンネルごとのハーフトーン（CMYK風）
vec3 halftoneRGB(vec2 uv, vec3 color) {
    // アスペクト比を考慮
    vec2 aspectRatio = vec2(u_resolution.x / u_resolution.y, 1.0);
    vec2 correctedUV = uv * aspectRatio;
    
    // 各チャンネルに異なる角度のハーフトーンを適用
    float angle1 = 0.26;  // 約15度
    float angle2 = 1.31;  // 約75度
    float angle3 = -0.26; // 約-15度
    
    // 回転行列を使って各チャンネルのグリッドを回転
    mat2 rot1 = mat2(cos(angle1), -sin(angle1), sin(angle1), cos(angle1));
    mat2 rot2 = mat2(cos(angle2), -sin(angle2), sin(angle2), cos(angle2));
    mat2 rot3 = mat2(cos(angle3), -sin(angle3), sin(angle3), cos(angle3));
    
    // 各チャンネルのハーフトーンを計算（回転後のUVを使用、マウス計算には元のuvを使用）
    float r = halftone(rot1 * correctedUV / aspectRatio, uv, color.r);
    float g = halftone(rot2 * correctedUV / aspectRatio, uv, color.g);
    float b = halftone(rot3 * correctedUV / aspectRatio, uv, color.b);
    
    return vec3(r, g, b);
}

// ★★★ 色を追加・削除する場合は、このエリアだけ編集してください ★★★
const int MAX_COLORS = 20;  // 最大色数（変更不要）
const int COLOR_COUNT = 4;   // 実際に使用する色数（色の数に合わせて変更）

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 pos = uv * 2.0 - 1.0;
    pos.x *= u_resolution.x / u_resolution.y;
    
    float t = u_time * u_speed;
    
    // ★ カラーパレット（色を追加・削除する場合はこの配列だけ編集）★
    vec3 colors[MAX_COLORS];
    colors[0] = vec3(1.0, 0.2, 0.6);    // ピンク
    colors[1] = vec3(0.15, 0.55, 1.0);  // 青
    colors[2] = vec3(0.2, 1.0, 1.0);    // シアン
    colors[3] = vec3(1.0, 0.6, 0.15);   // オレンジ
    colors[4] = vec3(1.0, 1.0, 1.0);   // 白
    // ↑ 追加したらCOLOR_COUNTも増やしてください（例：5 → 6）
    
    // 各色の重み（影響力）デフォルトは1.0
    // 大きいほどその色が強く表示される
    float weights[MAX_COLORS];
    weights[0] = 0.9;  // ピンク
    weights[1] = 1.2;  // 青
    weights[2] = 0.9;  // シアン
    weights[3] = 0.8;  // オレンジ
    weights[4] = 1.1;  // 白
    // ベースカラー（白）
    vec3 color = vec3(1.0, 1.0, 1.0);
    
    // 各色のノイズ値を計算してブレンド
    float noiseSum = 0.0;
    for(int i = 0; i < MAX_COLORS; i++) {
        if(i >= COLOR_COUNT) break;  // 使用する色数まで処理
        
        // インデックスから動的にパラメータを生成（リロード時にランダム化）
        float seed = (float(i) + u_random_seed) * 12.9898;
        
        // オフセット（各色で異なる位置に配置、より広範囲に）
        vec2 offset = hash2(seed) * 12.0 - 6.0;
        
        // スケール（拡大率パラメータで調整、よりバリエーション豊かに）
        float baseScale = 0.25 + hash(seed + 1.0) * 0.25;
        float scale = baseScale * u_scale;
        
        // 異方性（横長の形を作る、歪み度パラメータで調整可能）
        float stretchX = 0.3 + hash(seed + 5.0) * 0.5; // 0.3～0.8
        // 歪み度パラメータ（u_distortion）で横長の度合いを調整
        // 1.0 = 標準、値が大きいほど横に長くなる
        float safeDistortion = clamp(u_distortion, 0.0, 5.0);
        float stretchY = 1.0 + hash(seed + 6.0) * safeDistortion;
        vec2 anisotropicScale = vec2(stretchX, stretchY) * scale;
        
        // ランダムな回転角度
        float angle = hash(seed + 7.0) * 6.28318; // 0～2π
        mat2 rotation = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
        
        // 時間スケール（より広い範囲で有機的な動きに）
        float timeScale = 0.3 + hash(seed + 2.0) * 0.5;
        
        // ブレンド強度（0.7～0.85の範囲）
        float blendStrength = 0.7 + hash(seed + 3.0) * 0.15;
        
        // 回転と引き伸ばしを適用したノイズパラメータ
        vec2 stretchedPos = rotation * (pos * anisotropicScale) + offset;
        vec3 p = vec3(
            stretchedPos,
            t * timeScale + float(i) * 10.0
        );
        
        // ノイズを計算（-1 to 1 → 0 to 1）
        float noise = snoise(p) * 0.5 + 0.5;
        
        // 流体の密度（きつさ）を調整
        // 値が大きいほど変化が激しく、小さいほどゆるやか
        // 負の値やNaNを防ぐため、noiseを安全な範囲にclamp
        noise = clamp(noise, 0.001, 1.0);
        noise = pow(noise, 1.0 / max(u_density, 0.1));
        
        // 重み付けを適用
        // これにより各色の影響力を調整し、バランスを取る
        float weightedNoise = noise * weights[i];
        
        noiseSum += weightedNoise;
        
        // smoothstepでブレンド係数を計算（ボケ感を調整）
        float blurAmount = u_blur;
        float lower = 0.5 - blurAmount;
        float upper = 0.5 + blurAmount;
        float blend = smoothstep(lower, upper, weightedNoise);
        
        // 色をブレンド（重みを考慮、1.0を超えないようにclamp）
        float blendFactor = clamp(blend * blendStrength * weights[i], 0.0, 1.0);
        color = mix(color, colors[i], blendFactor);
    }
    
    // 滑らかさを追加
    float soften = noiseSum / float(COLOR_COUNT);
    color = mix(color, color * 1.15, soften * 0.25);
    
    // 色の値が負にならないように保護
    color = max(color, vec3(0.0));
    
    // 明るさを調整（pow関数の前にclampで安全な範囲に）
    color = clamp(color, vec3(0.001), vec3(1.0));
    color = pow(color, vec3(0.85));
    
    // 彩度を調整
    // 色のあざやかさを変える（白とのブレンド比率で制御）
    vec3 gray = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
    color = mix(gray, color, clamp(u_saturation, 0.0, 5.0));
    
    // ハーフトーン効果を適用（常に適用、強度は関数内で制御）
    vec3 halftoneColor = halftoneRGB(uv, color);
    color = halftoneColor;
    
    // 最終的な色の値を安全な範囲に（黒くなる問題を防ぐ）
    color = clamp(color, vec3(0.0), vec3(1.0));
    
    gl_FragColor = vec4(color, 1.0);
}
