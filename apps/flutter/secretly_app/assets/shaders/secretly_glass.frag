// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

// SecretlyGlass — жидкое стекло одним проходом (план стекла, 23.11.2026).
//
// Работает фильтром фона (ImageFilter.shader внутри BackdropFilter): один
// захват фона на пластину, форма — формула (SDF), без текстур формы и без
// растеризации на процессоре.
//
// * Преломление ТОЛЬКО в полосе у края (как у Telegram): внутри фон не
//   искажается, подписи не плывут.
// * Капля (выбранный пункт полосы) — второй контур: преломление у её края
//   только пока она движется (u_lift), на уровне Full ещё и дисперсия.
// * Материал: лёгкое размытие (5 выборок), насыщенность, тинт, тонкий блик
//   сверху.
// * Уровни: 1 — Edge (только край + тинт), 2 — Balanced (+ размытие),
//   3 — Full (+ дисперсия у капли). Flat (0) шейдер не вызывает вовсе.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;     // размер входной текстуры (задаёт движок)
uniform vec2 u_origin;   // левый верх пластины, физ. пиксели экрана
uniform vec2 u_plate;    // размер пластины, физ. пиксели
uniform float u_radius;  // скругление пластины
uniform vec4 u_thumb;    // капля в координатах пластины: x, y, w, h (w<=0 — нет)
uniform float u_lift;    // 0..1 — сила линзы капли (движение / нажатие)
uniform float u_dpr;     // плотность экрана
uniform float u_quality; // 1 Edge, 2 Balanced, 3 Full
uniform vec4 u_tint;     // тинт: rgb + сила
uniform float u_sat;     // насыщенность

uniform sampler2D u_tex;

out vec4 fragColor;

float sdRRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec2 sdNormal(vec2 p, vec2 b, float r) {
  float dx = sdRRect(p + vec2(1.0, 0.0), b, r) - sdRRect(p - vec2(1.0, 0.0), b, r);
  float dy = sdRRect(p + vec2(0.0, 1.0), b, r) - sdRRect(p - vec2(0.0, 1.0), b, r);
  vec2 g = vec2(dx, dy);
  float l = length(g);
  return l > 0.0001 ? g / l : vec2(0.0);
}

vec3 tex(vec2 px) {
  vec2 uv = clamp(px / u_size, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_tex, uv).rgb;
}

// Сила сдвига по глубине в полосе: 1 у самого края, 0 на внутренней границе.
float edgeCurve(float depth, float band) {
  float s = 1.0 - clamp(depth / band, 0.0, 1.0);
  return s * s * (3.0 - 2.0 * s);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  // Вход фильтра бывает либо самой пластиной (её координаты), либо всем
  // экраном (координаты экрана) — различаем по размеру текстуры.
  bool local = abs(u_size.x - u_plate.x) < 4.0 && abs(u_size.y - u_plate.y) < 4.0;
  vec2 origin = local ? vec2(0.0) : u_origin;
  vec2 p = frag - origin;
  vec2 hs = u_plate * 0.5;
  float d = sdRRect(p - hs, hs, u_radius);
  float depth = -d;
  vec2 src = frag;

  // Край пластины: тянем фон из глубины — край «увеличивает», как толстое
  // стекло; внутри — ровно.
  float band = 10.0 * u_dpr;
  if (depth < band) {
    vec2 n = sdNormal(p - hs, hs, u_radius);
    src -= n * edgeCurve(max(depth, 0.0), band) * 7.0 * u_dpr;
  }

  // Капля: линза у её края, пока она движется.
  float chroma = 0.0;
  if (u_thumb.z > 0.0 && u_lift > 0.001) {
    vec2 th = u_thumb.zw * 0.5;
    vec2 tc = u_thumb.xy + th;
    float r = min(th.x, th.y);
    float dt = sdRRect(p - tc, th, r);
    float tband = 7.0 * u_dpr;
    if (dt < 0.0 && -dt < tband) {
      vec2 n = sdNormal(p - tc, th, r);
      float k = edgeCurve(-dt, tband) * u_lift;
      src -= n * k * 6.0 * u_dpr;
      chroma = k;
    }
  }

  vec3 c;
  if (u_quality > 2.5 && chroma > 0.02) {
    vec2 dir = src - frag;
    float l = length(dir);
    vec2 off = (l > 0.001 ? dir / l : vec2(1.0, 0.0)) * chroma * 1.6 * u_dpr;
    c = vec3(tex(src + off).r, tex(src).g, tex(src - off).b);
  } else if (u_quality > 1.5) {
    float o = 1.6 * u_dpr;
    c = (tex(src) * 2.0 + tex(src + vec2(o, 0.0)) + tex(src - vec2(o, 0.0)) +
         tex(src + vec2(0.0, o)) + tex(src - vec2(0.0, o))) / 6.0;
  } else {
    c = tex(src);
  }

  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, u_sat);
  c = mix(c, u_tint.rgb, u_tint.a);

  // Тонкий блик сверху-слева по краю.
  if (depth < 1.4 * u_dpr && depth > -0.5) {
    vec2 n = sdNormal(p - hs, hs, u_radius);
    float light = clamp(-n.y * 0.85 - n.x * 0.2, 0.0, 1.0);
    c += vec3(0.20) * light;
  }
  fragColor = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
